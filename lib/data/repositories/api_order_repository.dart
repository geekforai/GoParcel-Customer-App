import 'dart:async';

import '../../core/constants/api_constants.dart';
import '../../core/debug/agent_log.dart';
import '../../core/errors/result.dart';
import '../../core/utils/fare_calculator.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/api_client.dart';
import '../datasources/local_session_datasource.dart';

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._api, this._session);

  final ApiClient _api;
  final LocalSessionDatasource _session;

  final _controller = StreamController<CustomerOrder?>.broadcast();
  CustomerOrder? _active;
  String? _pickupId;
  String? _shipmentCode;

  void _emit() => _controller.add(_active);

  double _estimateFare(WeightBand band) => switch (band) {
        WeightBand.upTo1 => 99,
        WeightBand.oneTo5 => 148,
        WeightBand.fiveTo10 => 199,
        WeightBand.tenPlus => 279,
      };

  double _weightKg(WeightBand band) => switch (band) {
        WeightBand.upTo1 => 1,
        WeightBand.oneTo5 => 3,
        WeightBand.fiveTo10 => 7,
        WeightBand.tenPlus => 12,
      };

  String _packageType(ParcelType t) => switch (t) {
        ParcelType.documents => 'document',
        ParcelType.electronics => 'fragile',
        ParcelType.food => 'parcel',
        ParcelType.clothes => 'parcel',
        ParcelType.others => 'other',
      };

  OrderStatus _mapShipmentStatus(String? status) {
    switch (status) {
      case 'created':
      case 'pickup_scheduled':
        return OrderStatus.searching;
      case 'picked_up':
      case 'in_transit':
      case 'out_for_delivery':
        return OrderStatus.inTransit;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
      case 'rto':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.searching;
    }
  }

  Map<String, dynamic> _partyFromPlace(PlaceLocation place, String phone, String name) {
    final address = place.address.trim().isEmpty ? place.label : place.address;
    final partyName = place.contactName.trim().isEmpty ? name : place.contactName;
    final partyPhone = place.contactPhone.trim().isEmpty ? phone : place.contactPhone;
    return {
      'name': partyName,
      'phone': partyPhone,
      'line1': address.length >= 3 ? address : '$address, Jaipur',
      'line2': '',
      'city': 'Jaipur',
      'state': 'Rajasthan',
      'pincode': '302001',
      'country': 'IN',
    };
  }

  CustomerOrder _fromShipment(Map<String, dynamic> s, {CustomerOrder? base}) {
    final pickup = s['pickup'] as Map<String, dynamic>? ?? {};
    final delivery = s['delivery'] as Map<String, dynamic>? ?? {};
    final pkg = s['package'] as Map<String, dynamic>? ?? {};
    final history = (s['statusHistory'] as List?) ?? const [];
    final timeline = history.whereType<Map>().map((e) {
      final m = Map<String, dynamic>.from(e);
      return OrderTimelineEvent(
        title: (m['note'] as String?) ?? (m['status'] as String? ?? 'Update'),
        at: DateTime.tryParse(m['changedAt']?.toString() ?? '') ?? DateTime.now(),
      );
    }).toList();

    final code = s['shipmentId']?.toString() ?? base?.orderCode ?? '';
    final weight = (pkg['weightKg'] as num?)?.toDouble() ?? 3;
    final band = weight <= 1
        ? WeightBand.upTo1
        : weight <= 5
            ? WeightBand.oneTo5
            : weight <= 10
                ? WeightBand.fiveTo10
                : WeightBand.tenPlus;

    final meta = (s['metadata'] is Map)
        ? Map<String, dynamic>.from(s['metadata'] as Map)
        : <String, dynamic>{};
    final pickupLat = double.tryParse(meta['pickupLat']?.toString() ?? '');
    final pickupLng = double.tryParse(meta['pickupLng']?.toString() ?? '');
    final dropLat = double.tryParse(meta['dropLat']?.toString() ?? '');
    final dropLng = double.tryParse(meta['dropLng']?.toString() ?? '');

    return CustomerOrder(
      id: s['id']?.toString() ?? s['shipmentId']?.toString() ?? base?.id ?? '',
      orderCode: code.startsWith('#') ? code : '#$code',
      pickup: PlaceLocation(
        label: pickup['name']?.toString() ?? base?.pickup.label ?? 'Pickup',
        address: [
          pickup['line1'],
          pickup['city'],
        ].where((x) => x != null && x.toString().isNotEmpty).join(', '),
        point: GeoPoint(
          lat: pickupLat ?? base?.pickup.point.lat ?? 28.62,
          lng: pickupLng ?? base?.pickup.point.lng ?? 77.36,
        ),
      ),
      drop: PlaceLocation(
        label: delivery['name']?.toString() ?? base?.drop.label ?? 'Drop',
        address: [
          delivery['line1'],
          delivery['city'],
        ].where((x) => x != null && x.toString().isNotEmpty).join(', '),
        point: GeoPoint(
          lat: dropLat ?? base?.drop.point.lat ?? 28.57,
          lng: dropLng ?? base?.drop.point.lng ?? 77.32,
        ),
      ),
      parcelType: base?.parcelType ?? ParcelType.others,
      weightBand: band,
      fare: double.tryParse(meta['fare']?.toString() ?? '') ??
          base?.fare ??
          _estimateFare(band),
      status: _mapShipmentStatus(s['status']?.toString()),
      createdAt: DateTime.tryParse(s['createdAt']?.toString() ?? '') ??
          base?.createdAt ??
          DateTime.now(),
      instructions: pkg['description']?.toString() ?? base?.instructions ?? '',
      photoPath: base?.photoPath,
      driver: base?.driver,
      timeline: timeline.isEmpty ? (base?.timeline ?? const []) : timeline,
      rating: base?.rating,
      pickupOtp: base?.pickupOtp ?? '',
      deliveryOtp: base?.deliveryOtp ?? '',
      pickupId: base?.pickupId,
    );
  }

  OrderStatus? _statusFromPickup(String? status) {
    return switch (status) {
      'scheduled' || 'rescheduled' => OrderStatus.searching,
      'assigned' => OrderStatus.driverAssigned,
      'in_progress' => OrderStatus.pickupInProgress,
      'completed' || 'out_for_delivery' => OrderStatus.inTransit,
      'delivered' => OrderStatus.delivered,
      'cancelled' || 'failed' => OrderStatus.cancelled,
      _ => null,
    };
  }

  String _shipmentKey(CustomerOrder o) {
    final code = o.orderCode.replaceFirst('#', '');
    return code.isNotEmpty ? code : o.id;
  }

  bool _isAlreadyGoneCancelError(String message) {
    final m = message.toLowerCase();
    // Do NOT treat "Invalid status transition ... cancelled" as success —
    // that left ghost pickups blocking new bookings.
    if (m.contains('invalid') ||
        m.contains('already picked up') ||
        m.contains('cannot cancel')) {
      return false;
    }
    return m.contains('not found') ||
        m.contains('already cancelled') ||
        m.contains('is cancelled') ||
        m.contains('does not exist');
  }

  Future<void> _cancelShipmentBestEffort(String? shipmentId) async {
    if (shipmentId == null || shipmentId.isEmpty) return;
    try {
      await _api.post(
        '${ApiConstants.shipments}/$shipmentId/cancel',
        body: {'reason': 'Rolled back incomplete booking'},
      );
    } catch (_) {}
  }

  /// Cancels owner pickups that still block scheduling (ghost trips).
  Future<int> _cancelBlockingPickups() async {
    var cleared = 0;
    try {
      final pickupsData =
          await _api.get(ApiConstants.pickups, query: {'limit': '50'});
      final pickupItems = (pickupsData['items'] as List?) ?? const [];
      const blocking = {
        'scheduled',
        'assigned',
        'in_progress',
        'rescheduled',
      };
      for (final raw in pickupItems.whereType<Map>()) {
        final p = Map<String, dynamic>.from(raw);
        final status = p['status']?.toString() ?? '';
        if (!blocking.contains(status)) continue;
        final id = p['id']?.toString() ?? p['pickupId']?.toString();
        if (id == null || id.isEmpty) continue;
        try {
          await _api.post(
            '${ApiConstants.pickups}/$id/cancel',
            body: {'reason': 'Cleared stale booking before new trip'},
          );
          cleared++;
          final sid = p['shipmentId']?.toString();
          await _cancelShipmentBestEffort(sid);
        } on ApiException catch (e) {
          // #region agent log
          agentLog(
            'api_order_repository.dart:_cancelBlockingPickups',
            'failed clearing blocker',
            hypothesisId: 'H1',
            data: {'pickupId': id, 'status': status, 'error': e.message},
          );
          // #endregion
        }
      }
    } catch (_) {}
    // #region agent log
    agentLog(
      'api_order_repository.dart:_cancelBlockingPickups',
      'cleared blocking pickups',
      hypothesisId: 'H1',
      data: {'cleared': cleared},
    );
    // #endregion
    return cleared;
  }

  CustomerOrder _mergePickupOntoOrder(
    CustomerOrder order,
    Map<String, dynamic> pickup,
  ) {
    final pickupRef =
        pickup['id']?.toString() ?? pickup['pickupId']?.toString();
    final mapped = _statusFromPickup(pickup['status']?.toString());
    final driverName = pickup['driverName']?.toString();
    final driverPhone = pickup['driverPhone']?.toString() ?? '';
    AssignedDriver? driver = order.driver;
    if (driverName != null && driverName.isNotEmpty) {
      driver = AssignedDriver(
        name: driverName,
        rating: driver?.rating ?? 4.8,
        trips: driver?.trips ?? 50,
        vehicleLabel: driver?.vehicleLabel ?? 'Bike',
        plateNumber: driver?.plateNumber ?? '',
        phone: driverPhone.isNotEmpty ? driverPhone : (driver?.phone ?? ''),
        etaMinutes: driver?.etaMinutes ?? 12,
        lat: driver?.lat,
        lng: driver?.lng,
      );
    }
    final status = (order.status == OrderStatus.delivered ||
            order.status == OrderStatus.cancelled)
        ? order.status
        : (mapped ?? order.status);

    return order.copyWith(
      status: status,
      pickupId: pickupRef ?? order.pickupId,
      driver: driver,
      pickupOtp: pickup['verificationOtp']?.toString().isNotEmpty == true
          ? pickup['verificationOtp'].toString()
          : null,
      deliveryOtp:
          pickup['deliveryVerificationOtp']?.toString().isNotEmpty == true
              ? pickup['deliveryVerificationOtp'].toString()
              : null,
    );
  }

  @override
  Stream<CustomerOrder?> watchActiveOrder() {
    Future.microtask(_emit);
    return _controller.stream;
  }

  @override
  Future<Result<List<CustomerOrder>>> getOrders() async {
    try {
      final data =
          await _api.get(ApiConstants.shipments, query: {'limit': '50'});
      final items = (data['items'] as List?) ?? const [];
      var list = items.whereType<Map>().map((e) {
        return _fromShipment(Map<String, dynamic>.from(e));
      }).toList();

      try {
        final pickupsData =
            await _api.get(ApiConstants.pickups, query: {'limit': '50'});
        final pickupItems = (pickupsData['items'] as List?) ?? const [];
        final byShipment = <String, Map<String, dynamic>>{};
        for (final raw in pickupItems.whereType<Map>()) {
          final p = Map<String, dynamic>.from(raw);
          final sid = p['shipmentId']?.toString() ?? '';
          if (sid.isEmpty) continue;
          byShipment[sid] = p;
        }
        list = list.map((o) {
          final p = byShipment[_shipmentKey(o)];
          if (p == null) return o;
          return _mergePickupOntoOrder(o, p);
        }).toList();
      } catch (_) {}

      if (_active != null &&
          _active!.status != OrderStatus.draft &&
          !list.any(
            (o) =>
                o.id == _active!.id ||
                _shipmentKey(o) == _shipmentKey(_active!),
          )) {
        list.insert(0, _active!);
      }
      // #region agent log
      agentLog(
        'api_order_repository.dart:getOrders',
        'orders loaded',
        hypothesisId: 'H5',
        data: {
          'count': list.length,
          'ongoing': list
              .where((o) => o.isBlockingNewBooking)
              .map((o) => {
                    'code': o.orderCode,
                    'status': o.status.name,
                    'pickupId': o.pickupId,
                    'addr': o.pickup.address.length > 36
                        ? o.pickup.address.substring(0, 36)
                        : o.pickup.address,
                  })
              .take(8)
              .toList(),
          'localActive': _active?.orderCode,
          'localStatus': _active?.status.name,
        },
      );
      // #endregion
      return Success(list);
    } on ApiException {
      return const Success([]);
    } catch (_) {
      return const Success([]);
    }
  }

  @override
  Future<Result<CustomerOrder>> createDraft({
    required PlaceLocation pickup,
    required PlaceLocation drop,
  }) async {
    if (_active != null && _active!.isBlockingNewBooking) {
      // #region agent log
      agentLog(
        'api_order_repository.dart:createDraft',
        'local active blocks draft — clearing blockers',
        hypothesisId: 'H3',
        runId: 'post-fix',
        data: {
          'localStatus': _active!.status.name,
          'localCode': _active!.orderCode,
          'localPickupId': _pickupId,
        },
      );
      // #endregion
      // Stale local/session booking must not permanently block a new trip.
      await _cancelBlockingPickups();
      if (_active?.canCancelTrip == true ||
          _active?.status == OrderStatus.searching ||
          _active?.status == OrderStatus.driverAssigned ||
          _active?.status == OrderStatus.pickupInProgress) {
        try {
          await cancelOrder(_active!.id);
        } catch (_) {}
      }
      _active = null;
      _pickupId = null;
      _shipmentCode = null;
      _emit();
    }
    _active = CustomerOrder(
      id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      orderCode: '#DRAFT',
      pickup: pickup,
      drop: drop,
      parcelType: ParcelType.documents,
      weightBand: WeightBand.oneTo5,
      fare: 148,
      status: OrderStatus.draft,
      createdAt: DateTime.now(),
    );
    _pickupId = null;
    _shipmentCode = null;
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
    bool electric = true,
    double tip = 0,
  }) async {
    if (_active == null) return const FailureResult('No active booking');
    _active = _active!.copyWith(
      parcelType: parcelType,
      weightBand: weightBand,
      instructions: instructions,
      photoPath: photoPath,
      electric: electric,
      tip: tip,
      fare: FareCalculator.estimate(
        pickup: _active!.pickup,
        drop: _active!.drop,
        weight: weightBand,
        electric: electric,
        tip: tip,
      ),
    );
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<CustomerOrder>> startDriverSearch(String orderId) async {
    if (_active == null) return const FailureResult('No active booking');
    try {
      final session = await _session.readSession();
      final phone = (session?.phone.isNotEmpty == true) ? session!.phone : '9876543210';
      final name = (session?.fullName.isNotEmpty == true)
          ? session!.fullName
          : 'Customer';

      // #region agent log
      agentLog(
        'api_order_repository.dart:startDriverSearch',
        'creating shipment',
        hypothesisId: 'H2',
        data: {
          'draftId': orderId,
          'pickup': _active!.pickup.address.length > 48
              ? _active!.pickup.address.substring(0, 48)
              : _active!.pickup.address,
          'drop': _active!.drop.address.length > 48
              ? _active!.drop.address.substring(0, 48)
              : _active!.drop.address,
        },
      );
      // #endregion

      final shipment = await _api.post(
        '${ApiConstants.shipments}/create',
        body: {
          'paymentMode': 'prepaid',
          'pickup': _partyFromPlace(_active!.pickup, phone, name),
          'delivery': _partyFromPlace(
            _active!.drop,
            phone,
            _active!.drop.label.isEmpty ? 'Receiver' : _active!.drop.label,
          ),
          'package': {
            'type': _packageType(_active!.parcelType),
            'weightKg': _weightKg(_active!.weightBand),
            'description': _active!.instructions,
            'declaredValue': 0,
          },
          'metadata': {
            'fare': _active!.fare.toString(),
            'source': 'customer_app',
            'pickupLat': _active!.pickup.point.lat.toString(),
            'pickupLng': _active!.pickup.point.lng.toString(),
            'dropLat': _active!.drop.point.lat.toString(),
            'dropLng': _active!.drop.point.lng.toString(),
          },
        },
      );

      _shipmentCode = shipment['shipmentId']?.toString();
      // #region agent log
      agentLog(
        'api_order_repository.dart:startDriverSearch',
        'shipment created',
        hypothesisId: 'H2',
        data: {
          'shipmentId': _shipmentCode,
          'shipmentStatus': shipment['status']?.toString(),
        },
      );
      // #endregion
      final pickupAddr = shipment['pickup'] as Map<String, dynamic>? ?? {};
      final scheduleBody = {
        'shipmentId': _shipmentCode,
        'scheduledAt': DateTime.now()
            .add(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
        'address': {
          'name': pickupAddr['name'] ?? name,
          'phone': pickupAddr['phone'] ?? phone,
          'line1': pickupAddr['line1'] ?? _active!.pickup.address,
          'line2': pickupAddr['line2'] ?? '',
          'city': pickupAddr['city'] ?? 'Noida',
          'state': pickupAddr['state'] ?? 'Uttar Pradesh',
          'pincode': pickupAddr['pincode'] ?? '201301',
          'country': 'IN',
        },
        'notes': _active!.instructions,
      };

      Map<String, dynamic> pickup;
      try {
        pickup = await _api.post(
          '${ApiConstants.pickups}/schedule',
          body: scheduleBody,
        );
      } on ApiException catch (e) {
        final msg = e.message.toLowerCase();
        final blocked = e.statusCode == 409 ||
            msg.contains('already have an active booking');
        // #region agent log
        agentLog(
          'api_order_repository.dart:startDriverSearch',
          'schedule failed',
          hypothesisId: 'H1',
          data: {
            'error': e.message,
            'statusCode': e.statusCode,
            'willClearBlockers': blocked,
            'orphanShipmentCode': _shipmentCode,
          },
        );
        // #endregion
        if (!blocked) {
          await _cancelShipmentBestEffort(_shipmentCode);
          _shipmentCode = null;
          rethrow;
        }
        final cleared = await _cancelBlockingPickups();
        // #region agent log
        agentLog(
          'api_order_repository.dart:startDriverSearch',
          'retry schedule after clear',
          hypothesisId: 'H1',
          runId: 'post-fix',
          data: {'cleared': cleared, 'shipmentId': _shipmentCode},
        );
        // #endregion
        try {
          pickup = await _api.post(
            '${ApiConstants.pickups}/schedule',
            body: scheduleBody,
          );
        } on ApiException catch (e2) {
          await _cancelShipmentBestEffort(_shipmentCode);
          _shipmentCode = null;
          // #region agent log
          agentLog(
            'api_order_repository.dart:startDriverSearch',
            'retry schedule still failed; orphan rolled back',
            hypothesisId: 'H2',
            runId: 'post-fix',
            data: {'error': e2.message},
          );
          // #endregion
          rethrow;
        }
      }

      _pickupId = pickup['id']?.toString() ?? pickup['pickupId']?.toString();
      var otp = pickup['verificationOtp']?.toString() ?? '';
      var deliveryOtp = pickup['deliveryVerificationOtp']?.toString() ?? '';

      // Always re-fetch as owner so OTPs + any server fields are authoritative.
      if (_pickupId != null) {
        try {
          final fresh = await _api.get('${ApiConstants.pickups}/$_pickupId');
          otp = fresh['verificationOtp']?.toString() ?? otp;
          deliveryOtp =
              fresh['deliveryVerificationOtp']?.toString() ?? deliveryOtp;
        } catch (_) {}
      }

      _active = _fromShipment(shipment, base: _active).copyWith(
        status: OrderStatus.searching,
        pickupOtp: otp,
        deliveryOtp: deliveryOtp,
        pickupId: _pickupId,
      );
      _emit();
      // #region agent log
      agentLog(
        'api_order_repository.dart:startDriverSearch',
        'booking scheduled successfully',
        hypothesisId: 'H1',
        runId: 'post-fix',
        data: {
          'shipmentId': _shipmentCode,
          'pickupId': _pickupId,
          'status': _active!.status.name,
        },
      );
      // #endregion
      return Success(_active!);
    } on ApiException catch (e) {
      // #region agent log
      agentLog(
        'api_order_repository.dart:startDriverSearch',
        'schedule/create failed after possible orphan shipment',
        hypothesisId: 'H1',
        data: {
          'error': e.message,
          'statusCode': e.statusCode,
          'orphanShipmentCode': _shipmentCode,
        },
      );
      // #endregion
      await _cancelShipmentBestEffort(_shipmentCode);
      _shipmentCode = null;
      return FailureResult(e.message);
    } catch (e) {
      await _cancelShipmentBestEffort(_shipmentCode);
      _shipmentCode = null;
      return FailureResult(e.toString());
    }
  }

  void _mergePickupIntoActive(Map<String, dynamic> pickup) {
    if (_active == null) return;
    final otp = pickup['verificationOtp']?.toString();
    final deliveryOtp = pickup['deliveryVerificationOtp']?.toString();
    final driverName = pickup['driverName']?.toString();
    final driverPhone = pickup['driverPhone']?.toString() ?? '';
    final loc = pickup['driverLocation'];
    double? dLat;
    double? dLng;
    if (loc is Map) {
      dLat = double.tryParse(loc['lat']?.toString() ?? '');
      dLng = double.tryParse(loc['lng']?.toString() ?? '');
    }

    AssignedDriver? driver = _active!.driver;
    final vehicle = pickup['vehicle'];
    String? vehicleLabel;
    String? plate;
    if (vehicle is Map) {
      vehicleLabel = vehicle['type']?.toString() ?? vehicle['model']?.toString();
      plate = vehicle['number']?.toString() ?? vehicle['plate']?.toString();
    }

    if (driverName != null && driverName.isNotEmpty) {
      driver = AssignedDriver(
        name: driverName,
        rating: driver?.rating ?? 4.8,
        trips: driver?.trips ?? 50,
        vehicleLabel: (vehicleLabel != null && vehicleLabel.isNotEmpty)
            ? vehicleLabel
            : (driver?.vehicleLabel ?? 'Bike'),
        plateNumber: (plate != null && plate.isNotEmpty)
            ? plate
            : (driver?.plateNumber ?? 'UP-- ----'),
        phone: driverPhone.isNotEmpty ? driverPhone : (driver?.phone ?? ''),
        etaMinutes: driver?.etaMinutes ?? 12,
        lat: dLat ?? driver?.lat,
        lng: dLng ?? driver?.lng,
      );
    } else if (driver != null && (dLat != null || driverPhone.isNotEmpty)) {
      driver = driver.copyWith(
        phone: driverPhone.isNotEmpty ? driverPhone : null,
        lat: dLat,
        lng: dLng,
      );
    }

    final status = pickup['status']?.toString();
    OrderStatus? mapped;
    if (driverName != null && driverName.isNotEmpty) {
      mapped = switch (status) {
        'in_progress' => OrderStatus.pickupInProgress,
        'completed' || 'out_for_delivery' => OrderStatus.inTransit,
        'delivered' => OrderStatus.delivered,
        'assigned' => OrderStatus.driverAssigned,
        _ => null,
      };
    }

    _active = _active!.copyWith(
      status: mapped,
      pickupOtp: (otp != null && otp.isNotEmpty) ? otp : null,
      deliveryOtp:
          (deliveryOtp != null && deliveryOtp.isNotEmpty) ? deliveryOtp : null,
      driver: driver,
    );
  }

  @override
  Future<Result<CustomerOrder>> assignDriver(String orderId) async {
    if (_active == null) return const FailureResult('No active booking');
    if (_pickupId == null) {
      return const FailureResult('Pickup not scheduled');
    }

    try {
      final pickup = await _api.get('${ApiConstants.pickups}/$_pickupId');
      final status = pickup['status']?.toString();
      final driverName = pickup['driverName']?.toString();
      _mergePickupIntoActive(pickup);

      if (driverName != null &&
          driverName.isNotEmpty &&
          (status == 'assigned' ||
              status == 'in_progress' ||
              status == 'completed' ||
              status == 'out_for_delivery' ||
              status == 'delivered')) {
        if (_active!.timeline.every((e) => e.title != 'Driver Assigned')) {
          _active = _active!.copyWith(
            timeline: [
              ..._active!.timeline,
              OrderTimelineEvent(title: 'Driver Assigned', at: DateTime.now()),
            ],
          );
        }
        _emit();
        return Success(_active!);
      }
      _emit();
      return const FailureResult('Still searching for a driver');
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<CustomerOrder>> refreshActiveTrip() async {
    if (_active == null) return const FailureResult('No active booking');
    if (_pickupId == null) return Success(_active!);
    try {
      final pickup = await _api.get('${ApiConstants.pickups}/$_pickupId');
      _mergePickupIntoActive(pickup);
      _emit();
      return Success(_active!);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<CustomerOrder>> markInTransit(String orderId) async {
    if (_active == null) return const FailureResult('No active booking');
    try {
      if (_shipmentCode != null) {
        final s = await _api.get('${ApiConstants.shipments}/$_shipmentCode');
        _active = _fromShipment(s, base: _active);
        if (_active!.status == OrderStatus.searching ||
            _active!.status == OrderStatus.driverAssigned) {
          _active = _active!.copyWith(status: OrderStatus.inTransit);
        }
      } else {
        _active = _active!.copyWith(status: OrderStatus.inTransit);
      }
      _emit();
      return Success(_active!);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<CustomerOrder>> markDelivered(String orderId) async {
    if (_active == null) return const FailureResult('No active booking');
    try {
      if (_shipmentCode != null) {
        final s = await _api.get('${ApiConstants.shipments}/$_shipmentCode');
        _active = _fromShipment(s, base: _active);
        if (_active!.status != OrderStatus.delivered) {
          _active = _active!.copyWith(status: OrderStatus.delivered);
        }
      } else {
        _active = _active!.copyWith(status: OrderStatus.delivered);
      }
      _emit();
      return Success(_active!);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<CustomerOrder>> cancelOrder(String orderId) async {
    try {
      final isActive = _active != null &&
          (_active!.id == orderId ||
              _shipmentKey(_active!) == orderId.replaceFirst('#', '') ||
              _active!.orderCode == orderId ||
              _active!.orderCode == '#$orderId');

      CustomerOrder? target = isActive ? _active : null;
      String? pickupRef = isActive ? _pickupId : target?.pickupId;
      String? shipmentRef = isActive
          ? (_shipmentCode ?? _shipmentKey(_active!))
          : null;

      // #region agent log
      agentLog(
        'api_order_repository.dart:cancelOrder',
        'cancel entry',
        hypothesisId: 'H1',
        data: {
          'orderId': orderId,
          'isActive': isActive,
          'localPickupId': _pickupId,
          'localShipment': _shipmentCode,
          'targetStatus': target?.status.name,
          'canCancel': target?.canCancelTrip,
        },
      );
      // #endregion

      if (target == null) {
        // Resolve from order history / shipments so Orders screen can cancel.
        final orders = await getOrders();
        await orders.when(
          success: (list) async {
            for (final o in list) {
              if (o.id == orderId ||
                  _shipmentKey(o) == orderId.replaceFirst('#', '') ||
                  o.orderCode == orderId ||
                  o.orderCode == '#$orderId') {
                target = o;
                pickupRef = o.pickupId ?? pickupRef;
                shipmentRef = _shipmentKey(o);
                break;
              }
            }
          },
          failure: (_) async {},
        );
      }

      if (target == null) {
        // Still try cancelling by treating orderId as shipment / pickup id.
        shipmentRef ??= orderId.replaceFirst('#', '');
      } else if (!target!.canCancelTrip) {
        return const FailureResult(
          'Parcel already picked up. You cannot cancel this trip.',
        );
      }

      final shipLookup = shipmentRef;
      if ((pickupRef == null || pickupRef!.isEmpty) &&
          shipLookup != null &&
          shipLookup.isNotEmpty) {
        try {
          final pickupsData =
              await _api.get(ApiConstants.pickups, query: {'limit': '50'});
          final pickupItems = (pickupsData['items'] as List?) ?? const [];
          for (final raw in pickupItems.whereType<Map>()) {
            final p = Map<String, dynamic>.from(raw);
            if (p['shipmentId']?.toString() == shipLookup) {
              pickupRef =
                  p['id']?.toString() ?? p['pickupId']?.toString();
              break;
            }
          }
        } catch (_) {}
      }

      if (pickupRef != null && pickupRef!.isNotEmpty) {
        // #region agent log
        agentLog(
          'api_order_repository.dart:cancelOrder',
          'cancelling pickup',
          hypothesisId: 'H1',
          data: {'pickupRef': pickupRef, 'shipmentRef': shipmentRef},
        );
        // #endregion
        try {
          await _api.post(
            '${ApiConstants.pickups}/$pickupRef/cancel',
            body: {'reason': 'Cancelled by customer'},
          );
        } on ApiException catch (e) {
          final msg = e.message.toLowerCase();
          if (msg.contains('already picked up') ||
              msg.contains('cannot cancel')) {
            return FailureResult(e.message);
          }
          if (!_isAlreadyGoneCancelError(e.message)) rethrow;
        }
      }

      final shipId = shipmentRef ?? orderId.replaceFirst('#', '');
      if (shipId.isNotEmpty) {
        try {
          await _api.post(
            '${ApiConstants.shipments}/$shipId/cancel',
            body: {'reason': 'Cancelled by customer'},
          );
        } on ApiException catch (e) {
          if (!_isAlreadyGoneCancelError(e.message) && pickupRef == null) {
            rethrow;
          }
        }
      }

      final cancelled = (target ??
              CustomerOrder(
                id: orderId,
                orderCode: orderId.startsWith('#') ? orderId : '#$orderId',
                pickup: const PlaceLocation(label: '', address: ''),
                drop: const PlaceLocation(label: '', address: ''),
                parcelType: ParcelType.others,
                weightBand: WeightBand.upTo1,
                fare: 0,
                status: OrderStatus.cancelled,
                createdAt: DateTime.now(),
              ))
          .copyWith(status: OrderStatus.cancelled);

      if (isActive ||
          (_active != null &&
              (_shipmentKey(_active!) == shipId ||
                  _active!.id == orderId))) {
        _active = null;
        _pickupId = null;
        _shipmentCode = null;
        _emit();
      }

      return Success(cancelled);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<CustomerOrder>> rateOrder({
    required String orderId,
    required int rating,
  }) async {
    if (_active == null) return const FailureResult('No active booking');
    _active = _active!.copyWith(rating: rating);
    _emit();
    return Success(_active!);
  }

  @override
  Future<Result<void>> clearActive() async {
    _active = null;
    _pickupId = null;
    _shipmentCode = null;
    _emit();
    return const Success(null);
  }
}

class ApiNotificationRepository implements NotificationRepository {
  ApiNotificationRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<AppNotification>>> getNotifications() async {
    try {
      final data = await _api.get(ApiConstants.notifications, query: {'limit': '50'});
      final items = (data['items'] as List?) ??
          (data is List ? data as List : const []);
      final list = items.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        return AppNotification(
          id: m['id']?.toString() ?? '',
          title: m['title']?.toString() ?? 'Notification',
          body: m['body']?.toString() ?? m['message']?.toString() ?? '',
          createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          kind: NotificationKind.service,
        );
      }).toList();
      return Success(list);
    } on ApiException catch (e) {
      // Soft-fail to empty when notification service is down
      if (e.statusCode == 404 || e.statusCode == 502) {
        return const Success([]);
      }
      return FailureResult(e.message);
    } catch (_) {
      return const Success([]);
    }
  }
}
