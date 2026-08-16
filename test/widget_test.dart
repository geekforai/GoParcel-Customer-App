import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:customer_app/app/app.dart';
import 'package:customer_app/app/di.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('GoParcel customer app smoke test', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const GoParcelCustomerApp(),
      ),
    );

    await tester.pump();
    expect(find.text('GoParcel'), findsWidgets);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.textContaining('Welcome'), findsOneWidget);
  });
}
