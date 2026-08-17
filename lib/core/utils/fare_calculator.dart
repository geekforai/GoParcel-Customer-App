import 'dart:math';

import '../../domain/entities/order.dart';

/// Runtime fare rate card loaded from admin (`GET /shipment/fare-config`).
class FareRateCard {
  const FareRateCard({
    required this.vehicles,
    required this.slabs,
    this.mini3WheelerMaxKm = 40,
    this.version = 1,
  });

  final List<FareVehicleOption> vehicles;
  final List<FareSlabConfig> slabs;
  final double? mini3WheelerMaxKm;
  final int version;

  static FareRateCard get bundledFallback => FareRateCard(
        version: 1,
        mini3WheelerMaxKm: 40,
        vehicles: const [
          FareVehicleOption(id: 'twoWheeler', label: '2-Wheeler / Bike'),
          FareVehicleOption(id: 'mini3Wheeler', label: 'Mini 3-Wheeler'),
          FareVehicleOption(id: 'threeWheeler', label: '3-Wheeler'),
          FareVehicleOption(id: 'tataAce', label: 'Tata Ace'),
          FareVehicleOption(id: 'pickup8ft', label: 'Pickup 8ft'),
        ],
        slabs: _fallbackSlabs,
      );

  static FareRateCard fromJson(Map<String, dynamic> json) {
    final vehiclesRaw = (json['vehicles'] as List?) ?? const [];
    final slabsRaw = (json['slabs'] as List?) ?? const [];
    final rules = (json['unavailableRules'] is Map)
        ? Map<String, dynamic>.from(json['unavailableRules'] as Map)
        : const <String, dynamic>{};
    return FareRateCard(
      version: int.tryParse('${json['version'] ?? 1}') ?? 1,
      mini3WheelerMaxKm:
          double.tryParse('${rules['mini3WheelerMaxKm'] ?? 40}'),
      vehicles: [
        for (final v in vehiclesRaw)
          if (v is Map)
            FareVehicleOption(
              id: '${v['id']}',
              label: '${v['label']}',
            ),
      ],
      slabs: [
        for (final s in slabsRaw)
          if (s is Map) FareSlabConfig.fromJson(Map<String, dynamic>.from(s)),
      ],
    );
  }
}

class FareVehicleOption {
  const FareVehicleOption({required this.id, required this.label});
  final String id;
  final String label;
}

class FareSlabConfig {
  const FareSlabConfig({
    required this.id,
    required this.label,
    required this.minKm,
    required this.maxKm,
    required this.mode,
    required this.rates,
    this.note,
  });

  final String id;
  final String label;
  final double minKm;
  final double? maxKm;
  final String mode; // base | perKm
  final Map<String, dynamic> rates;
  final String? note;

  factory FareSlabConfig.fromJson(Map<String, dynamic> json) {
    return FareSlabConfig(
      id: '${json['id']}',
      label: '${json['label']}',
      minKm: double.tryParse('${json['minKm'] ?? 0}') ?? 0,
      maxKm: json['maxKm'] == null
          ? null
          : double.tryParse('${json['maxKm']}'),
      mode: '${json['mode'] ?? 'perKm'}',
      rates: Map<String, dynamic>.from((json['rates'] as Map?) ?? const {}),
      note: json['note']?.toString(),
    );
  }
}

const _fallbackSlabs = <FareSlabConfig>[
  FareSlabConfig(
    id: '1_10',
    label: '1–10 KM',
    minKm: 0,
    maxKm: 10,
    mode: 'base',
    rates: {
      'twoWheeler': {'base': 39, 'after1Km': 11},
      'mini3Wheeler': {'base': 109, 'after1Km': 16},
      'threeWheeler': {'base': 139, 'after1Km': 18},
      'tataAce': {'base': 179, 'after1Km': 45},
      'pickup8ft': {'base': 299, 'after1Km': 50},
    },
  ),
  FareSlabConfig(
    id: '11_20',
    label: '11–20 KM',
    minKm: 10,
    maxKm: 20,
    mode: 'perKm',
    rates: {
      'twoWheeler': 8,
      'mini3Wheeler': 12,
      'threeWheeler': 27,
      'tataAce': 31,
      'pickup8ft': 36,
    },
  ),
  FareSlabConfig(
    id: '21_30',
    label: '21–30 KM',
    minKm: 20,
    maxKm: 30,
    mode: 'perKm',
    rates: {
      'twoWheeler': 7,
      'mini3Wheeler': 9,
      'threeWheeler': 26,
      'tataAce': 33,
      'pickup8ft': 37,
    },
  ),
  FareSlabConfig(
    id: '31_40',
    label: '31–40 KM',
    minKm: 30,
    maxKm: 40,
    mode: 'perKm',
    rates: {
      'twoWheeler': 7,
      'mini3Wheeler': 9,
      'threeWheeler': 25,
      'tataAce': 28,
      'pickup8ft': 35,
    },
  ),
  FareSlabConfig(
    id: '41_50',
    label: '41–50 KM',
    minKm: 40,
    maxKm: 50,
    mode: 'perKm',
    rates: {
      'twoWheeler': 8,
      'threeWheeler': 27,
      'tataAce': 33,
      'pickup8ft': 38,
    },
  ),
  FareSlabConfig(
    id: '51_100',
    label: '51–100 KM',
    minKm: 50,
    maxKm: 100,
    mode: 'perKm',
    rates: {
      'twoWheeler': 9,
      'threeWheeler': 25,
      'tataAce': 34,
      'pickup8ft': 39,
    },
  ),
  FareSlabConfig(
    id: '100_200',
    label: '100+ KM (up to 200)',
    minKm: 100,
    maxKm: 200,
    mode: 'perKm',
    rates: {
      'twoWheeler': 8.5,
      'threeWheeler': 26,
      'tataAce': 31,
      'pickup8ft': 36.5,
    },
  ),
  FareSlabConfig(
    id: '200_plus',
    label: '200+ KM',
    minKm: 200,
    maxKm: null,
    mode: 'perKm',
    rates: {
      'twoWheeler': 8.5,
      'threeWheeler': 29,
      'tataAce': 33,
      'pickup8ft': 38,
    },
  ),
];

/// Official GoParcel distance + vehicle fare card (admin-configurable).
abstract final class FareCalculator {
  static FareRateCard _card = FareRateCard.bundledFallback;

  static FareRateCard get card => _card;

  static void applyConfig(FareRateCard card) {
    if (card.slabs.isEmpty) return;
    _card = card;
  }

  static String vehicleId(FareVehicle vehicle) => switch (vehicle) {
        FareVehicle.twoWheeler => 'twoWheeler',
        FareVehicle.mini3Wheeler => 'mini3Wheeler',
        FareVehicle.threeWheeler => 'threeWheeler',
        FareVehicle.tataAce => 'tataAce',
        FareVehicle.pickup8ft => 'pickup8ft',
      };

  static FareVehicle? vehicleFromId(String id) => switch (id) {
        'twoWheeler' => FareVehicle.twoWheeler,
        'mini3Wheeler' => FareVehicle.mini3Wheeler,
        'threeWheeler' => FareVehicle.threeWheeler,
        'tataAce' => FareVehicle.tataAce,
        'pickup8ft' => FareVehicle.pickup8ft,
        _ => null,
      };

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
    if (vehicle == FareVehicle.mini3Wheeler) {
      final maxKm = _card.mini3WheelerMaxKm;
      if (maxKm != null && km > maxKm) return false;
    }
    final slab = _slabFor(km);
    return slab.rates.containsKey(vehicleId(vehicle));
  }

  static double? estimateForKm({
    required double km,
    required FareVehicle vehicle,
    double tip = 0,
  }) {
    if (!isVehicleAvailable(vehicle, km)) return null;
    final distance = km < 0 ? 0.0 : km;
    final slab = _slabFor(distance);
    final rate = slab.rates[vehicleId(vehicle)];
    if (rate == null) return null;

    double fare;
    if (slab.mode == 'base' && rate is Map) {
      final billed = distance < 1 ? 1.0 : distance;
      final base = double.tryParse('${rate['base']}') ?? 0;
      final after = double.tryParse('${rate['after1Km']}') ?? 0;
      fare = base + max(0, billed - 1) * after;
    } else {
      final perKm = double.tryParse('$rate') ?? 0;
      fare = distance * perKm;
    }
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

  static FareSlabConfig _slabFor(double km) {
    for (final slab in _card.slabs) {
      final max = slab.maxKm ?? double.infinity;
      if (slab.minKm == 0) {
        if (km <= max) return slab;
      } else if (km > slab.minKm && km <= max) {
        return slab;
      }
    }
    return _card.slabs.last;
  }

  static double _rad(double deg) => deg * pi / 180;
}
