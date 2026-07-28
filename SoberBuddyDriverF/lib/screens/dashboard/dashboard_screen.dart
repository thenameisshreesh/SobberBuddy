import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/theme.dart';
import '../../models/trip_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/location_service.dart';
import '../../services/trip_service.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/loading_spinner.dart';
import '../../widgets/map_component.dart';
import '../../widgets/trip_alert_overlay.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _tripService = TripService();
  final _locationService = LocationService();

  bool _isAvailable = false;
  bool _loading = true;
  String? _documentStatus;
  LatLng? _location;
  TripModel? _incomingTrip;
  MergedTripListener? _tripListener;
  String? _activeTripId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _tripListener?.cancel();
    _locationService.stopTracking();
    super.dispose();
  }

  Map<String, dynamic>? _todayStats;

  Future<void> _loadTodayStats(String uid) async {
    final stats = await _tripService.getDriverEarningsStats(uid);
    if (mounted) setState(() => _todayStats = stats['today'] as Map<String, dynamic>?);
  }

  Future<void> _initialize() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    await _loadDriverStatus(user.uid);
    await _getCurrentLocation();
    await _checkActiveTrip(user.uid);
    unawaited(_loadTodayStats(user.uid));

    if (_isAvailable) {
      _listenForTrips(user.uid);
      _startLocationTracking(user.uid);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadDriverStatus(String uid) async {
    final doc = await FirebaseService.db.collection('drivers').doc(uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _isAvailable = data['isAvailable'] as bool? ?? false;
        _documentStatus = data['documentStatus'] as String?;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    final coords = await _locationService.getCurrentLocation();
    if (coords != null && mounted) {
      setState(() => _location = LatLng(coords.latitude, coords.longitude));
    }
  }

  Future<void> _checkActiveTrip(String uid) async {
    final activeTrip = await _tripService.getActiveTrip(uid);
    if (activeTrip != null && mounted) {
      _activeTripId = activeTrip.id;
      context.push('/trip', extra: activeTrip);
    }
  }

  void _listenForTrips(String uid) {
    _tripListener?.cancel();
    _tripListener = _tripService.listenForDriverTrips(uid, (trip) {
      if (!mounted) return;
      setState(() => _incomingTrip = trip);
    });
  }

  void _startLocationTracking(String uid) {
    _locationService.startTracking((coords) async {
      if (!mounted) return;
      setState(() => _location = LatLng(coords.latitude, coords.longitude));
      await _tripService.updateDriverLocation(
        uid,
        coords.latitude,
        coords.longitude,
        activeTripId: _activeTripId,
      );
    });
  }

  bool get _canGoOnline {
    if (_documentStatus == null) return true;
    return _documentStatus == 'approved';
  }

  Future<void> _toggleAvailability(bool value) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (value && !_canGoOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _documentStatus == 'pending'
                ? 'Your documents are pending admin approval.'
                : 'Please upload and verify your documents before going online.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _tripService.updateDriverAvailability(
        user.uid,
        value,
        location: _location != null
            ? {'latitude': _location!.latitude, 'longitude': _location!.longitude}
            : null,
      );
      setState(() {
        _isAvailable = value;
        if (value) {
          _listenForTrips(user.uid);
          _startLocationTracking(user.uid);
        } else {
          _tripListener?.cancel();
          _locationService.stopTracking();
          _incomingTrip = null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'You are now online and available for trips!'
                : 'You are now offline.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update availability')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acceptTrip() async {
    final user = context.read<AuthProvider>().user;
    final trip = _incomingTrip;
    if (user == null || trip == null) return;

    try {
      await _tripService.acceptTrip(trip.id, user.uid);
      setState(() {
        _incomingTrip = null;
        _isAvailable = false;
        _activeTripId = trip.id;
      });
      if (mounted) context.push('/trip', extra: trip);
    } catch (e) {
      if (mounted) {
        setState(() => _incomingTrip = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('another driver')
                  ? 'Another driver accepted this trip'
                  : 'Failed to accept trip',
            ),
          ),
        );
      }
    }
  }

  Future<void> _declineTrip() async {
    final user = context.read<AuthProvider>().user;
    final trip = _incomingTrip;
    if (user == null || trip == null) return;

    try {
      await _tripService.declineTrip(trip.id, user.uid);
      setState(() => _incomingTrip = null);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Trip Declined'),
            content: const Text(
              'You have declined this trip. The passenger will be assigned another driver.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decline trip. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _location == null) {
      return const Scaffold(
        body: LoadingSpinner(message: 'Getting your location...'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Drive')),
      body: Stack(
        children: [
          if (_location != null)
            MapComponent(
              initialPosition: _location,
              userLocation: _location,
              onLocationUpdate: (latLng) => setState(() => _location = latLng),
            ),
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(
                              _isAvailable
                                  ? 'You are online and available'
                                  : 'You are offline',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: _loading ? null : _toggleAvailability,
                        activeThumbColor: AppColors.white,
                        activeTrackColor: AppColors.primary,
                      ),
                    ],
                  ),
                  if (_documentStatus != null && _documentStatus != 'approved') ...[
                    const Divider(),
                    Text(
                      _documentStatus == 'pending'
                          ? 'Documents pending approval'
                          : 'Documents required for going online',
                      style: const TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ],
                  const Divider(),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isAvailable ? AppColors.success : AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isAvailable
                            ? 'Online - Ready for trips'
                            : 'Offline - Not receiving trips',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_todayStats != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: SurfaceCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statTile('Today Trips', '${_todayStats!['trips'] ?? 0}'),
                    _statTile('Today Earned', '₹${_todayStats!['earnings'] ?? 0}'),
                  ],
                ),
              ),
            ),
          if (_incomingTrip != null)
            Positioned.fill(
              child: TripAlertOverlay(
                trip: _incomingTrip!,
                onAccept: _acceptTrip,
                onDecline: _declineTrip,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
