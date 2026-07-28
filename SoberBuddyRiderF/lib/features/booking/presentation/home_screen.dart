import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/shell_tab_notifier.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/loading_spinner.dart';
import '../../../services/location_service.dart';
import '../../../services/trip_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/location_autocomplete.dart';
import '../widgets/map_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final TextEditingController _pickupController;
  LatLngCoords? _location;
  MapRegion? _region;
  String _currentAddress = '';
  String _dropoffLocation = '';
  LatLngCoords? _dropoffCoords;
  bool _loading = true;
  bool _hasActiveTrip = false;
  bool _useManualPickup = false;
  LatLngCoords? _pickupCoords;
  DateTime? _scheduledAt;
  String? _partnerId;

  @override
  void initState() {
    super.initState();
    _pickupController = TextEditingController();
    unawaited(_getCurrentLocation());
    unawaited(_checkForActiveTrips());
  }

  @override
  void dispose() {
    _pickupController.dispose();
    super.dispose();
  }

  Future<void> _checkForActiveTrips() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final tripService = ref.read(tripServiceProvider);
      final activeTrips = await tripService.getActiveTrips(user.uid);
      if (mounted) {
        setState(() => _hasActiveTrip = activeTrips.isNotEmpty);
      }
    } catch (_) {}
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _loading = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final coords = await locationService
          .getCurrentLocation()
          .timeout(const Duration(seconds: 12));

      setState(() {
        _location = coords;
        _pickupCoords = coords;
        _useManualPickup = false;
        _region = MapRegion(
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
      });

      try {
        final address = await locationService.reverseGeocode(
          coords.latitude,
          coords.longitude,
        );
        if (mounted) {
          setState(() => _currentAddress = address);
          _pickupController.text = address;
        }
      } catch (_) {
        if (mounted) {
          final fallback =
              '${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)}';
          setState(() => _currentAddress = fallback);
          _pickupController.text = fallback;
        }
      }
    } catch (_) {
      setState(() {
        _useManualPickup = true;
        _currentAddress = '';
        _location = null;
        _pickupCoords = null;
      });

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Not Available'),
            content: const Text(
              'Unable to get your current location automatically. '
              'Please search for your pickup location.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fitRegionForCoords(LatLngCoords a, LatLngCoords b) {
    final minLat = a.latitude < b.latitude ? a.latitude : b.latitude;
    final maxLat = a.latitude > b.latitude ? a.latitude : b.latitude;
    final minLng = a.longitude < b.longitude ? a.longitude : b.longitude;
    final maxLng = a.longitude > b.longitude ? a.longitude : b.longitude;
    final latDelta = (maxLat - minLat) * 1.5;
    final lngDelta = (maxLng - minLng) * 1.5;

    setState(() {
      _region = MapRegion(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLng + maxLng) / 2,
        latitudeDelta: latDelta < 0.01 ? 0.01 : latDelta,
        longitudeDelta: lngDelta < 0.01 ? 0.01 : lngDelta,
      );
    });
  }

  void _handlePickupLocationSelect(Map<String, dynamic> selectedLocation) {
    final coords = LatLngCoords.fromMap(
      selectedLocation['coordinates'] as Map<String, dynamic>?,
    );

    setState(() {
      _pickupCoords = coords;
      _location = coords;
    });

    if (_dropoffCoords != null) {
      _fitRegionForCoords(coords, _dropoffCoords!);
    } else {
      setState(() {
        _region = MapRegion(
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
      });
    }
  }

  void _handleDropoffLocationSelect(Map<String, dynamic> selectedLocation) {
    final coords = LatLngCoords.fromMap(
      selectedLocation['coordinates'] as Map<String, dynamic>?,
    );

    setState(() => _dropoffCoords = coords);

    final pickup = _pickupCoords ?? _location;
    if (pickup != null) {
      _fitRegionForCoords(pickup, coords);
    }
  }

  void _updateCurrentAddress(String newAddress) {
    setState(() => _currentAddress = newAddress);
    if (!_useManualPickup) {
      _pickupController.text = newAddress;
    }

    if (newAddress.trim().isEmpty && _useManualPickup) {
      setState(() {
        _pickupCoords = null;
        _location = null;
      });
    } else if (newAddress.trim().isEmpty) {
      final coords = _pickupCoords ?? _location;
      if (coords != null) {
        setState(() {
          _region = MapRegion(
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
        });
      }
    }
  }

  void _updateDropoffLocation(String newLocation) {
    setState(() => _dropoffLocation = newLocation);

    if (newLocation.trim().isEmpty) {
      setState(() => _dropoffCoords = null);
      final coords = _pickupCoords ?? _location;
      if (coords != null) {
        setState(() {
          _region = MapRegion(
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
        });
      }
    }
  }

  void _retryAutomaticLocation() {
    setState(() {
      _useManualPickup = false;
      _currentAddress = '';
      _pickupCoords = null;
    });
    unawaited(_getCurrentLocation());
  }

  Future<void> _handleCurrentLocationPress() async {
    setState(() => _loading = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final coords = await locationService.getCurrentLocation();

      setState(() {
        _location = coords;
        _pickupCoords = coords;
        _useManualPickup = false;
        _region = MapRegion(
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
      });

      final address = await locationService.reverseGeocode(
        coords.latitude,
        coords.longitude,
      );
      if (mounted) {
        setState(() => _currentAddress = address);
        _pickupController.text = address;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get your current location')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleBookRide() async {
    await _checkForActiveTrips();

    if (_hasActiveTrip) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Active Trip Found'),
          content: const Text(
            'You already have an ongoing trip. Please complete it before booking a new ride.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/history');
              },
              child: const Text('View Trip'),
            ),
          ],
        ),
      );
      return;
    }

    if (_dropoffLocation.trim().isEmpty) {
      _showError('Please enter drop-off location');
      return;
    }
    if (_pickupCoords == null) {
      _showError('Please select your pickup location');
      return;
    }
    if (_dropoffCoords == null) {
      _showError('Please select a drop-off location from the suggestions');
      return;
    }

    final distance = AppHelpers.calculateDistance(
      _pickupCoords!.latitude,
      _pickupCoords!.longitude,
      _dropoffCoords!.latitude,
      _dropoffCoords!.longitude,
    );
    final isNightTime = AppHelpers.isNightTime();
    final fareBreakdown = AppHelpers.getFareBreakdown(distance, 30, isNightTime: isNightTime);

    if (!mounted) return;
    context.push(
      '/booking-confirmation',
      extra: {
        'pickup': _currentAddress,
        'dropoff': _dropoffLocation,
        'pickupCoords': _pickupCoords!.toMap(),
        'dropoffCoords': _dropoffCoords!.toMap(),
        'distance': distance,
        'fareBreakdown': fareBreakdown.toMap(),
        'isNightTime': isNightTime,
        'bookingType': _scheduledAt != null ? 'scheduled' : 'instant',
        if (_scheduledAt != null) 'scheduledAt': _scheduledAt,
        if (_partnerId != null) 'partnerId': _partnerId,
      },
    );
  }

  Future<void> _scanPartnerQr() async {
    final result = await context.push<Map<String, dynamic>>('/qr-scan');
    if (result == null || !mounted) return;
    setState(() {
      _partnerId = result['partnerId'] as String?;
      _dropoffLocation = result['dropoff'] as String? ?? _dropoffLocation;
      final coords = result['dropoffCoords'];
      if (coords is Map) {
        _dropoffCoords = LatLngCoords(
          latitude: (coords['latitude'] as num).toDouble(),
          longitude: (coords['longitude'] as num).toDouble(),
        );
      }
    });
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool get _canBook =>
      _dropoffLocation.trim().isNotEmpty &&
      _currentAddress.trim().isNotEmpty &&
      _pickupCoords != null &&
      _dropoffCoords != null &&
      !_hasActiveTrip;

  @override
  Widget build(BuildContext context) {
    ref.listen(shellTabNotifierProvider, (previous, next) {
      if (next.activeTab == '/home' &&
          previous?.generation != next.generation) {
        unawaited(_checkForActiveTrips());
      }
    });

    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    if (_loading && _region == null) {
      return const SafeArea(
        child: LoadingSpinner(message: 'Getting your location...'),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          if (_region != null)
            Positioned.fill(
              child: MapWidget(
                region: _region!,
                userLocation: _pickupCoords ?? _location,
                dropoffLocation: _dropoffCoords,
                currentAddress: _currentAddress,
                showRoute: _dropoffCoords != null,
                onCurrentLocationPress: _handleCurrentLocationPress,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                10,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _scanPartnerQr,
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: const Text('Scan QR'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickSchedule,
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(_scheduledAt == null ? 'Schedule' : 'Scheduled'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Material(
                    elevation: 5,
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_useManualPickup) ...[
                            LocationAutocomplete(
                              value: _currentAddress,
                              onChanged: _updateCurrentAddress,
                              onLocationSelect: _handlePickupLocationSelect,
                              placeholder: 'Search for pickup location',
                              icon: Icons.location_on,
                              iconColor: AppColors.primary,
                            ),
                            InkWell(
                              onTap: _retryAutomaticLocation,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.my_location, size: 16, color: AppColors.primary),
                                    SizedBox(width: AppSpacing.xs),
                                    Text(
                                      'Use GPS Location',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, size: 20, color: AppColors.primary),
                                Expanded(
                                  child: TextField(
                                    controller: _pickupController,
                                    onChanged: _updateCurrentAddress,
                                    maxLines: null,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: AppColors.text,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Current location',
                                      hintStyle: TextStyle(color: AppColors.textSecondary),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                                  onPressed: _getCurrentLocation,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.search, color: AppColors.primary),
                                  onPressed: () => setState(() => _useManualPickup = true),
                                ),
                              ],
                            ),
                          const Padding(
                            padding: EdgeInsets.only(left: 44),
                            child: Divider(color: AppColors.border, height: 1),
                          ),
                          LocationAutocomplete(
                            value: _dropoffLocation,
                            onChanged: _updateDropoffLocation,
                            onLocationSelect: _handleDropoffLocationSelect,
                            placeholder: 'Where to?',
                            icon: Icons.place,
                            iconColor: AppColors.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canBook ? _handleBookRide : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canBook
                              ? AppColors.primary
                              : AppColors.textSecondary.withValues(alpha: 0.6),
                          padding: const EdgeInsets.all(AppSpacing.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _hasActiveTrip ? 'Trip in Progress' : 'Book Ride',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
