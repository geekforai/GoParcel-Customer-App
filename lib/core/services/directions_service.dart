import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../constants/maps_config.dart';

/// Fetches a driving route via Google Directions API (road path, not straight line).
class DirectionsService {
  DirectionsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final Map<String, List<LatLng>> _cache = {};

  Future<List<LatLng>> drivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final key =
        '${origin.latitude.toStringAsFixed(5)},${origin.longitude.toStringAsFixed(5)}_'
        '${destination.latitude.toStringAsFixed(5)},${destination.longitude.toStringAsFixed(5)}';
    final cached = _cache[key];
    if (cached != null && cached.length >= 2) return cached;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': MapsConfig.apiKey,
      },
    );

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        return [origin, destination];
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status']?.toString() != 'OK') {
        return [origin, destination];
      }
      final routes = data['routes'] as List? ?? const [];
      if (routes.isEmpty) return [origin, destination];
      final overview = (routes.first as Map)['overview_polyline'];
      final encoded = overview is Map ? overview['points']?.toString() : null;
      if (encoded == null || encoded.isEmpty) {
        return [origin, destination];
      }
      final points = decodePolyline(encoded);
      if (points.length < 2) return [origin, destination];
      _cache[key] = points;
      return points;
    } catch (_) {
      return [origin, destination];
    }
  }

  /// Google encoded polyline algorithm.
  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
