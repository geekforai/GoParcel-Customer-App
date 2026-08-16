import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_typography.dart';
import '../core/constants/app_constants.dart';
import '../core/locale/app_locale.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class GoParcelCustomerApp extends ConsumerWidget {
  const GoParcelCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(appLocaleProvider);
    AppTypography.hindi = localeCode == 'hi';
    final router = ref.watch(goRouterProvider);
    final locale = Locale(localeCode == 'hi' ? 'hi' : 'en');

    return MaterialApp.router(
      key: ValueKey('locale-$localeCode'),
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
