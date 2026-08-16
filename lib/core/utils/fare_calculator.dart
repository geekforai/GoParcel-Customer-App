import 'dart:math';

import '../../domain/entities/order.dart';

abstract final class FareCalculator {
  static double haversineKm(GeoPoint a, GeoPoint b) {
    const earthKm = 6371.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final lat1 = _rad(a.lat);
    final lat2 = _rad(b.lat);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * earthKm * asin(min(1, sqrt(h)));
  }

  static double estimate({
    required PlaceLocation pickup,
    required PlaceLocation drop,
    required WeightBand weight,
    required bool electric,
    double tip = 0,
  }) {
    final km = haversineKm(pickup.point, drop.point);
    final distanceFare = 49 + (km * 12);
    final weightFare = switch (weight) {
      WeightBand.upTo1 => 0,
      WeightBand.oneTo5 => 20,
      WeightBand.fiveTo10 => 45,
      WeightBand.tenPlus => 80,
    };
    final fuelSurcharge = electric ? 0 : 15;
    final subtotal = distanceFare + weightFare + fuelSurcharge;
    return (subtotal + tip).clamp(49, 9999).roundToDouble();
  }

  static double gst(double fare) => (fare * 0.05 * 100).round() / 100;

  static double _rad(double deg) => deg * pi / 180;
}
