import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.isFallback = false,
  });

  final List<LatLng> points;
  final int distanceMeters;
  final int durationSeconds;

  /// True when road routing failed and [points] is a straight line.
  final bool isFallback;
}

/// Fetches driving routes from the Google Routes API and picks the shortest.
class RouteService {
  RouteService(this.apiKey);

  final String apiKey;

  static const _endpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static final _cache = <String, RouteResult>{};

  /// Returns the shortest road route (by distance, then duration) among
  /// Google's candidate routes, or a straight line if routing fails.
  Future<RouteResult> shortestRoute(LatLng origin, LatLng destination) async {
    final cacheKey = '${_key(origin)}|${_key(destination)}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final routes = await _computeRoutes(origin, destination);
      if (routes.isNotEmpty) {
        routes.sort((a, b) {
          final byDistance = a.distanceMeters.compareTo(b.distanceMeters);
          return byDistance != 0
              ? byDistance
              : a.durationSeconds.compareTo(b.durationSeconds);
        });
        return _cache[cacheKey] = routes.first;
      }
    } catch (e) {
      debugPrint('Route lookup failed: $e');
    }

    return RouteResult(
      points: [origin, destination],
      distanceMeters: 0,
      durationSeconds: 0,
      isFallback: true,
    );
  }

  Future<List<RouteResult>> _computeRoutes(LatLng origin, LatLng destination) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
          },
          body: jsonEncode({
            'origin': _waypoint(origin),
            'destination': _waypoint(destination),
            'travelMode': 'DRIVE',
            'routingPreference': 'TRAFFIC_AWARE',
            'computeAlternativeRoutes': true,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Routes API ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>? ?? const [];
    return routes
        .cast<Map<String, dynamic>>()
        .map((route) {
          final encoded =
              (route['polyline'] as Map<String, dynamic>?)?['encodedPolyline'] as String?;
          final points = encoded == null ? <LatLng>[] : decodePolyline(encoded);
          return RouteResult(
            points: points,
            distanceMeters: (route['distanceMeters'] as num?)?.toInt() ?? 0,
            durationSeconds: _parseSeconds(route['duration'] as String?),
          );
        })
        .where((route) => route.points.length >= 2)
        .toList();
  }

  static Map<String, dynamic> _waypoint(LatLng point) => {
        'location': {
          'latLng': {'latitude': point.latitude, 'longitude': point.longitude},
        },
      };

  /// Rounds to ~11 m so tiny GPS jitter reuses the cached route.
  static String _key(LatLng point) =>
      '${point.latitude.toStringAsFixed(4)},${point.longitude.toStringAsFixed(4)}';

  static int _parseSeconds(String? duration) {
    if (duration == null) return 0;
    return int.tryParse(duration.replaceAll('s', '')) ?? 0;
  }
}

/// Decodes a Google encoded polyline string.
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  while (index < encoded.length) {
    for (var coordinate = 0; coordinate < 2; coordinate++) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final delta = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      if (coordinate == 0) {
        lat += delta;
      } else {
        lng += delta;
      }
    }
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}
