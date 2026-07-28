import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/constants/pricing.dart';
import '../../../core/utils/helpers.dart';
import '../../../services/firebase_service.dart';
import '../../../services/sos_service.dart';
import '../../../services/location_service.dart';
import '../../../services/trip_service.dart';
import '../../auth/providers/auth_provider.dart';

class TripDetailsScreen extends ConsumerStatefulWidget {
  const TripDetailsScreen({
    super.key,
    required this.tripId,
    required this.driver,
    required this.tripData,
  });

  final String tripId;
  final Map<String, dynamic> driver;
  final Map<String, dynamic> tripData;

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  bool _loading = false;
  String _tripStatus = 'accepted';
  bool _navigatedAway = false;

  @override
  void initState() {
    super.initState();
    _tripStatus = widget.tripData['status'] as String? ?? 'accepted';
  }

  void _handleTripUpdate(Map<String, dynamic> updatedTrip) {
    final previousStatus = _tripStatus;
    final newStatus = updatedTrip['status'] as String? ?? previousStatus;

    if (newStatus != _tripStatus) {
      setState(() => _tripStatus = newStatus);
    }

    if (_navigatedAway) return;

    if (newStatus == 'declined' && previousStatus != 'declined') {
      _navigatedAway = true;
      context.go('/home');
      return;
    }

    if (newStatus == 'completed' && previousStatus != 'completed') {
      _navigatedAway = true;
      context.go(
        '/payment-summary',
        extra: {
          'tripData': updatedTrip,
          'driver': widget.driver,
        },
      );
    }
  }

  Future<void> _showAlert(String title, String message, {VoidCallback? onOk}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.text)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOk?.call();
            },
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCallDriver() async {
    final phoneNumber = widget.driver['phone'] as String? ?? '+1234567890';
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _handleCancelTrip(Map<String, dynamic> realTimeTrip) {
    final status = realTimeTrip['status'] as String? ?? 'pending';

    if (status == 'in_progress') {
      _showAlert('Cannot Cancel', 'You cannot cancel a trip that is already in progress.');
      return;
    }

    final willChargeFee = status == 'accepted' || status == 'in_progress';

    if (willChargeFee) {
      final fee = AppHelpers.getCancellationFee();
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Cancel Trip', style: TextStyle(color: AppColors.text)),
          content: Text(
            'Are you sure you want to cancel this trip? Since the driver has already accepted, '
            'you will be charged a cancellation fee of ${formatCurrency(fee)}.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelTrip();
              },
              child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Cancel Trip', style: TextStyle(color: AppColors.text)),
          content: const Text(
            'Are you sure you want to cancel this trip? No cancellation fee will be applied '
            'since the driver has not accepted yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _cancelTrip();
              },
              child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _cancelTrip() async {
    if (_loading) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final tripService = ref.read(tripServiceProvider);
      final firebase = ref.read(firebaseServiceProvider);

      final result = await tripService.cancelTripByConsumer(
        widget.tripId,
        user.uid,
        reason: 'User cancelled',
      );

      final driverId = widget.driver['id'] as String?;
      if (driverId != null) {
        await firebase.db.collection('drivers').doc(driverId).update({
          'isAvailable': true,
          'currentTrip': null,
          'updatedAt': DateTime.now(),
        });
      }

      var message = 'Trip cancelled successfully.';
      final feeApplied = result['feeApplied'] == true;
      final cancellationFee = (result['cancellationFee'] as num?)?.toDouble() ?? 0;

      if (feeApplied && cancellationFee > 0) {
        message +=
            ' A cancellation fee of ${formatCurrency(cancellationFee)} will be added to your next trip '
            'because the driver had already accepted.';
      } else if (!feeApplied) {
        message +=
            ' No cancellation fee applied since the driver had not accepted the trip yet.';
      }

      final isBlocked = result['isBlocked'] == true;
      if (isBlocked) {
        message +=
            ' Your account has been temporarily locked due to ${result['cancellationCount']} '
            'cancellations. Please contact support to restore access.';
      }

      if (!mounted) return;
      await _showAlert(
        isBlocked ? 'Account Locked' : 'Trip Cancelled',
        message,
        onOk: () => context.go('/home'),
      );
    } catch (_) {
      if (mounted) {
        await _showAlert('Error', 'Failed to cancel trip. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _StatusInfo _getStatusInfo() {
    switch (_tripStatus) {
      case 'accepted':
        return const _StatusInfo(
          icon: Icons.directions_car_outlined,
          title: 'Driver Assigned',
          subtitle: 'Your driver is on the way to pick you up',
          color: AppColors.warning,
        );
      case 'declined':
        return const _StatusInfo(
          icon: Icons.cancel_outlined,
          title: 'Trip Cancelled',
          subtitle: 'Driver has cancelled the trip',
          color: AppColors.error,
        );
      case 'in_progress':
        return const _StatusInfo(
          icon: Icons.directions_car,
          title: 'Trip in Progress',
          subtitle: 'You are on your way to destination',
          color: AppColors.primary,
        );
      case 'completed':
        return const _StatusInfo(
          icon: Icons.check_circle,
          title: 'Trip Completed',
          subtitle: 'Thank you for riding with us!',
          color: AppColors.success,
        );
      default:
        return const _StatusInfo(
          icon: Icons.directions_car_outlined,
          title: 'Trip Status',
          subtitle: 'Checking status...',
          color: AppColors.textSecondary,
        );
    }
  }

  double _getFare(Map<String, dynamic> trip) {
    final breakdown = trip['fareBreakdown'];
    if (breakdown is Map && breakdown['total'] is num) {
      return (breakdown['total'] as num).toDouble();
    }
    final fare = trip['fare'];
    if (fare is num) return fare.toDouble();
    return AppHelpers.getTripAmount(trip);
  }

  Future<void> _triggerSos() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final locationService = ref.read(locationServiceProvider);
    final coords = await locationService.getCurrentLocation();
    await SosService().triggerSos(
      tripId: widget.tripId,
      userId: user.uid,
      userType: 'consumer',
      latitude: coords.latitude,
      longitude: coords.longitude,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS alert sent. Emergency contacts notified.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripService = ref.watch(tripServiceProvider);
    final statusInfo = _getStatusInfo();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/history');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/history'),
          ),
        ),
        floatingActionButton: _tripStatus == 'in_progress' || _tripStatus == 'accepted'
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.error,
                onPressed: _triggerSos,
                icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                label: const Text('SOS', style: TextStyle(color: Colors.white)),
              )
            : null,
        body: StreamBuilder<Map<String, dynamic>>(
          stream: tripService.listenToTripUpdates(widget.tripId),
          initialData: widget.tripData,
          builder: (context, snapshot) {
            final realTimeTrip = snapshot.data ?? widget.tripData;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleTripUpdate(realTimeTrip);
            });

            final distance = (realTimeTrip['distance'] as num?)?.toDouble();

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        _DriverCard(
                          driver: widget.driver,
                          onCall: _handleCallDriver,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _StatusCard(statusInfo: statusInfo),
                        const SizedBox(height: AppSpacing.md),
                        _LiveTrackingCard(trip: realTimeTrip),
                        const SizedBox(height: AppSpacing.md),
                        _TripDetailsCard(
                          trip: realTimeTrip,
                          tripId: widget.tripId,
                          fare: _getFare(realTimeTrip),
                          distance: distance,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _PaymentMethodCard(),
                      ],
                    ),
                  ),
                ),
                if (_tripStatus != 'completed' && _tripStatus != 'in_progress')
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : () => _handleCancelTrip(realTimeTrip),
                        icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                        label: Text(
                          _loading ? 'Cancelling...' : 'Cancel Trip',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppColors.error),
                          backgroundColor: AppColors.surface,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusInfo {
  const _StatusInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver, required this.onCall});

  final Map<String, dynamic> driver;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 40, color: AppColors.primary),
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
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'License: ${driver['licenseNumber'] ?? 'N/A'}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: AppColors.warning),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${driver['rating'] ?? 'N/A'}',
                      style: const TextStyle(color: AppColors.text),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onCall,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.call),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.statusInfo});

  final _StatusInfo statusInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: statusInfo.color,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusInfo.icon, color: AppColors.white),
              const SizedBox(width: AppSpacing.sm),
              Text(
                statusInfo.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            statusInfo.subtitle,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripDetailsCard extends StatelessWidget {
  const _TripDetailsCard({
    required this.trip,
    required this.tripId,
    required this.fare,
    this.distance,
  });

  final Map<String, dynamic> trip;
  final String tripId;
  final double fare;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _LocationRow(
            icon: Icons.location_on,
            iconColor: AppColors.primary,
            label: 'Pickup',
            address: trip['pickup'] as String? ?? 'Unknown',
          ),
          const SizedBox(height: AppSpacing.md),
          _LocationRow(
            icon: Icons.place,
            iconColor: AppColors.accent,
            label: 'Drop-off',
            address: trip['dropoff'] as String? ?? 'Unknown',
          ),
          const Divider(height: AppSpacing.xl, color: AppColors.border),
          _MetaRow(
            label: 'Distance',
            value: distance != null ? '${distance!.toStringAsFixed(1)} km' : 'N/A',
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetaRow(
            label: 'Estimated Fare',
            value: formatCurrency(fare),
            valueStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _MetaRow(
            label: 'Trip ID',
            value: '#${tripId.length >= 8 ? tripId.substring(0, 8) : tripId}',
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: AppSpacing.xs),
              Text(address, style: const TextStyle(color: AppColors.text, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.payments, color: AppColors.success),
              SizedBox(width: AppSpacing.sm),
              Text('UPI / Cash', style: TextStyle(color: AppColors.text, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveTrackingCard extends StatelessWidget {
  const _LiveTrackingCard({required this.trip});

  final Map<String, dynamic> trip;

  @override
  Widget build(BuildContext context) {
    final driverLoc = trip['driverLocation'] as Map<String, dynamic>?;
    final eta = trip['etaMinutes'] as num?;
    final lat = (driverLoc?['latitude'] as num?)?.toDouble();
    final lng = (driverLoc?['longitude'] as num?)?.toDouble();

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
            'Live Tracking',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (lat != null && lng != null) ...[
            Text('Driver location: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                style: const TextStyle(color: AppColors.textSecondary)),
            if (eta != null)
              Text('ETA: ~${eta.round()} min',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ] else
            const Text(
              'Waiting for driver location updates...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
