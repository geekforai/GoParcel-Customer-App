import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/session_gate.dart';
import '../data/datasources/api_client.dart';
import '../data/datasources/local_session_datasource.dart';
import '../data/repositories/api_auth_customer_repository.dart';
import '../data/repositories/api_order_repository.dart';
import '../data/services/google_auth_service.dart';
import '../domain/repositories/auth_customer_repository.dart';
import '../domain/repositories/order_repository.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

final localSessionDatasourceProvider = Provider<LocalSessionDatasource>((ref) {
  return LocalSessionDatasource(ref.watch(sharedPreferencesProvider));
});

final sessionGateProvider = Provider<SessionGate>((ref) {
  final gate = SessionGate(ref.watch(localSessionDatasourceProvider));
  // ignore: discarded_futures
  gate.hydrate();
  ref.onDispose(gate.dispose);
  return gate;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(localSessionDatasourceProvider),
    ref.watch(sessionGateProvider),
  );
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(localSessionDatasourceProvider),
    ref.watch(sessionGateProvider),
  );
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return ApiCustomerRepository(
    ref.watch(apiClientProvider),
    ref.watch(localSessionDatasourceProvider),
  );
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return ApiOrderRepository(
    ref.watch(apiClientProvider),
    ref.watch(localSessionDatasourceProvider),
  );
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return ApiNotificationRepository(ref.watch(apiClientProvider));
});
