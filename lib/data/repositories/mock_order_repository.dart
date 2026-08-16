import 'dart:async';

import '../../core/constants/app_constants.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

class MockOrderRepository implements OrderRepository {
  final _controller = StreamController<CustomerOrder?>.broadcast();
  CustomerOrder? _active;
  int _seq = 0;

  late List<CustomerOrder> _history = [
    CustomerOrder(
      id: 'ord_hist_ongoing',
      orderCode: '#GP990011',
      pickup: const PlaceLocation(label: 'Home', address: 'Sector 62, Noida'),
      drop: const PlaceLocation(label: 'Office', address: 'Sector 18, Noida'),
      parcelType: ParcelType.documents,
      weightBand: WeightBand.upTo1,
      fare: 148,
      status: OrderStatus.driverAssigned,
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      driver: const AssignedDriver(
        name: 'Rahul Sharma',
        rating: 4.8,
        trips: 125,
        vehicleLabel: 'Bike',
        plateNumber: 'UP32 AB 1234',
        phone: '9876543210',
      ),
    ),
    CustomerOrder(
      id: 'ord_hist_1',
      orderCode: '#GP123456',
      pickup: const PlaceLocation(label: 'Home', address: 'Sector 62, Noida'),
      drop: const PlaceLocation(label: 'Work', address: 'Sector 18, Noida'),
      parcelType: ParcelType.documents,
      weightBand: WeightBand.upTo1,
      fare: 148,
      status: OrderStatus.delivered,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      timeline: [
        OrderTimelineEvent(
          title: 'Order Placed',
          at: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        ),
        OrderTimelineEvent(
          title: 'Delivered',
          at: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    ),
    CustomerOrder(
      id: 'ord_hist_2',
      orderCode: '#GP123458',
      pickup: const PlaceLocation(label: 'Pickup', address: 'Indirapuram'),
      drop: const PlaceLocation(label: 'Drop', address: 'Noida Ext'),
      parcelType: ParcelType.electronics,
      weightBand: WeightBand.oneTo5,
      fare: 220,
      status: OrderStatus.cancelled,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  void _emit() => _controller.add(_active);

  double _estimateFare(WeightBand band) => switch (band) {
        WeightBand.upTo1 => 99,
        WeightBand.oneTo5 => 148,
        WeightBand.fiveTo10 => 199,
        WeightBand.tenPlus => 279,
      };

  @override
  Stream<CustomerOrder?> watchActiveOrder() {
    Future.microtask(_emit);
    return _controller.stream;
  }

  @override
  Future<Result<List<CustomerOrder>>> getOrders() async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    final list = [
      if (_active != null &&
          _active!.status != OrderStatus.draft &&
          _active!.status != OrderStatus.searching)
        _active!,
      ..._history,
    ];
    return Success(list);
  }

  @override
  Future<Result<CustomerOrder>> createDraft({
    required PlaceLocation pickup,
    required PlaceLocation drop,
  }) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    if (_active != null && _active!.isBlockingNewBooking) {
      return const FailureResult(
        'You already have an active booking. Finish or cancel it first.',
      );
    }
    _seq += 1;
    final code = '#GP${123450 + _seq}';
    _active = CustomerOrder(
      id: 'ord_$_seq',
      orderCode: code,
      pickup: pickup,
      drop: drop,
      parcelType: ParcelType.documents,
      weightBand: WeightBand.oneTo5,
      fare: 148,
      status: OrderStatus.draft,
      createdAt: DateTime.now(),
    );
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<CustomerOrder>> updateParcelDetails({
    required String orderId,
    required ParcelType parcelType,
    required WeightBand weightBand,
    required String instructions,
    String? photoPath,
  }) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    if (_active == null) return const FailureResult('No active booking');
    _active = _active!.copyWith(
      parcelType: parcelType,
      weightBand: weightBand,
      instructions: instructions,
      photoPath: photoPath,
      fare: _estimateFare(weightBand),
    );
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<CustomerOrder>> startDriverSearch(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (_active == null) return const FailureResult('No active booking');
    _active = _active!.copyWith(
      status: OrderStatus.searching,
      pickupOtp: '4582',
      deliveryOtp: '7391',
    );
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<CustomerOrder>> assignDriver(String orderId) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    if (_active == null) return const FailureResult('No active booking');
    final now = DateTime.now();
    _active = _active!.copyWith(
      status: OrderStatus.driverAssigned,
      driver: const AssignedDriver(
        name: 'Rahul Sharma',
        rating: 4.8,
        trips: 125,
        vehicleLabel: 'Bike',
        plateNumber: 'UP32 AB 1234',
        phone: '9876543210',
        etaMinutes: 12,
        lat: 28.62,
        lng: 77.36,
      ),
      timeline: [
        OrderTimelineEvent(title: 'Order Placed', at: now.subtract(const Duration(minutes: 5))),
        OrderTimelineEvent(title: 'Driver Assigned', at: now),
      ],
    );
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<CustomerOrder>> markInTransit(String orderId) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    if (_active == null) return const FailureResult('No active booking');
    final now = DateTime.now();
    _active = _active!.copyWith(
      status: OrderStatus.inTransit,
      driver: _active!.driver?.copyWithEta(18),
      timeline: [
        ..._active!.timeline,
        OrderTimelineEvent(title: 'Picked Up', at: now),
        OrderTimelineEvent(title: 'In Transit', at: now),
      ],
    );
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<CustomerOrder>> markDelivered(String orderId) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    if (_active == null) return const FailureResult('No active booking');
    final now = DateTime.now();
    _active = _active!.copyWith(
      status: OrderStatus.delivered,
      timeline: [
        ..._active!.timeline,
        OrderTimelineEvent(title: 'Delivered', at: now),
      ],
    );
    _history = [_active!, ..._history];
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<CustomerOrder>> cancelOrder(String orderId) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);

    if (_active != null &&
        (_active!.id == orderId || _active!.orderCode == orderId)) {
      if (!_active!.canCancelTrip) {
        return const FailureResult(
          'Parcel already picked up. You cannot cancel this trip.',
        );
      }
      _active = _active!.copyWith(status: OrderStatus.cancelled);
      _history = [_active!, ..._history];
      final cancelled = _active!;
      _active = null;
      _emit();
      return Success(cancelled);
    }

    final idx = _history.indexWhere(
      (o) => o.id == orderId || o.orderCode == orderId,
    );
    if (idx < 0) return const FailureResult('Order not found');
    final order = _history[idx];
    if (!order.canCancelTrip) {
      return const FailureResult(
        'Parcel already picked up. You cannot cancel this trip.',
      );
    }
    final cancelled = order.copyWith(status: OrderStatus.cancelled);
    _history = [..._history]..[idx] = cancelled;
    _emit();
    return Success(cancelled);
  }

  @override
  Future<Result<CustomerOrder>> rateOrder({
    required String orderId,
    required int rating,
  }) async {
    if (_active == null) return const FailureResult('No active booking');
    _active = _active!.copyWith(rating: rating);
    _history = _history
        .map((o) => o.id == orderId ? o.copyWith(rating: rating) : o)
        .toList();
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<void>> clearActive() async {
    _active = null;
    _emit();
    return const Success(null);
  }

  @override
  Future<Result<CustomerOrder>> refreshActiveTrip() async {
    if (_active == null) return const FailureResult('No active booking');
    final d = _active!.driver;
    if (d != null && d.hasLocation) {
      _active = _active!.copyWith(
        driver: d.copyWith(
          lat: (d.lat ?? 28.62) + 0.0008,
          lng: (d.lng ?? 77.36) + 0.0005,
          etaMinutes: (d.etaMinutes > 3) ? d.etaMinutes - 1 : d.etaMinutes,
        ),
      );
      _emit();
    }
    return Success(_active!);
  }
}

extension on AssignedDriver {
  AssignedDriver copyWithEta(int eta) => copyWith(etaMinutes: eta);
}

class MockNotificationRepository implements NotificationRepository {
  @override
  Future<Result<List<AppNotification>>> getNotifications() async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    final now = DateTime.now();
    return Success([
      AppNotification(
        id: 'n1',
        title: 'Parcel delivered',
        body: 'Your parcel #GP123456 was delivered successfully.',
        createdAt: now.subtract(const Duration(hours: 2)),
        kind: NotificationKind.delivery,
      ),
      AppNotification(
        id: 'n2',
        title: 'Package picked up',
        body: 'Driver has picked up your parcel.',
        createdAt: now.subtract(const Duration(hours: 5)),
        kind: NotificationKind.pickup,
      ),
      AppNotification(
        id: 'n3',
        title: 'Driver on the way',
        body: 'Rahul is heading to your pickup location.',
        createdAt: now.subtract(const Duration(hours: 6)),
        kind: NotificationKind.driver,
      ),
      AppNotification(
        id: 'n4',
        title: '20% off on next booking',
        body: 'Use code GOPARCEL20 this week.',
        createdAt: now.subtract(const Duration(days: 1)),
        kind: NotificationKind.promo,
      ),
      AppNotification(
        id: 'n5',
        title: 'Service area update',
        body: 'We now deliver across Greater Noida.',
        createdAt: now.subtract(const Duration(days: 2)),
        kind: NotificationKind.service,
      ),
    ]);
  }
}
