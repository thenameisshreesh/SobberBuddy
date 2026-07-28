import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LatLngCoords {
  LatLngCoords({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, double> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  Future<bool> requestPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LatLngCoords?> getCurrentLocation() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return LatLngCoords(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  /// Streams location updates every [intervalSeconds] while active.
  Stream<LatLngCoords> getPositionStream({
    int intervalSeconds = 8,
    int distanceFilterMeters = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        timeLimit: Duration(seconds: intervalSeconds),
      ),
    ).map(
      (position) => LatLngCoords(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
    );
  }

  void startTracking(
    void Function(LatLngCoords coords) onUpdate, {
    int intervalSeconds = 8,
  }) {
    stopTracking();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: intervalSeconds),
      ),
    ).listen((position) {
      onUpdate(LatLngCoords(
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<String> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return 'Unknown location';
      final address = placemarks.first;
      return '${address.street ?? ''} ${address.locality ?? ''} ${address.administrativeArea ?? ''}'
          .trim();
    } catch (_) {
      return 'Unknown location';
    }
  }
}
