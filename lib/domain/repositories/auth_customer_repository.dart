import '../../core/errors/result.dart';
import '../entities/customer.dart';

abstract class AuthRepository {
  Future<Result<void>> sendOtp({required String phone});
  Future<Result<AuthSession>> verifyOtp({required String phone, required String otp});
  Future<Result<AuthSession>> loginWithWhatsApp();
  Future<Result<void>> registerWithEmail({
    required String fullName,
    required String email,
    required String password,
  });
  Future<Result<AuthSession>> loginWithEmail({
    required String email,
    required String password,
  });
  Future<Result<AuthSession>> verifyEmailOtp({
    required String email,
    required String otp,
  });
  Future<Result<AuthSession>> loginWithGoogle({required String idToken});
  Future<Result<AuthSession>> getSession();
  Future<Result<void>> logout();
}

abstract class CustomerRepository {
  Future<Result<CustomerProfile>> getProfile();
  Future<Result<List<SavedAddress>>> getSavedAddresses();
  Future<Result<void>> setLocationGranted(bool granted);
  Future<Result<bool>> isLocationGranted();
}
