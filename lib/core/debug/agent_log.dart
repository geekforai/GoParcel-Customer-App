import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Debug-mode agent logger (session d5c03e). Do not log secrets/PII.
void agentLog(
  String location,
  String message, {
  String hypothesisId = '',
  Map<String, Object?> data = const {},
  String runId = 'pre',
}) {
  // #region agent log
  final payload = <String, Object?>{
    'sessionId': 'd5c03e',
    'runId': runId,
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  };
  final line = jsonEncode(payload);
  debugPrint('AGENT_LOG $line');

  try {
    File('/Users/amitkumar/Desktop/GoParcel/.cursor/debug-d5c03e.log')
        .writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {}

  final body = line;
  const headers = {
    'Content-Type': 'application/json',
    'X-Debug-Session-Id': 'd5c03e',
  };
  const path = '/ingest/cbbbc0a2-eab7-41c2-816f-450319630625';
  for (final host in ['127.0.0.1', '10.0.2.2', '10.32.38.147']) {
    http
        .post(
          Uri.parse('http://$host:7911$path'),
          headers: headers,
          body: body,
        )
        .timeout(const Duration(milliseconds: 600))
        .catchError((_) => http.Response('', 599));
  }
  // #endregion
}
