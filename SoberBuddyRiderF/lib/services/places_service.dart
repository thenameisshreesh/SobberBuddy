import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.fullDescription,
    required this.placeId,
  });

  final String id;
  final String title;
  final String description;
  final String fullDescription;
  final String placeId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'fullDescription': fullDescription,
        'placeId': placeId,
        'coordinates': null,
      };
}

class PlaceDetails {
  const PlaceDetails({
    required this.coordinates,
    required this.formattedAddress,
  });

  final Map<String, double> coordinates;
  final String formattedAddress;
}

class PlacesService {
  static const _autocompleteBase =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const _detailsBase =
      'https://maps.googleapis.com/maps/api/place/details/json';

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    if (query.length <= 2) return [];

    try {
      final uri = Uri.parse(_autocompleteBase).replace(queryParameters: {
        'input': query,
        'key': AppConfig.googleMapsApiKey,
        'components': 'country:in',
        'types': 'geocode',
      });

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (!response.ok) {
        debugPrint('Google Places API response not ok: ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') {
        debugPrint('Google Places API error: ${data['status']}');
        return [];
      }

      final predictions = data['predictions'] as List<dynamic>? ?? [];
      return predictions.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value as Map<String, dynamic>;
        final structured = item['structured_formatting'] as Map<String, dynamic>?;
        return PlaceSuggestion(
          id: item['place_id'] as String? ?? index.toString(),
          title: structured?['main_text'] as String? ??
              item['description'] as String? ??
              '',
          description: structured?['secondary_text'] as String? ?? '',
          fullDescription: item['description'] as String? ?? '',
          placeId: item['place_id'] as String? ?? '',
        );
      }).toList();
    } catch (error) {
      debugPrint('Error fetching Google Places suggestions: $error');
      return [];
    }
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final uri = Uri.parse(_detailsBase).replace(queryParameters: {
        'place_id': placeId,
        'key': AppConfig.googleMapsApiKey,
        'fields': 'geometry,formatted_address',
      });

      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (!response.ok) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) return null;

      final geometry = result['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      return PlaceDetails(
        coordinates: {
          'latitude': (location['lat'] as num).toDouble(),
          'longitude': (location['lng'] as num).toDouble(),
        },
        formattedAddress: result['formatted_address'] as String? ?? '',
      );
    } catch (error) {
      debugPrint('Error fetching place details: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>> resolvePlaceSelection(
    PlaceSuggestion suggestion,
  ) async {
    final details = await getPlaceDetails(suggestion.placeId);

    return {
      ...suggestion.toMap(),
      'title': details?.formattedAddress.isNotEmpty == true
          ? details!.formattedAddress
          : suggestion.fullDescription.isNotEmpty
              ? suggestion.fullDescription
              : suggestion.title,
      'coordinates': details?.coordinates ??
          const {
            'latitude': 28.6139,
            'longitude': 77.2090,
          },
    };
  }
}

extension on http.Response {
  bool get ok => statusCode >= 200 && statusCode < 300;
}

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService();
});
