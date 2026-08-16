import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di.dart';
import '../../../../core/debug/agent_log.dart';
import '../../../../core/errors/result.dart';
import '../../../../domain/entities/order.dart';

enum BookingActionStatus { idle, loading, error }

class BookingState extends Equatable {
  const BookingState({
    this.order,
    this.actionStatus = BookingActionStatus.idle,
    this.errorMessage,
  });

  final CustomerOrder? order;
  final BookingActionStatus actionStatus;
  final String? errorMessage;

  BookingState copyWith({
    CustomerOrder? order,
    bool clearOrder = false,
    BookingActionStatus? actionStatus,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookingState(
      order: clearOrder ? null : (order ?? this.order),
      actionStatus: actionStatus ?? this.actionStatus,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [order, actionStatus, errorMessage];
}

class BookingNotifier extends Notifier<BookingState> {
  StreamSubscription<CustomerOrder?>? _sub;

  @override
  BookingState build() {
    _sub?.cancel();
    _sub = ref.read(orderRepositoryProvider).watchActiveOrder().listen((order) {
      state = state.copyWith(order: order, clearOrder: order == null);
    });
    ref.onDispose(() => _sub?.cancel());
    return const BookingState();
  }

  Future<bool> setLocations({
    required PlaceLocation pickup,
    required PlaceLocation drop,
  }) async {
    final existing = state.order;
    // #region agent log
    agentLog(
      'booking_provider.dart:setLocations',
      'setLocations entry',
      hypothesisId: 'H3',
      data: {
        'hasExisting': existing != null,
        'existingStatus': existing?.status.name,
        'existingCode': existing?.orderCode,
        'blocking': existing?.isBlockingNewBooking,
        'pickupAddr': pickup.address.length > 40
            ? pickup.address.substring(0, 40)
            : pickup.address,
        'dropAddr': drop.address.length > 40
            ? drop.address.substring(0, 40)
            : drop.address,
      },
    );
    // #endregion
    // Do not hard-block on stale local state — createDraft clears ghosts.
    state = state.copyWith(actionStatus: BookingActionStatus.loading, clearError: true);
    final result = await ref.read(orderRepositoryProvider).createDraft(
          pickup: pickup,
          drop: drop,
        );
    return _handle(result);
  }

  Future<bool> saveParcel({
    required ParcelType type,
    required WeightBand weight,
    required String instructions,
    String? photoPath,
  }) async {
    final order = state.order;
    if (order == null) return false;
    state = state.copyWith(actionStatus: BookingActionStatus.loading, clearError: true);
    final result = await ref.read(orderRepositoryProvider).updateParcelDetails(
          orderId: order.id,
          parcelType: type,
          weightBand: weight,
          instructions: instructions,
          photoPath: photoPath,
        );
    return _handle(result);
  }

  Future<bool> startSearch() async {
    final order = state.order;
    if (order == null) return false;
    // #region agent log
    agentLog(
      'booking_provider.dart:startSearch',
      'startSearch entry',
      hypothesisId: 'H2',
      data: {
        'orderId': order.id,
        'status': order.status.name,
        'pickupId': order.pickupId,
        'code': order.orderCode,
      },
    );
    // #endregion
    state = state.copyWith(actionStatus: BookingActionStatus.loading);
    final result =
        await ref.read(orderRepositoryProvider).startDriverSearch(order.id);
    // #region agent log
    result.when(
      success: (o) => agentLog(
        'booking_provider.dart:startSearch',
        'startSearch success',
        hypothesisId: 'H2',
        data: {'status': o.status.name, 'code': o.orderCode, 'pickupId': o.pickupId},
      ),
      failure: (m) => agentLog(
        'booking_provider.dart:startSearch',
        'startSearch failure',
        hypothesisId: 'H1',
        data: {'message': m},
      ),
    );
    // #endregion
    return _handle(result);
  }

  Future<bool> assignDriver() async {
    final order = state.order;
    if (order == null) return false;
    final result = await ref.read(orderRepositoryProvider).assignDriver(order.id);
    return result.when(
      success: (updated) {
        state = state.copyWith(
          order: updated,
          actionStatus: BookingActionStatus.idle,
          clearError: true,
        );
        return true;
      },
      failure: (message) {
        // Soft continue while drivers are still being searched.
        if (message.toLowerCase().contains('still searching')) {
          state = state.copyWith(
            actionStatus: BookingActionStatus.idle,
            clearError: true,
          );
          return false;
        }
        state = state.copyWith(
          actionStatus: BookingActionStatus.error,
          errorMessage: message,
        );
        return false;
      },
    );
  }

  Future<void> refreshActiveTrip() async {
    final result = await ref.read(orderRepositoryProvider).refreshActiveTrip();
    result.when(
      success: (updated) {
        state = state.copyWith(order: updated, clearError: true);
      },
      failure: (_) {},
    );
  }

  Future<bool> markInTransit() async {
    final order = state.order;
    if (order == null) return false;
    final result =
        await ref.read(orderRepositoryProvider).markInTransit(order.id);
    return _handle(result);
  }

  Future<bool> markDelivered() async {
    final order = state.order;
    if (order == null) return false;
    final result =
        await ref.read(orderRepositoryProvider).markDelivered(order.id);
    return _handle(result);
  }

  Future<bool> cancel() async {
    final order = state.order;
    if (order == null) return false;
    if (!order.canCancelTrip) {
      state = state.copyWith(
        actionStatus: BookingActionStatus.error,
        errorMessage:
            'Parcel already picked up. You cannot cancel this trip.',
      );
      return false;
    }
    final result = await ref.read(orderRepositoryProvider).cancelOrder(order.id);
    final ok = _handle(result);
    if (ok) {
      await ref.read(orderRepositoryProvider).clearActive();
      state = state.copyWith(clearOrder: true);
    }
    return ok;
  }

  Future<bool> rate(int rating) async {
    final order = state.order;
    if (order == null) return false;
    final result = await ref.read(orderRepositoryProvider).rateOrder(
          orderId: order.id,
          rating: rating,
        );
    return _handle(result);
  }

  Future<void> clearActive() async {
    await ref.read(orderRepositoryProvider).clearActive();
    state = state.copyWith(clearOrder: true);
  }

  bool _handle(Result<CustomerOrder> result) {
    return result.when(
      success: (order) {
        state = state.copyWith(
          order: order,
          actionStatus: BookingActionStatus.idle,
        );
        return true;
      },
      failure: (message) {
        state = state.copyWith(
          actionStatus: BookingActionStatus.error,
          errorMessage: message,
        );
        return false;
      },
    );
  }
}

final bookingProvider =
    NotifierProvider<BookingNotifier, BookingState>(BookingNotifier.new);
