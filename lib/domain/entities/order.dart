import 'package:equatable/equatable.dart';

enum ParcelType { documents, electronics, food, clothes, others }

enum WeightBand { upTo1, oneTo5, fiveTo10, tenPlus }

enum OrderStatus {
  draft,
  searching,
  driverAssigned,
  pickupInProgress,
  inTransit,
  delivered,
  cancelled,
}

enum OrderFilter { all, completed, ongoing, cancelled }

enum NotificationKind { delivery, pickup, driver, promo, service }

class GeoPoint extends Equatable {
  const GeoPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;
  @override
  List<Object?> get props => [lat, lng];
}

class PlaceLocation extends Equatable {
  const PlaceLocation({
    required this.label,
    required this.address,
    this.point = const GeoPoint(lat: 28.62, lng: 77.36),
  });

  final String label;
  final String address;
  final GeoPoint point;

  @override
  List<Object?> get props => [label, address, point];
}

class AssignedDriver extends Equatable {
  const AssignedDriver({
    required this.name,
    required this.rating,
    required this.trips,
    required this.vehicleLabel,
    required this.plateNumber,
    this.phone = '',
    this.etaMinutes = 12,
    this.lat,
    this.lng,
  });

  final String name;
  final double rating;
  final int trips;
  final String vehicleLabel;
  final String plateNumber;
  final String phone;
  final int etaMinutes;
  final double? lat;
  final double? lng;

  bool get hasLocation => lat != null && lng != null;

  AssignedDriver copyWith({
    String? name,
    double? rating,
    int? trips,
    String? vehicleLabel,
    String? plateNumber,
    String? phone,
    int? etaMinutes,
    double? lat,
    double? lng,
  }) {
    return AssignedDriver(
      name: name ?? this.name,
      rating: rating ?? this.rating,
      trips: trips ?? this.trips,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
      plateNumber: plateNumber ?? this.plateNumber,
      phone: phone ?? this.phone,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  @override
  List<Object?> get props =>
      [name, rating, trips, vehicleLabel, plateNumber, phone, etaMinutes, lat, lng];
}

class CustomerOrder extends Equatable {
  const CustomerOrder({
    required this.id,
    required this.orderCode,
    required this.pickup,
    required this.drop,
    required this.parcelType,
    required this.weightBand,
    required this.fare,
    required this.status,
    required this.createdAt,
    this.instructions = '',
    this.photoPath,
    this.driver,
    this.timeline = const [],
    this.rating,
    this.pickupOtp = '',
    this.deliveryOtp = '',
    this.pickupId,
  });

  final String id;
  final String orderCode;
  final PlaceLocation pickup;
  final PlaceLocation drop;
  final ParcelType parcelType;
  final WeightBand weightBand;
  final double fare;
  final OrderStatus status;
  final DateTime createdAt;
  final String instructions;
  final String? photoPath;
  final AssignedDriver? driver;
  final List<OrderTimelineEvent> timeline;
  final int? rating;
  final String pickupOtp;
  final String deliveryOtp;
  /// Backend pickup document id / pickupId — used to cancel from Orders.
  final String? pickupId;

  /// True while a trip is not finished/cancelled — blocks a second booking.
  bool get isBlockingNewBooking => switch (status) {
        OrderStatus.searching ||
        OrderStatus.driverAssigned ||
        OrderStatus.pickupInProgress ||
        OrderStatus.inTransit =>
          true,
        _ => false,
      };

  /// Customer may cancel until the parcel is picked up (not yet in transit).
  bool get canCancelTrip => switch (status) {
        OrderStatus.searching ||
        OrderStatus.driverAssigned ||
        OrderStatus.pickupInProgress =>
          true,
        _ => false,
      };

  String get resumeRoute => switch (status) {
        OrderStatus.searching => '/booking/searching',
        OrderStatus.driverAssigned || OrderStatus.pickupInProgress =>
          '/booking/driver',
        OrderStatus.inTransit => '/booking/tracking',
        OrderStatus.delivered => '/booking/completed',
        _ => '/booking/locations',
      };

  String get statusLabel => switch (status) {
        OrderStatus.draft => 'Draft',
        OrderStatus.searching => 'Finding driver',
        OrderStatus.driverAssigned => 'Driver assigned',
        OrderStatus.pickupInProgress => 'Pickup in progress',
        OrderStatus.inTransit => 'In transit',
        OrderStatus.delivered => 'Delivered',
        OrderStatus.cancelled => 'Cancelled',
      };

  String get parcelTypeLabel => switch (parcelType) {
        ParcelType.documents => 'Documents',
        ParcelType.electronics => 'Electronics',
        ParcelType.food => 'Food',
        ParcelType.clothes => 'Clothes',
        ParcelType.others => 'Others',
      };

  String get weightLabel => switch (weightBand) {
        WeightBand.upTo1 => 'Up to 1 KG',
        WeightBand.oneTo5 => '1-5 KG',
        WeightBand.fiveTo10 => '5-10 KG',
        WeightBand.tenPlus => '10+ KG',
      };

  CustomerOrder copyWith({
    OrderStatus? status,
    AssignedDriver? driver,
    List<OrderTimelineEvent>? timeline,
    int? rating,
    String? photoPath,
    String? instructions,
    ParcelType? parcelType,
    WeightBand? weightBand,
    double? fare,
    PlaceLocation? pickup,
    PlaceLocation? drop,
    String? pickupOtp,
    String? deliveryOtp,
    String? pickupId,
  }) {
    return CustomerOrder(
      id: id,
      orderCode: orderCode,
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      parcelType: parcelType ?? this.parcelType,
      weightBand: weightBand ?? this.weightBand,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      createdAt: createdAt,
      instructions: instructions ?? this.instructions,
      photoPath: photoPath ?? this.photoPath,
      driver: driver ?? this.driver,
      timeline: timeline ?? this.timeline,
      rating: rating ?? this.rating,
      pickupOtp: pickupOtp ?? this.pickupOtp,
      deliveryOtp: deliveryOtp ?? this.deliveryOtp,
      pickupId: pickupId ?? this.pickupId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderCode,
        pickup,
        drop,
        parcelType,
        weightBand,
        fare,
        status,
        createdAt,
        instructions,
        photoPath,
        driver,
        timeline,
        rating,
        pickupOtp,
        deliveryOtp,
        pickupId,
      ];
}

class OrderTimelineEvent extends Equatable {
  const OrderTimelineEvent({required this.title, required this.at});

  final String title;
  final DateTime at;

  @override
  List<Object?> get props => [title, at];
}

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.kind = NotificationKind.delivery,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationKind kind;

  @override
  List<Object?> get props => [id, title, body, createdAt, kind];
}
