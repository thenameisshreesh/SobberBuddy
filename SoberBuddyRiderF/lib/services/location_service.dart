import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LatLngCoords {
  const LatLngCoords({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LatLngCoords.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LatLngCoords(latitude: 0, longitude: 0);
    return LatLngCoords(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LocationService {
  Future<bool> requestPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LatLngCoords> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );

    return LatLngCoords(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) {
        return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
      }
      final p = placemarks.first;
      final parts = [p.street, p.locality, p.administrativeArea, p.country]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
      return parts.isEmpty
          ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}'
          : parts.join(', ');
    } catch (_) {
      return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
    }
  }

  Future<LatLngCoords?> geocode(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isEmpty) return null;
      return LatLngCoords(
        latitude: locations.first.latitude,
        longitude: locations.first.longitude,
      );
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
