import 'package:flutter/foundation.dart';

import '../../data/datasources/local_session_datasource.dart';

/// Global auth gate for GoRouter redirects + ApiClient 401 handling.
class SessionGate extends ChangeNotifier {
  SessionGate(this._session);

  final LocalSessionDatasource _session;
  bool _authenticated = false;
  bool _hydrated = false;

  bool get isAuthenticated => _authenticated;
  bool get isHydrated => _hydrated;

  Future<void> hydrate() async {
    final local = await _session.readSession();
    final next = local != null &&
        local.isAuthenticated &&
        local.token.trim().isNotEmpty;
    _hydrated = true;
    if (_authenticated != next) {
      _authenticated = next;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  void markAuthenticated() {
    if (_authenticated) return;
    _authenticated = true;
    _hydrated = true;
    notifyListeners();
  }

  /// Clears local session and notifies router to send user to Login.
  Future<void> forceLogout() async {
    await _session.clear();
    if (!_authenticated && _hydrated) {
      notifyListeners();
      return;
    }
    _authenticated = false;
    _hydrated = true;
    notifyListeners();
  }
}
