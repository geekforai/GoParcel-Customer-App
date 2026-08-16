import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/auth/session_gate.dart';
import '../../core/constants/api_constants.dart';
import '../../core/debug/agent_log.dart';
import 'local_session_datasource.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});
  final String message;
  final int? statusCode;
  final List<dynamic>? errors;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._session, this._gate);

  final LocalSessionDatasource _session;
  final SessionGate _gate;
  final http.Client _http = http.Client();
  bool _refreshing = false;

  static const Duration requestTimeout = Duration(seconds: 8);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final session = await _session.readSession();
      final token = session?.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  bool _skipAuthRecovery(String path) {
    return path.contains(ApiConstants.authRefresh) ||
        path.contains(ApiConstants.authLogin) ||
        path.contains(ApiConstants.authRegister) ||
        path.contains(ApiConstants.authVerifyOtp) ||
        path.contains(ApiConstants.authGoogle) ||
        path.contains(ApiConstants.authPhoneSendOtp) ||
        path.contains(ApiConstants.authPhoneVerifyOtp) ||
        path.contains(ApiConstants.authWhatsappLogin) ||
        path.contains(ApiConstants.authLogout);
  }

  bool _isTransientNetwork(Object e) {
    if (e is TimeoutException || e is SocketException) return true;
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Connection aborted') ||
        s.contains('Connection reset') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable');
  }

  ApiException _asApiException(Object e) {
    if (e is ApiException) return e;
    if (e is TimeoutException) {
      return ApiException(
        'Server not reachable. Check internet or try again.',
        statusCode: 408,
      );
    }
    if (_isTransientNetwork(e)) {
      return ApiException(
        'Connection lost. Check internet and try again.',
        statusCode: 503,
      );
    }
    return ApiException('Network error. Please try again.');
  }

  Future<http.Response> _once(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? encoded,
  ) async {
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers).timeout(requestTimeout);
      case 'POST':
        return _http
            .post(uri, headers: headers, body: encoded)
            .timeout(requestTimeout);
      case 'PUT':
        return _http
            .put(uri, headers: headers, body: encoded)
            .timeout(requestTimeout);
      case 'DELETE':
        return _http.delete(uri, headers: headers).timeout(requestTimeout);
      default:
        throw ApiException('Unsupported method $method');
    }
  }

  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final local = await _session.readSession();
      final refresh = local?.refreshToken.trim() ?? '';
      if (local == null || refresh.isEmpty) return false;

      final res = await _http
          .post(
            _uri(ApiConstants.authRefresh),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(requestTimeout);

      if (res.statusCode < 200 || res.statusCode >= 300) return false;

      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return false;
      final data = (json['data'] as Map<String, dynamic>?) ?? json;
      final tokens = (data['tokens'] as Map<String, dynamic>?) ?? {};
      final access = tokens['accessToken']?.toString() ?? '';
      final nextRefresh = tokens['refreshToken']?.toString() ?? '';
      if (access.isEmpty) return false;

      final user = (data['user'] as Map<String, dynamic>?) ?? {};
      await _session.saveSession(
        local.copyWith(
          token: access,
          refreshToken: nextRefresh.isNotEmpty ? nextRefresh : refresh,
          phone: user['phone'] as String? ?? local.phone,
          userId: user['id']?.toString() ?? local.userId,
          fullName: user['fullName'] as String? ?? local.fullName,
          isAuthenticated: true,
        ),
      );
      _gate.markAuthenticated();
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
    bool allowRefresh = true,
  }) async {
    final sw = Stopwatch()..start();
    final uri = _uri(path, query);
    agentLog(
      'api_client.dart:_send',
      '$method start',
      hypothesisId: 'J',
      runId: 'post-fix',
      data: {'path': path, 'host': uri.host, 'app': 'customer'},
    );

    Object? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final headers = await _headers(auth: auth);
        final encoded = body == null ? null : jsonEncode(body);
        var res = await _once(method, uri, headers, encoded);

        if (res.statusCode == 401 &&
            auth &&
            allowRefresh &&
            !_skipAuthRecovery(path)) {
          final ok = await _tryRefresh();
          if (ok) {
            final retryHeaders = await _headers(auth: auth);
            res = await _once(method, uri, retryHeaders, encoded);
          } else {
            await _gate.forceLogout();
            throw ApiException(
              'Session expired. Please login again.',
              statusCode: 401,
            );
          }
        }

        if (res.statusCode == 401 && auth && !_skipAuthRecovery(path)) {
          await _gate.forceLogout();
          throw ApiException(
            'Session expired. Please login again.',
            statusCode: 401,
          );
        }

        agentLog(
          'api_client.dart:_send',
          '$method done',
          hypothesisId: 'J',
          runId: 'post-fix',
          data: {
            'path': path,
            'status': res.statusCode,
            'ms': sw.elapsedMilliseconds,
            'attempt': attempt,
            'app': 'customer',
          },
        );
        return res;
      } catch (e) {
        lastError = e;
        agentLog(
          'api_client.dart:_send',
          '$method error',
          hypothesisId: 'J',
          runId: 'post-fix',
          data: {
            'path': path,
            'ms': sw.elapsedMilliseconds,
            'attempt': attempt,
            'error': e.runtimeType.toString(),
            'transient': _isTransientNetwork(e),
            'app': 'customer',
          },
        );
        if (e is ApiException && e.statusCode != null && e.statusCode! < 500) {
          rethrow;
        }
        if (attempt < 2 && _isTransientNetwork(e)) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          continue;
        }
        throw _asApiException(e);
      }
    }
    throw _asApiException(lastError ?? 'Unknown network error');
  }

  Future<dynamic> getRaw(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final res = await _send('GET', path, query: query, auth: auth);
    return _decodeRaw(res);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final data = await getRaw(path, query: query, auth: auth);
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final res = await _send('POST', path, body: body, auth: auth);
    final data = _decodeRaw(res);
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final res = await _send('PUT', path, body: body, auth: auth);
    final data = _decodeRaw(res);
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  Future<Map<String, dynamic>> delete(String path, {bool auth = true}) async {
    final res = await _send('DELETE', path, auth: auth);
    final data = _decodeRaw(res);
    if (data is Map<String, dynamic>) return data;
    return {'data': data};
  }

  dynamic _decodeRaw(http.Response res) {
    dynamic json;
    if (res.body.isNotEmpty) {
      json = jsonDecode(res.body);
    } else {
      json = <String, dynamic>{};
    }

    if (json is! Map<String, dynamic>) {
      if (res.statusCode >= 200 && res.statusCode < 300) return json;
      throw ApiException(
        'Request failed (${res.statusCode})',
        statusCode: res.statusCode,
      );
    }

    final success = json['success'] == true;
    if (res.statusCode >= 200 &&
        res.statusCode < 300 &&
        (success || !json.containsKey('success'))) {
      return json.containsKey('data') ? json['data'] : json;
    }

    final message =
        (json['message'] as String?) ?? 'Request failed (${res.statusCode})';
    throw ApiException(
      message,
      statusCode: res.statusCode,
      errors: json['errors'] as List?,
    );
  }
}
