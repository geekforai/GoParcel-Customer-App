import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/maps_config.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    this.mainText = '',
    this.secondaryText = '',
  });

  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
}

class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.address,
    required this.lat,
    required this.lng,
    this.name = '',
  });

  final String placeId;
  final String address;
  final double lat;
  final double lng;
  final String name;
}

/// Lightweight Places Autocomplete via HTTP (no heavy native Places SDK).
class PlacesService {
  PlacesService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://maps.googleapis.com/maps/api/place';

  Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    String? sessionToken,
  }) async {
    final q = input.trim();
    if (q.length < 2) return const [];

    final uri = Uri.parse('$_base/autocomplete/json').replace(queryParameters: {
      'input': q,
      'key': MapsConfig.apiKey,
      'components': 'country:in',
      'language': 'en',
      if (sessionToken != null) 'sessiontoken': sessionToken,
    });

    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return const [];
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['status'] != 'OK' && json['status'] != 'ZERO_RESULTS') {
      return const [];
    }
    final preds = (json['predictions'] as List?) ?? const [];
    return preds.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      final structured = m['structured_formatting'] as Map<String, dynamic>? ?? {};
      return PlaceSuggestion(
        placeId: m['place_id']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        mainText: structured['main_text']?.toString() ?? '',
        secondaryText: structured['secondary_text']?.toString() ?? '',
      );
    }).where((s) => s.placeId.isNotEmpty).toList();
  }

  Future<PlaceDetails?> details(
    String placeId, {
    String? sessionToken,
  }) async {
    if (placeId.isEmpty) return null;
    final uri = Uri.parse('$_base/details/json').replace(queryParameters: {
      'place_id': placeId,
      'fields': 'place_id,formatted_address,geometry,name',
      'key': MapsConfig.apiKey,
      'language': 'en',
      if (sessionToken != null) 'sessiontoken': sessionToken,
    });
    final res = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['status'] != 'OK') return null;
    final r = json['result'] as Map<String, dynamic>? ?? {};
    final loc = (r['geometry'] as Map?)?['location'] as Map? ?? {};
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return PlaceDetails(
      placeId: r['place_id']?.toString() ?? placeId,
      address: r['formatted_address']?.toString() ?? '',
      name: r['name']?.toString() ?? '',
      lat: lat,
      lng: lng,
    );
  }
}
