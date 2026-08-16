import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/di.dart';

const _localeKey = 'gp_customer_locale';

class AppLocaleNotifier extends Notifier<String> {
  @override
  String build() {
    return ref.read(sharedPreferencesProvider).getString(_localeKey) ?? 'en';
  }

  Future<void> setLocale(String code) async {
    state = code;
    await ref.read(sharedPreferencesProvider).setString(_localeKey, code);
  }

  bool get isHindi => state == 'hi';
}

final appLocaleProvider =
    NotifierProvider<AppLocaleNotifier, String>(AppLocaleNotifier.new);

String tr(WidgetRef ref, String en, String hi) {
  return ref.watch(appLocaleProvider) == 'hi' ? hi : en;
}
