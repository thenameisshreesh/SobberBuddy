import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/sos_service.dart';
import '../../services/location_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/map_component.dart';
import '../../widgets/shared_widgets.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.trip});

  final TripModel trip;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final _tripService = TripService();
  final _sosService = SosService();
  final _locationService = LocationService();
  late TripModel _realTimeTrip;
  late String _tripPhase;
  bool _loading = false;
  DateTime? _tripStartTime;
  LatLng? _driverLocation;
  LatLng? _pickupRouteOrigin;
  Timer? _locationTimer;

  /// Re-route to pickup only after the driver drifts this far from the last route start.
  static const _rerouteDistanceMeters = 300.0;

  @override
  void initState() {
    super.initState();
    _realTimeTrip = widget.trip;
    _tripPhase = widget.trip.status == 'accepted' ? 'pickup' : 'dropoff';
    if (widget.trip.startedAt != null) {
      _tripStartTime = widget.trip.startedAt!.toDate();
    }
    _refreshDriverLocation();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshDriverLocation(),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshDriverLocation() async {
    final coords = await _locationService.getCurrentLocation();
    if (coords == null || !mounted) return;
    final location = LatLng(coords.latitude, coords.longitude);
    final origin = _pickupRouteOrigin;
    setState(() {
      _driverLocation = location;
      if (origin == null ||
          Geolocator.distanceBetween(origin.latitude, origin.longitude,
                  location.latitude, location.longitude) >
              _rerouteDistanceMeters) {
        _pickupRouteOrigin = location;
      }
    });
  }

  void _handleCancellation(TripModel cancelledTrip) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    try {
      await FirebaseService.db.collection('drivers').doc(user.uid).update({
        'isAvailable': true,
        'currentTrip': null,
        'updatedAt': DateTime.now(),
      });
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Trip Cancelled'),
        content: Text(
          'This trip has been cancelled by the ${cancelledTrip.data['cancelledBy'] == 'consumer' ? 'passenger' : 'system'}.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/drive');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _callConsumer() async {
    final phone = _realTimeTrip.consumerInfo?['phone'] as String?;
    if (phone == null) {
      _showAlert('No Phone Number', 'Passenger phone number is not available');
      return;
    }
    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _navigate() async {
    final coords = _tripPhase == 'pickup'
        ? _realTimeTrip.pickupCoords
        : _realTimeTrip.dropoffCoords;
    if (coords == null) return;
    final lat = coords['latitude'];
    final lng = coords['longitude'];
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'),
    );
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _startTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Trip'),
        content: const Text(
          'Have you picked up the passenger and are ready to start the trip?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not Yet')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start Trip')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await _tripService.startTrip(_realTimeTrip.id);
      setState(() {
        _tripPhase = 'dropoff';
        _tripStartTime = DateTime.now();
      });
    } catch (_) {
      _showAlert('Error', 'Failed to start trip');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _completeTrip() async {
    if (_loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Trip'),
        content: const Text(
          'Have you successfully dropped off the passenger at their destination?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not Yet')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete Trip')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    final user = context.read<AuthProvider>().user;
    try {
      final tripEndTime = DateTime.now();
      final actualDuration = _tripStartTime != null
          ? tripEndTime.difference(_tripStartTime!).inMinutes
          : (_realTimeTrip.estimatedDuration ?? 30).round();

      final result = await _tripService.completeTrip(
        _realTimeTrip.id,
        _realTimeTrip.distance,
        actualDuration.toDouble(),
      );

      if (user != null) {
        await FirebaseService.db.collection('drivers').doc(user.uid).update({
          'isAvailable': true,
          'currentTrip': null,
          'updatedAt': DateTime.now(),
        });

        await FirebaseService.db.collection('payments').add({
          'tripId': _realTimeTrip.id,
          'consumerId': _realTimeTrip.consumerId,
          'driverId': user.uid,
          'totalAmount': result['fareBreakdown']['total'],
          'driverEarnings': result['earnings']['driver'],
          'companyEarnings': result['earnings']['company'],
          'paymentMethod': _realTimeTrip.paymentMethod,
          'status': 'pending',
          'fareBreakdown': result['fareBreakdown'],
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });

        if (_realTimeTrip.consumerId != null) {
          await _tripService.clearPendingFeesOnCompletion(
            _realTimeTrip.consumerId!,
            _realTimeTrip.id,
          );
        }
      }

      if (mounted) {
        context.pushReplacement('/trip-completion', extra: {
          ..._realTimeTrip.toMap(),
          ...result,
        });
      }
    } catch (_) {
      _showAlert('Error', 'Failed to complete trip. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _triggerSos() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final coords = await _locationService.getCurrentLocation();
    if (coords == null) return;
    await _sosService.triggerSos(
      tripId: _realTimeTrip.id,
      userId: user.uid,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS alert sent. Help is on the way.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = latLngFromMap(_realTimeTrip.pickupCoords);
    final dropoff = latLngFromMap(_realTimeTrip.dropoffCoords);
    final fare = _realTimeTrip.fareBreakdown?['total'] ?? _realTimeTrip.data['fare'];
    final earnings = Helpers.calculateEarnings(fare ?? 0).driver;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Active Trip'),
          automaticallyImplyLeading: false,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.error,
          onPressed: _triggerSos,
          icon: const Icon(Ionicons.alert, color: AppColors.white),
          label: const Text('SOS', style: TextStyle(color: AppColors.white)),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseService.db.collection('trips').doc(_realTimeTrip.id).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final updated = TripModel.fromDoc(snapshot.data!);
              if (updated.status == 'cancelled') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handleCancellation(updated);
                });
              } else {
                _realTimeTrip = updated;
                if (updated.status == 'accepted') {
                  _tripPhase = 'pickup';
                } else if (updated.status == 'in_progress') {
                  _tripPhase = 'dropoff';
                  if (updated.startedAt != null && _tripStartTime == null) {
                    _tripStartTime = updated.startedAt!.toDate();
                  }
                }
              }
            }

            return Column(
              children: [
                Expanded(
                  child: pickup != null
                      ? MapComponent(
                          initialPosition: pickup,
                          userLocation: _driverLocation,
                          pickupLocation: pickup,
                          dropoffLocation: dropoff,
                          routeOrigin: _tripPhase == 'pickup' && _pickupRouteOrigin != null
                              ? _pickupRouteOrigin
                              : pickup,
                          routeDestination: _tripPhase == 'pickup' && _pickupRouteOrigin != null
                              ? pickup
                              : dropoff,
                        )
                      : const Center(child: Text('Map unavailable')),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SurfaceCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.background,
                                child: const Icon(Ionicons.person, color: AppColors.primary),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _realTimeTrip.consumerInfo?['name'] ?? 'Passenger',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    StatusBadge(
                                      label: _tripPhase == 'pickup' ? 'Pickup' : 'In Transit',
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _callConsumer,
                                icon: const Icon(Ionicons.call, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SurfaceCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              _locationRow(
                                'Pickup',
                                _realTimeTrip.pickup,
                                Ionicons.location,
                                _tripPhase == 'pickup' ? AppColors.primary : AppColors.success,
                                isActive: _tripPhase == 'pickup',
                                completed: _tripPhase == 'dropoff',
                              ),
                              const SizedBox(height: 20),
                              _locationRow(
                                'Drop-off',
                                _realTimeTrip.dropoff,
                                Ionicons.pin_sharp,
                                _tripPhase == 'dropoff' ? AppColors.accent : AppColors.textSecondary,
                                isActive: _tripPhase == 'dropoff',
                              ),
                              const Divider(height: 24),
                              _metaRow('Trip Fare', Helpers.formatCurrency(fare ?? 0), isPrimary: true),
                              _metaRow('Your Earnings (80%)', Helpers.formatCurrency(earnings), isSuccess: true),
                              if (_realTimeTrip.distance != null)
                                _metaRow('Distance', '${_realTimeTrip.distance!.toStringAsFixed(1)} km'),
                              _metaRow('Payment', 'Cash', icon: Ionicons.cash),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _tripPhase == 'pickup'
                              ? 'Navigate to Pickup Location'
                              : 'Navigate to Drop-off Location',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tripPhase == 'pickup'
                              ? 'Head to the pickup location to collect your passenger'
                              : 'Take your passenger to their destination safely',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        if (_tripStartTime != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Ionicons.time, size: 16, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text('Trip started at ${_tripStartTime!.toLocal()}'.split('.').first),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _navigate,
                                icon: const Icon(Ionicons.navigate, color: AppColors.primary),
                                label: const Text('Navigate', style: TextStyle(color: AppColors.primary)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: _loading
                                    ? null
                                    : (_tripPhase == 'pickup' ? _startTrip : _completeTrip),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  _loading
                                      ? (_tripPhase == 'pickup' ? 'Starting...' : 'Completing...')
                                      : (_tripPhase == 'pickup' ? 'Start Trip' : 'Complete Trip'),
                                  style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _locationRow(
    String label,
    String address,
    IconData icon,
    Color color, {
    bool isActive = false,
    bool completed = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(address, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (isActive) const StatusBadge(label: 'Active'),
        if (completed) const Icon(Ionicons.checkmark_circle, color: AppColors.success),
      ],
    );
  }

  Widget _metaRow(String label, String value, {bool isPrimary = false, bool isSuccess = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          if (icon != null)
            Row(children: [
              Icon(icon, size: 16, color: AppColors.success),
              const SizedBox(width: 4),
              Text(value),
            ])
          else
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSuccess
                    ? AppColors.success
                    : isPrimary
                        ? AppColors.primary
                        : AppColors.text,
              ),
            ),
        ],
      ),
    );
  }
}
