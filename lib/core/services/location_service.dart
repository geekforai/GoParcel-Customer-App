import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  static const LatLng defaultNoida = LatLng(28.6200, 77.3650);
  final Geocoding _geocoder = Geocoding();

  Future<bool> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LatLng> currentLatLng({LatLng fallback = defaultNoida}) async {
    try {
      final ok = await ensurePermission();
      if (!ok) return fallback;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return fallback;
    }
  }

  Future<String> addressFromLatLng(LatLng point) async {
    try {
      final places = await _geocoder.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (places.isEmpty) {
        return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
      final p = places.first;
      final parts = <String>[
        if ((p.name ?? '').trim().isNotEmpty) p.name!.trim(),
        if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.administrativeArea ?? '').trim().isNotEmpty)
          p.administrativeArea!.trim(),
      ];
      final unique = <String>[];
      for (final part in parts) {
        if (unique.isEmpty || unique.last.toLowerCase() != part.toLowerCase()) {
          unique.add(part);
        }
      }
      if (unique.isEmpty) {
        return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
      }
      return unique.take(4).join(', ');
    } catch (_) {
      return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    }
  }

  Future<LatLng?> latLngFromAddress(String address) async {
    try {
      final list = await _geocoder.locationFromAddress(address);
      if (list.isEmpty) return null;
      return LatLng(list.first.latitude, list.first.longitude);
    } catch (_) {
      return null;
    }
  }
}
