import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/customer.dart';

class LocalSessionDatasource {
  LocalSessionDatasource(this._prefs);
  final SharedPreferences _prefs;

  static const _refreshKey = 'gp_customer_refresh';
  static const _userIdKey = 'gp_customer_user_id';
  static const _nameKey = 'gp_customer_name';

  Future<void> savePendingPhone(String phone) async {
    await _prefs.setString(AppConstants.phoneKey, phone);
  }

  Future<String?> readPendingPhone() async => _prefs.getString(AppConstants.phoneKey);

  Future<void> saveSession(AuthSession session) async {
    await _prefs.setString(AppConstants.sessionKey, session.token);
    await _prefs.setString(_refreshKey, session.refreshToken);
    await _prefs.setString(AppConstants.phoneKey, session.phone);
    await _prefs.setString(_userIdKey, session.userId);
    await _prefs.setString(_nameKey, session.fullName);
  }

  Future<AuthSession?> readSession() async {
    final token = _prefs.getString(AppConstants.sessionKey);
    if (token == null || token.isEmpty) return null;
    return AuthSession(
      token: token,
      refreshToken: _prefs.getString(_refreshKey) ?? '',
      phone: _prefs.getString(AppConstants.phoneKey) ?? '',
      userId: _prefs.getString(_userIdKey) ?? '',
      fullName: _prefs.getString(_nameKey) ?? '',
      isAuthenticated: true,
    );
  }

  Future<void> clear() async {
    await _prefs.remove(AppConstants.sessionKey);
    await _prefs.remove(_refreshKey);
    await _prefs.remove(AppConstants.phoneKey);
    await _prefs.remove(_userIdKey);
    await _prefs.remove(_nameKey);
  }

  Future<void> setLocationGranted(bool value) async {
    await _prefs.setBool(AppConstants.locationGrantedKey, value);
  }

  bool isLocationGranted() =>
      _prefs.getBool(AppConstants.locationGrantedKey) ?? false;
}
