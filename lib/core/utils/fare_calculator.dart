import 'dart:math';

import '../../domain/entities/order.dart';

/// Official GoParcel distance + vehicle fare card.
abstract final class FareCalculator {
  static const freeLoadingMinutes = 50;
  static const waitingChargePerMinute = 3.0;

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

  static bool isVehicleAvailable(FareVehicle vehicle, double km) {
    if (vehicle == FareVehicle.mini3Wheeler && km > 40) return false;
    return true;
  }

  /// Returns null when the vehicle is not offered for [km].
  static double? estimateForKm({
    required double km,
    required FareVehicle vehicle,
    double tip = 0,
  }) {
    if (!isVehicleAvailable(vehicle, km)) return null;
    final distance = km < 0 ? 0.0 : km;
    final fare = switch (_slab(distance)) {
      _FareSlab.upto10 => _baseFare(vehicle, distance),
      _FareSlab.km11to20 => distance * _perKm(vehicle, _FareSlab.km11to20),
      _FareSlab.km21to30 => distance * _perKm(vehicle, _FareSlab.km21to30),
      _FareSlab.km31to40 => distance * _perKm(vehicle, _FareSlab.km31to40),
      _FareSlab.km41to50 => distance * _perKm(vehicle, _FareSlab.km41to50),
      _FareSlab.km51to100 => distance * _perKm(vehicle, _FareSlab.km51to100),
      _FareSlab.km100to200 => distance * _perKm(vehicle, _FareSlab.km100to200),
      _FareSlab.km200plus => distance * _perKm(vehicle, _FareSlab.km200plus),
    };
    return (fare + tip).roundToDouble();
  }

  static double estimate({
    required PlaceLocation pickup,
    required PlaceLocation drop,
    required FareVehicle vehicle,
    WeightBand weight = WeightBand.oneTo5,
    bool electric = true,
    double tip = 0,
  }) {
    final km = haversineKm(pickup.point, drop.point);
    return estimateForKm(km: km, vehicle: vehicle, tip: tip) ??
        estimateForKm(km: km, vehicle: FareVehicle.twoWheeler, tip: tip)!;
  }

  static double gst(double fare) => (fare * 0.05 * 100).round() / 100;

  static double _baseFare(FareVehicle vehicle, double km) {
    final billed = km < 1 ? 1.0 : km;
    final (base, after) = switch (vehicle) {
      FareVehicle.twoWheeler => (39.0, 11.0),
      FareVehicle.mini3Wheeler => (109.0, 16.0),
      FareVehicle.threeWheeler => (139.0, 18.0),
      FareVehicle.tataAce => (179.0, 45.0),
      FareVehicle.pickup8ft => (299.0, 50.0),
    };
    return base + max(0, billed - 1) * after;
  }

  static double _perKm(FareVehicle vehicle, _FareSlab slab) {
    return switch ((slab, vehicle)) {
      (_FareSlab.km11to20, FareVehicle.twoWheeler) => 8,
      (_FareSlab.km11to20, FareVehicle.mini3Wheeler) => 12,
      (_FareSlab.km11to20, FareVehicle.threeWheeler) => 27,
      (_FareSlab.km11to20, FareVehicle.tataAce) => 31,
      (_FareSlab.km11to20, FareVehicle.pickup8ft) => 36,
      (_FareSlab.km21to30, FareVehicle.twoWheeler) => 7,
      (_FareSlab.km21to30, FareVehicle.mini3Wheeler) => 9,
      (_FareSlab.km21to30, FareVehicle.threeWheeler) => 26,
      (_FareSlab.km21to30, FareVehicle.tataAce) => 33,
      (_FareSlab.km21to30, FareVehicle.pickup8ft) => 37,
      (_FareSlab.km31to40, FareVehicle.twoWheeler) => 7,
      (_FareSlab.km31to40, FareVehicle.mini3Wheeler) => 9,
      (_FareSlab.km31to40, FareVehicle.threeWheeler) => 25,
      (_FareSlab.km31to40, FareVehicle.tataAce) => 28,
      (_FareSlab.km31to40, FareVehicle.pickup8ft) => 35,
      (_FareSlab.km41to50, FareVehicle.twoWheeler) => 8,
      (_FareSlab.km41to50, FareVehicle.threeWheeler) => 27,
      (_FareSlab.km41to50, FareVehicle.tataAce) => 33,
      (_FareSlab.km41to50, FareVehicle.pickup8ft) => 38,
      (_FareSlab.km51to100, FareVehicle.twoWheeler) => 9,
      (_FareSlab.km51to100, FareVehicle.threeWheeler) => 25,
      (_FareSlab.km51to100, FareVehicle.tataAce) => 34,
      (_FareSlab.km51to100, FareVehicle.pickup8ft) => 39,
      (_FareSlab.km100to200, FareVehicle.twoWheeler) => 8.5,
      (_FareSlab.km100to200, FareVehicle.threeWheeler) => 26,
      (_FareSlab.km100to200, FareVehicle.tataAce) => 31,
      (_FareSlab.km100to200, FareVehicle.pickup8ft) => 36.5,
      (_FareSlab.km200plus, FareVehicle.twoWheeler) => 8.5,
      (_FareSlab.km200plus, FareVehicle.threeWheeler) => 29,
      (_FareSlab.km200plus, FareVehicle.tataAce) => 33,
      (_FareSlab.km200plus, FareVehicle.pickup8ft) => 38,
      _ => 0,
    };
  }

  static _FareSlab _slab(double km) {
    if (km <= 10) return _FareSlab.upto10;
    if (km <= 20) return _FareSlab.km11to20;
    if (km <= 30) return _FareSlab.km21to30;
    if (km <= 40) return _FareSlab.km31to40;
    if (km <= 50) return _FareSlab.km41to50;
    if (km <= 100) return _FareSlab.km51to100;
    if (km <= 200) return _FareSlab.km100to200;
    return _FareSlab.km200plus;
  }

  static double _rad(double deg) => deg * pi / 180;
}

enum _FareSlab {
  upto10,
  km11to20,
  km21to30,
  km31to40,
  km41to50,
  km51to100,
  km100to200,
  km200plus,
}
