import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';
import '../constants/api_constants.dart';
import '../utils/fare_calculator.dart';

final fareConfigProvider =
    AsyncNotifierProvider<FareConfigNotifier, FareRateCard>(
  FareConfigNotifier.new,
);

class FareConfigNotifier extends AsyncNotifier<FareRateCard> {
  @override
  Future<FareRateCard> build() async {
    return _load();
  }

  Future<FareRateCard> refresh() async {
    state = const AsyncLoading();
    final next = await _load();
    state = AsyncData(next);
    return next;
  }

  Future<FareRateCard> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get(
        '${ApiConstants.shipments}/fare-config',
        auth: false,
      );
      final card = FareRateCard.fromJson(data);
      if (card.slabs.isEmpty) {
        FareCalculator.applyConfig(FareRateCard.bundledFallback);
        return FareRateCard.bundledFallback;
      }
      FareCalculator.applyConfig(card);
      return card;
    } catch (_) {
      FareCalculator.applyConfig(FareRateCard.bundledFallback);
      return FareRateCard.bundledFallback;
    }
  }
}
