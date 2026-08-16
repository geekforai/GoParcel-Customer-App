import '../../core/auth/session_gate.dart';
import '../../core/constants/api_constants.dart';
import '../../core/debug/agent_log.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/auth_customer_repository.dart';
import '../datasources/api_client.dart';
import '../datasources/local_session_datasource.dart';

AuthSession _sessionFromAuthData(Map<String, dynamic> data, {String? fallbackPhone}) {
  final user = (data['user'] as Map<String, dynamic>?) ?? {};
  final tokens = (data['tokens'] as Map<String, dynamic>?) ?? {};
  return AuthSession(
    token: tokens['accessToken'] as String? ?? '',
    refreshToken: tokens['refreshToken'] as String? ?? '',
    phone: user['phone'] as String? ?? fallbackPhone ?? '',
    userId: user['id']?.toString() ?? '',
    fullName: user['fullName'] as String? ?? '',
    isAuthenticated: true,
  );
}

bool _isEmailNotVerified(ApiException e) {
  if (e.statusCode != 403) return false;
  final errors = e.errors;
  if (errors == null) return e.message.toLowerCase().contains('email not verified');
  for (final item in errors) {
    if (item is Map && item['code'] == 'EMAIL_NOT_VERIFIED') return true;
  }
  return e.message.toLowerCase().contains('email not verified');
}

String? _debugOtpFromErrors(ApiException e) {
  final errors = e.errors;
  if (errors == null) return null;
  for (final item in errors) {
    if (item is Map && item['otp'] != null) return item['otp'].toString();
  }
  return null;
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._session, this._gate);

  final ApiClient _api;
  final LocalSessionDatasource _session;
  final SessionGate _gate;

  Future<void> _ensureCustomerProfile() async {
    try {
      await _api.get(ApiConstants.customerProfile);
    } catch (_) {}
  }

  @override
  Future<Result<void>> sendOtp({required String phone}) async {
    try {
      await _session.savePendingPhone(phone);
      final data = await _api.post(
        ApiConstants.authPhoneSendOtp,
        body: {'phone': phone, 'role': ApiConstants.role},
        auth: false,
      );
      final otp = data['otp']?.toString();
      if (otp != null && otp.isNotEmpty) {
        // ignore: avoid_print
        print('GoParcel OTP for $phone: $otp');
      }
      return const Success(null);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final data = await _api.post(
        ApiConstants.authPhoneVerifyOtp,
        body: {'phone': phone, 'otp': otp, 'role': ApiConstants.role},
        auth: false,
      );
      final session = _sessionFromAuthData(data, fallbackPhone: phone);
      await _session.saveSession(session);
      await _ensureCustomerProfile();
      return Success(session);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<AuthSession>> loginWithWhatsApp() async {
    try {
      final data = await _api.post(
        ApiConstants.authWhatsappLogin,
        body: {'role': ApiConstants.role},
        auth: false,
      );
      final session = _sessionFromAuthData(data);
      await _session.saveSession(session);
      await _ensureCustomerProfile();
      return Success(session);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<void>> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final data = await _api.post(
        ApiConstants.authRegister,
        body: {
          'fullName': fullName,
          'email': email,
          'password': password,
          'role': ApiConstants.role,
        },
        auth: false,
      );
      final verification = data['verification'] as Map<String, dynamic>?;
      final otp = verification?['otp']?.toString();
      if (otp != null && otp.isNotEmpty) {
        // ignore: avoid_print
        print('GoParcel email OTP for $email: $otp');
      }
      return const Success(null);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<AuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _api.post(
        ApiConstants.authLogin,
        body: {
          'email': email,
          'password': password,
          'role': ApiConstants.role,
        },
        auth: false,
      );
      final session = _sessionFromAuthData(data);
      await _session.saveSession(session);
      await _ensureCustomerProfile();
      return Success(session);
    } on ApiException catch (e) {
      if (_isEmailNotVerified(e)) {
        final otp = _debugOtpFromErrors(e);
        if (otp != null && otp.isNotEmpty) {
          // ignore: avoid_print
          print('GoParcel email OTP for $email: $otp');
        }
        return const FailureResult('EMAIL_NOT_VERIFIED');
      }
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<AuthSession>> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final data = await _api.post(
        ApiConstants.authVerifyOtp,
        body: {
          'email': email,
          'otp': otp,
          'purpose': 'email_verification',
          'role': ApiConstants.role,
        },
        auth: false,
      );
      final session = _sessionFromAuthData(data);
      if (session.token.isEmpty) {
        return const FailureResult('Email verified. Please login again.');
      }
      await _session.saveSession(session);
      await _ensureCustomerProfile();
      return Success(session);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<AuthSession>> loginWithGoogle({required String idToken}) async {
    try {
      final data = await _api.post(
        ApiConstants.authGoogle,
        body: {'idToken': idToken, 'role': ApiConstants.role},
        auth: false,
      );
      final session = _sessionFromAuthData(data);
      await _session.saveSession(session);
      await _ensureCustomerProfile();
      return Success(session);
    } on ApiException catch (e) {
      return FailureResult(e.message);
    } catch (e) {
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<AuthSession>> getSession() async {
    final local = await _session.readSession();
    if (local == null) return const Success(AuthSession.empty);

    // #region agent log
    agentLog(
      'api_auth_customer',
      'getSession local-first',
      hypothesisId: 'F',
      runId: 'post-fix',
      data: {'hasLocal': true, 'authed': local.isAuthenticated},
    );
    // #endregion

    // Never block splash/home on dead backend — refresh in background.
    // ignore: unawaited_futures
    _refreshSessionInBackground(local);
    _gate.markAuthenticated();
    return Success(local);
  }

  Future<void> _refreshSessionInBackground(AuthSession local) async {
    try {
      final me = await _api.get(ApiConstants.authMe);
      final session = local.copyWith(
        phone: me['phone'] as String? ?? local.phone,
        userId: me['id']?.toString() ?? local.userId,
        fullName: me['fullName'] as String? ?? local.fullName,
        isAuthenticated: true,
      );
      await _session.saveSession(session);
      _gate.markAuthenticated();
      // #region agent log
      agentLog(
        'api_auth_customer',
        'bg refresh ok',
        hypothesisId: 'F',
        runId: 'post-fix',
        data: {'ok': true},
      );
      // #endregion
    } on ApiException catch (e) {
      // #region agent log
      agentLog(
        'api_auth_customer',
        'bg refresh fail',
        hypothesisId: 'F',
        runId: 'post-fix',
        data: {'status': e.statusCode},
      );
      // #endregion
      if (e.statusCode == 401) {
        await _gate.forceLogout();
      }
    } catch (_) {}
  }

  @override
  Future<Result<void>> logout() async {
    try {
      final local = await _session.readSession();
      if (local != null && local.refreshToken.isNotEmpty) {
        await _api.post(
          ApiConstants.authLogout,
          body: {'refreshToken': local.refreshToken},
          auth: false,
        );
      }
    } catch (_) {}
    await _gate.forceLogout();
    return const Success(null);
  }
}

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(this._api, this._session);

  final ApiClient _api;
  final LocalSessionDatasource _session;

  @override
  Future<Result<CustomerProfile>> getProfile() async {
    try {
      final data = await _api.get(ApiConstants.customerProfile);
      final local = await _session.readSession();
      return Success(
        CustomerProfile(
          id: data['id']?.toString() ?? local?.userId ?? '',
          name: data['fullName'] as String? ?? local?.fullName ?? 'Customer',
          phone: data['phone'] as String? ?? local?.phone ?? '',
          walletBalance: 0,
        ),
      );
    } on ApiException catch (e) {
      final local = await _session.readSession();
      if (local != null && local.isAuthenticated) {
        // #region agent log
        agentLog(
          'api_customer',
          'profile local fallback',
          hypothesisId: 'G',
          runId: 'post-fix',
          data: {'apiStatus': e.statusCode},
        );
        // #endregion
        return Success(
          CustomerProfile(
            id: local.userId,
            name: local.fullName.isEmpty ? 'Customer' : local.fullName,
            phone: local.phone,
            walletBalance: 0,
          ),
        );
      }
      return FailureResult(e.message);
    } catch (e) {
      final local = await _session.readSession();
      if (local != null && local.isAuthenticated) {
        return Success(
          CustomerProfile(
            id: local.userId,
            name: local.fullName.isEmpty ? 'Customer' : local.fullName,
            phone: local.phone,
            walletBalance: 0,
          ),
        );
      }
      return FailureResult(e.toString());
    }
  }

  @override
  Future<Result<List<SavedAddress>>> getSavedAddresses() async {
    try {
      final raw = await _api.getRaw(ApiConstants.customerAddresses);
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List ? raw['data'] as List : <dynamic>[]);
      final addresses = list.whereType<Map>().map((e) {
        final m = Map<String, dynamic>.from(e);
        final parts = [
          m['line1'],
          m['line2'],
          m['city'],
          m['state'],
          m['pincode'],
        ].where((x) => x != null && x.toString().trim().isNotEmpty).join(', ');
        return SavedAddress(
          id: m['id']?.toString() ?? '',
          label: m['label'] as String? ?? 'Address',
          address: parts,
          isDefault: m['isDefault'] == true,
        );
      }).toList();
      return Success(addresses);
    } on ApiException {
      return const Success([]);
    } catch (_) {
      return const Success([]);
    }
  }

  @override
  Future<Result<void>> setLocationGranted(bool granted) async {
    await _session.setLocationGranted(granted);
    return const Success(null);
  }

  @override
  Future<Result<bool>> isLocationGranted() async {
    return Success(_session.isLocationGranted());
  }
}
