import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentPlace {
  const RecentPlace({
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String address;
  final double lat;
  final double lng;

  Map<String, dynamic> toJson() => {
        'address': address,
        'lat': lat,
        'lng': lng,
      };

  factory RecentPlace.fromJson(Map<String, dynamic> json) {
    return RecentPlace(
      address: json['address']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RecentPlacesStore {
  RecentPlacesStore(this._prefs);
  final SharedPreferences _prefs;
  static const _key = 'gp_recent_places';

  List<RecentPlace> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => RecentPlace.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.address.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(RecentPlace place) async {
    final next = [
      place,
      ...read().where((p) => p.address != place.address),
    ].take(8).toList();
    await _prefs.setString(
      _key,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
  }
}
