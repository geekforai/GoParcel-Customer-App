import '../../core/constants/app_constants.dart';
import '../../core/errors/result.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/auth_customer_repository.dart';
import '../datasources/local_session_datasource.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._session);
  final LocalSessionDatasource _session;

  @override
  Future<Result<void>> sendOtp({required String phone}) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    await _session.savePendingPhone(phone);
    return const Success(null);
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    if (otp == '0000') return const FailureResult('Invalid OTP');
    final session = AuthSession(
      token: 'cust_jwt_$phone',
      phone: phone,
      isAuthenticated: true,
    );
    await _session.saveSession(session);
    return Success(session);
  }

  @override
  Future<Result<AuthSession>> loginWithWhatsApp() async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    const session = AuthSession(
      token: 'cust_jwt_wa',
      phone: '9876543210',
      isAuthenticated: true,
    );
    await _session.saveSession(session);
    return const Success(session);
  }

  @override
  Future<Result<void>> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    return const Success(null);
  }

  @override
  Future<Result<AuthSession>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    final session = AuthSession(
      token: 'cust_jwt_$email',
      phone: '',
      fullName: email.split('@').first,
      isAuthenticated: true,
    );
    await _session.saveSession(session);
    return Success(session);
  }

  @override
  Future<Result<AuthSession>> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    if (otp == '000000') return const FailureResult('Invalid OTP');
    final session = AuthSession(
      token: 'cust_jwt_$email',
      phone: '',
      fullName: email.split('@').first,
      isAuthenticated: true,
    );
    await _session.saveSession(session);
    return Success(session);
  }

  @override
  Future<Result<AuthSession>> loginWithGoogle({required String idToken}) async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    const session = AuthSession(
      token: 'cust_jwt_google',
      phone: '',
      fullName: 'Google User',
      isAuthenticated: true,
    );
    await _session.saveSession(session);
    return const Success(session);
  }

  @override
  Future<Result<AuthSession>> getSession() async {
    return Success(await _session.readSession() ?? AuthSession.empty);
  }

  @override
  Future<Result<void>> logout() async {
    await _session.clear();
    return const Success(null);
  }
}

class MockCustomerRepository implements CustomerRepository {
  MockCustomerRepository(this._session);
  final LocalSessionDatasource _session;

  @override
  Future<Result<CustomerProfile>> getProfile() async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    final phone = (await _session.readSession())?.phone ?? '9876543210';
    return Success(
      CustomerProfile(
        id: 'cust_001',
        name: 'Amit Kumar',
        phone: phone,
        walletBalance: 350,
      ),
    );
  }

  @override
  Future<Result<List<SavedAddress>>> getSavedAddresses() async {
    await Future<void>.delayed(AppConstants.mockNetworkDelay);
    return const Success([
      SavedAddress(
        id: 'addr_home',
        label: 'Home',
        address: 'A-42, Sector 62, Noida',
        isDefault: true,
      ),
      SavedAddress(
        id: 'addr_work',
        label: 'Work',
        address: 'Tower B, Sector 18, Noida',
      ),
    ]);
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
