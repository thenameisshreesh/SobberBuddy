import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/widgets/route_animation.dart';
import '../../../services/location_service.dart';
import '../../../services/route_service.dart';

class MapRegion {
  const MapRegion({
    required this.latitude,
    required this.longitude,
    this.latitudeDelta = 0.005,
    this.longitudeDelta = 0.005,
  });

  final double latitude;
  final double longitude;
  final double latitudeDelta;
  final double longitudeDelta;

  LatLng get center => LatLng(latitude, longitude);

  CameraPosition toCameraPosition() {
    return CameraPosition(
      target: center,
      zoom: _deltaToZoom(latitudeDelta),
    );
  }

  static double _deltaToZoom(double delta) {
    if (delta <= 0.005) return 15;
    if (delta <= 0.01) return 14;
    if (delta <= 0.05) return 12;
    return 10;
  }
}

const _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]}
]
''';

class MapWidget extends StatefulWidget {
  const MapWidget({
    super.key,
    required this.region,
    this.userLocation,
    this.dropoffLocation,
    this.currentAddress,
    this.showRoute = false,
    this.onCurrentLocationPress,
  });

  final MapRegion region;
  final LatLngCoords? userLocation;
  final LatLngCoords? dropoffLocation;
  final String? currentAddress;
  final bool showRoute;
  final VoidCallback? onCurrentLocationPress;

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;
  MapRegion? _lastRegion;
  late final RouteAnimation _route =
      RouteAnimation(vsync: this, color: AppColors.primary);
  final _routeService = RouteService(AppConfig.googleMapsApiKey);
  String? _routeKey;

  @override
  void initState() {
    super.initState();
    _syncRoute();
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.region.latitude != oldWidget.region.latitude ||
        widget.region.longitude != oldWidget.region.longitude ||
        widget.region.latitudeDelta != oldWidget.region.latitudeDelta) {
      _animateToRegion(widget.region);
    }
    _syncRoute();
  }

  @override
  void dispose() {
    _route.dispose();
    super.dispose();
  }

  (LatLng, LatLng)? get _routeEnds {
    final pickup = widget.userLocation;
    final dropoff = widget.dropoffLocation;
    final hasPickupAddress = widget.currentAddress?.trim().isNotEmpty ?? false;
    if (!widget.showRoute || pickup == null || dropoff == null || !hasPickupAddress) {
      return null;
    }
    return (
      LatLng(pickup.latitude, pickup.longitude),
      LatLng(dropoff.latitude, dropoff.longitude),
    );
  }

  Future<void> _syncRoute() async {
    final ends = _routeEnds;
    final key = ends == null
        ? null
        : '${ends.$1.latitude},${ends.$1.longitude}|${ends.$2.latitude},${ends.$2.longitude}';
    if (key == _routeKey) return;
    _routeKey = key;

    if (ends == null) {
      _route.clear();
      return;
    }
    final result = await _routeService.shortestRoute(ends.$1, ends.$2);
    if (!mounted || key != _routeKey) return;
    _route.setRoute(result.points);
    await _fitRoute();
  }

  Future<void> _fitRoute() async {
    final controller = _controller;
    if (controller == null || _route.points.length < 2) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(boundsFor(_route.points), 80),
    );
  }

  Future<void> _animateToRegion(MapRegion region) async {
    final controller = _controller;
    if (controller == null) return;
    if (_lastRegion?.latitude == region.latitude &&
        _lastRegion?.longitude == region.longitude &&
        _lastRegion?.latitudeDelta == region.latitudeDelta) {
      return;
    }
    _lastRegion = region;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(region.toCameraPosition()),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    final pickup = widget.userLocation;
    final dropoff = widget.dropoffLocation;
    final hasPickupAddress = widget.currentAddress?.trim().isNotEmpty ?? false;

    if (pickup != null && hasPickupAddress) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(pickup.latitude, pickup.longitude),
          infoWindow: const InfoWindow(
            title: 'Pickup Location',
            snippet: 'Your current location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    if (dropoff != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(dropoff.latitude, dropoff.longitude),
          infoWindow: const InfoWindow(
            title: 'Drop-off Location',
            snippet: 'Your destination',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final markers = _buildMarkers();
    return Stack(
      children: [
        ListenableBuilder(
          listenable: _route,
          builder: (context, _) => GoogleMap(
            initialCameraPosition: widget.region.toCameraPosition(),
            onMapCreated: (controller) {
              _controller = controller;
              unawaited(
                _route.points.length >= 2 ? _fitRoute() : _animateToRegion(widget.region),
              );
            },
            style: _darkMapStyle,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            polylines: _route.polylines,
          ),
        ),
        if (widget.onCurrentLocationPress != null)
          Positioned(
            right: 20,
            bottom: 80,
            child: Material(
              elevation: 8,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.border),
              ),
              color: AppColors.white,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onCurrentLocationPress,
                child: const SizedBox(
                  width: 50,
                  height: 50,
                  child: Icon(Icons.my_location, color: AppColors.primary, size: 24),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
