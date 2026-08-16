abstract final class ApiConstants {
  /// Override at build time:
  /// flutter run --dart-define=API_BASE_URL=http://YOUR_HOST/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://13.204.187.217/api/v1',
  );

  /// Web OAuth client ID — needed so Google returns an idToken on Android.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static const String role = 'customer';
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authGoogle = '/auth/google';
  static const String authPhoneSendOtp = '/auth/phone/send-otp';
  static const String authPhoneVerifyOtp = '/auth/phone/verify-otp';
  static const String authWhatsappLogin = '/auth/phone/whatsapp-login';
  static const String authLogout = '/auth/logout';
  static const String authRefresh = '/auth/refresh-token';
  static const String authMe = '/auth/me';
  static const String customerProfile = '/customer/profile';
  static const String customerAddresses = '/customer/addresses';
  static const String customerAddress = '/customer/address';
  static const String shipments = '/shipment';
  static const String pickups = '/pickup';
  static const String notifications = '/notification';
}
