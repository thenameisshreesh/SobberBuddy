import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/pricing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/blocked_user_message.dart';
import '../../../services/trip_service.dart';
import '../../auth/providers/auth_provider.dart';

enum BookingStatus { finding, waitingAcceptance, failed, blocked, noDrivers, scheduled }

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.routeParams});

  final Map<String, dynamic> routeParams;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  BookingStatus _status = BookingStatus.finding;
  Map<String, dynamic>? _driver;
  Map<String, dynamic>? _eligibilityData;
  String? _tripId;
  StreamSubscription<Map<String, dynamic>>? _tripSubscription;
  bool _cancelling = false;

  String get _pickup => widget.routeParams['pickup'] as String? ?? '';
  String get _dropoff => widget.routeParams['dropoff'] as String? ?? '';
  double get _distance => (widget.routeParams['distance'] as num?)?.toDouble() ?? 0;
  bool get _isNightTime => widget.routeParams['isNightTime'] as bool? ?? false;
  String get _paymentMethod =>
      widget.routeParams['paymentMethod'] as String? ?? 'cash';

  FareBreakdown get _fareBreakdown => FareBreakdown.fromMap(
        widget.routeParams['fareBreakdown'] as Map<String, dynamic>?,
      );

  double? get _pickupLat {
    final coords = widget.routeParams['pickupCoords'] as Map<String, dynamic>?;
    return (coords?['latitude'] as num?)?.toDouble();
  }

  double? get _pickupLng {
    final coords = widget.routeParams['pickupCoords'] as Map<String, dynamic>?;
    return (coords?['longitude'] as num?)?.toDouble();
  }

  bool get _isScheduled =>
      (widget.routeParams['bookingType'] as String? ?? 'instant') == 'scheduled';

  DateTime? get _scheduledAt {
    final value = widget.routeParams['scheduledAt'];
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_findDriver());
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _buildTripData(String userId) {
    return {
      'consumerId': userId,
      'pickup': _pickup,
      'dropoff': _dropoff,
      'pickupCoords': widget.routeParams['pickupCoords'],
      'dropoffCoords': widget.routeParams['dropoffCoords'],
      'distance': _distance,
      'fareBreakdown': _fareBreakdown.toMap(),
      'isNightTime': _isNightTime,
      'paymentMethod': _paymentMethod,
      'termsAccepted': widget.routeParams['termsAccepted'] ?? false,
      'vehiclePreference': widget.routeParams['vehiclePreference'],
      'estimatedDuration': 30,
      'bookingType': widget.routeParams['bookingType'] ?? 'instant',
      if (widget.routeParams['scheduledAt'] != null)
        'scheduledAt': widget.routeParams['scheduledAt'],
      if (widget.routeParams['promoCode'] != null)
        'promoCode': widget.routeParams['promoCode'],
      if (widget.routeParams['promoDiscount'] != null)
        'promoDiscount': widget.routeParams['promoDiscount'],
      if (widget.routeParams['partnerId'] != null)
        'partnerId': widget.routeParams['partnerId'],
    };
  }

  void _listenForTripAcceptance(String tripId) {
    _tripSubscription?.cancel();
    _tripSubscription = ref.read(tripServiceProvider).listenToTripUpdates(tripId).listen(
      (trip) async {
        if (!mounted) return;
        final status = trip['status'] as String? ?? '';

        if (status == 'declined') {
          setState(() {
            _status = BookingStatus.finding;
            _driver = null;
          });
          final result = await ref.read(tripServiceProvider).reassignTrip(tripId);
          if (!mounted) return;
          if (result == null) {
            setState(() => _status = BookingStatus.noDrivers);
            return;
          }
          setState(() {
            _driver = result.driver;
            _status = BookingStatus.waitingAcceptance;
          });
          return;
        }

        if (status == 'accepted') {
          _tripSubscription?.cancel();
          final driverId = trip['driverId'] as String?;
          Map<String, dynamic>? driver = _driver;
          if (driver == null && driverId != null) {
            final driverDoc = await ref
                .read(tripServiceProvider)
                .getDriverById(driverId);
            driver = driverDoc;
          }
          if (!mounted) return;
          context.pushReplacement(
            '/trip-details',
            extra: {
              'tripId': tripId,
              'driver': driver,
              'tripData': trip,
            },
          );
          return;
        }

        if (status == 'no_drivers') {
          _tripSubscription?.cancel();
          setState(() => _status = BookingStatus.noDrivers);
        }
      },
    );
  }

  Future<void> _findDriver() async {
    final user = ref.read(authProvider).user;
    final profile = ref.read(authProvider).userProfile;
    if (user == null) return;

    setState(() {
      _status = BookingStatus.finding;
      _driver = null;
      _tripId = null;
    });

    try {
      final tripService = ref.read(tripServiceProvider);
      final eligibility = await tripService.canUserBookTrip(user.uid);

      if (eligibility['canBook'] != true) {
        if (eligibility['reason'] == 'blocked') {
          setState(() {
            _status = BookingStatus.blocked;
            _eligibilityData = eligibility;
          });
          return;
        }
        setState(() => _status = BookingStatus.failed);
        return;
      }

      final pickupLat = _pickupLat;
      final pickupLng = _pickupLng;
      if (pickupLat == null || pickupLng == null) {
        setState(() => _status = BookingStatus.failed);
        return;
      }

      final tripData = _buildTripData(user.uid);
      final consumerInfo = {
        'name': profile?.name ??
            user.displayName ??
            user.email?.split('@').first ??
            'Passenger',
        'phone': profile?.mobile ?? user.phoneNumber,
      };
      final pendingFees = (eligibility['pendingFees'] as num?)?.toDouble() ?? 0;

      if (_isScheduled) {
        final tripId = await tripService.createScheduledTrip(
          tripData: tripData,
          consumerInfo: consumerInfo,
          pendingFees: pendingFees,
        );
        if (!mounted) return;
        setState(() {
          _tripId = tripId;
          _status = BookingStatus.scheduled;
        });
        return;
      }

      final result = await tripService.assignNearestDriver(
        tripData: tripData,
        consumerInfo: consumerInfo,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pendingFees: pendingFees,
      );

      if (result == null) {
        setState(() => _status = BookingStatus.noDrivers);
        return;
      }

      setState(() {
        _tripId = result.tripId;
        _driver = result.driver;
        _status = BookingStatus.waitingAcceptance;
      });

      _listenForTripAcceptance(result.tripId);
    } catch (_) {
      if (mounted) setState(() => _status = BookingStatus.failed);
    }
  }

  Future<void> _cancelFinding() async {
    if (_cancelling) return;
    final tripId = _tripId;
    final user = ref.read(authProvider).user;

    if (tripId != null && user != null) {
      setState(() => _cancelling = true);
      try {
        await ref.read(tripServiceProvider).cancelPendingTrip(tripId, user.uid);
      } catch (_) {}
      _tripSubscription?.cancel();
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == BookingStatus.scheduled) {
      final scheduledAt = _scheduledAt;
      final formattedTime = scheduledAt != null
          ? AppHelpers.formatDate(scheduledAt)
          : 'your scheduled time';
      return Scaffold(
        appBar: AppBar(title: const Text('Ride Scheduled')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                const Icon(Icons.event_available, size: 64, color: AppColors.primary),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Ride Scheduled!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your ride is booked for $formattedTime. We\'ll assign a driver closer to pickup time.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_status == BookingStatus.blocked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking')),
        body: BlockedUserMessage(
          cancellationCount:
              (_eligibilityData?['cancellationCount'] as num?)?.toInt() ?? 0,
          pendingFees:
              (_eligibilityData?['pendingFees'] as num?)?.toDouble() ?? 0,
        ),
      );
    }

    if (_status == BookingStatus.failed || _status == BookingStatus.noDrivers) {
      final isNoDrivers = _status == BookingStatus.noDrivers;
      return Scaffold(
        appBar: AppBar(title: const Text('Booking')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                const Icon(Icons.directions_car_outlined,
                    size: 64, color: AppColors.textSecondary),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  isNoDrivers ? 'No Drivers Available' : 'Booking Failed',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isNoDrivers
                      ? 'We couldn\'t find any drivers nearby. Please try again in a few minutes.'
                      : 'Something went wrong. Please try again.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _findDriver,
                    child: const Text('Try Again'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.all(AppSpacing.md),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWaiting = _status == BookingStatus.waitingAcceptance;

    return Scaffold(
      appBar: AppBar(title: const Text('Finding Driver')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isWaiting
                    ? 'Waiting for driver to accept...'
                    : 'Finding nearest driver...',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isWaiting
                    ? 'Your request has been sent to the nearest available driver'
                    : 'We\'re looking for the best driver near your pickup location',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_driver != null && isWaiting) _DriverCard(driver: _driver!),
              _TripSummaryCard(
                pickup: _pickup,
                dropoff: _dropoff,
                distance: _distance,
                paymentMethod: _paymentMethod,
                fareTotal: _fareBreakdown.total,
                isNightTime: _isNightTime,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cancelling ? null : _cancelFinding,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.all(AppSpacing.md),
                  ),
                  child: Text(
                    _cancelling ? 'Cancelling...' : 'Cancel',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final Map<String, dynamic> driver;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.person, size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver['name'] as String? ?? 'Driver',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  'License: ${driver['licenseNumber'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${driver['rating'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({
    required this.pickup,
    required this.dropoff,
    required this.distance,
    required this.paymentMethod,
    required this.fareTotal,
    required this.isNightTime,
  });

  final String pickup;
  final String dropoff;
  final double distance;
  final String paymentMethod;
  final double fareTotal;
  final bool isNightTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryLocationRow(icon: Icons.location_on, text: pickup),
          const SizedBox(height: AppSpacing.sm),
          _SummaryLocationRow(icon: Icons.place, text: dropoff),
          const Divider(color: AppColors.border, height: AppSpacing.lg * 2),
          _SummaryRow(
            label: 'Distance:',
            value: '${distance.toStringAsFixed(1)} km',
          ),
          _SummaryRow(
            label: 'Payment:',
            value: paymentMethod == 'cash' ? 'UPI / Cash' : paymentMethod,
          ),
          _SummaryRow(
            label: 'Total Fare:',
            value: formatCurrency(fareTotal),
            valueStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (isNightTime) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Row(
                children: [
                  Icon(Icons.nightlight_round, size: 16, color: AppColors.warning),
                  SizedBox(width: AppSpacing.xs),
                  Text(
                    'Night charges included (₹200)',
                    style: TextStyle(fontSize: 12, color: AppColors.text),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLocationRow extends StatelessWidget {
  const _SummaryLocationRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, color: AppColors.text),
          ),
          Text(
            value,
            style: valueStyle ??
                const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text,
                ),
          ),
        ],
      ),
    );
  }
}

/// Factory helper for GoRouter.
Widget buildBookingScreen(BuildContext context, GoRouterState state) {
  return BookingScreen(routeParams: routeExtraMap(state));
}
