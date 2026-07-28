import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ionicons/ionicons.dart';
import '../core/constants/theme.dart';
import '../services/location_service.dart';

class MapComponent extends StatefulWidget {
  const MapComponent({
    super.key,
    this.initialPosition,
    this.userLocation,
    this.pickupLocation,
    this.dropoffLocation,
    this.onLocationUpdate,
  });

  final LatLng? initialPosition;
  final LatLng? userLocation;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final ValueChanged<LatLng>? onLocationUpdate;

  @override
  State<MapComponent> createState() => _MapComponentState();
}

class _MapComponentState extends State<MapComponent> {
  GoogleMapController? _controller;
  String? _mapStyle;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    final style =
        await rootBundle.loadString('assets/map_dark_style.json');
    if (mounted) setState(() => _mapStyle = style);
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    if (widget.userLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: widget.userLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ));
    }
    if (widget.pickupLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    if (widget.dropoffLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: widget.dropoffLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }
    return markers;
  }

  Future<void> _goToCurrentLocation() async {
    final locationService = LocationService();
    final coords = await locationService.getCurrentLocation();
    if (coords == null || _controller == null) return;

    final latLng = LatLng(coords.latitude, coords.longitude);
    await _controller!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: latLng, zoom: 16),
      ),
    );
    widget.onLocationUpdate?.call(latLng);
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPosition ??
        widget.userLocation ??
        const LatLng(28.6139, 77.2090);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 15),
          markers: _markers,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          style: _mapStyle,
          onMapCreated: (controller) => _controller = controller,
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: AppColors.surface,
            onPressed: _goToCurrentLocation,
            child: const Icon(Ionicons.locate, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

LatLng? latLngFromMap(Map<String, dynamic>? coords) {
  if (coords == null) return null;
  final lat = (coords['latitude'] as num?)?.toDouble();
  final lng = (coords['longitude'] as num?)?.toDouble();
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}
