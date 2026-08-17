import '../../core/errors/result.dart';
import '../entities/order.dart';

abstract class OrderRepository {
  Stream<CustomerOrder?> watchActiveOrder();
  Future<Result<List<CustomerOrder>>> getOrders();
  Future<Result<CustomerOrder>> createDraft({
    required PlaceLocation pickup,
    required PlaceLocation drop,
  });
  Future<Result<CustomerOrder>> updateParcelDetails({
    required String orderId,
    required ParcelType parcelType,
    required WeightBand weightBand,
    required String instructions,
    String? photoPath,
    bool electric = true,
    double tip = 0,
    FareVehicle fareVehicle = FareVehicle.twoWheeler,
  });
  Future<Result<CustomerOrder>> startDriverSearch(String orderId);
  Future<Result<CustomerOrder>> assignDriver(String orderId);
  Future<Result<CustomerOrder>> markInTransit(String orderId);
  Future<Result<CustomerOrder>> markDelivered(String orderId);
  Future<Result<CustomerOrder>> cancelOrder(String orderId);
  Future<Result<CustomerOrder>> rateOrder({required String orderId, required int rating});
  Future<Result<void>> clearActive();

  /// Refresh pickup OTPs, driver phone, and live location for the active trip.
  Future<Result<CustomerOrder>> refreshActiveTrip();
}

abstract class NotificationRepository {
  Future<Result<List<AppNotification>>> getNotifications();
}
