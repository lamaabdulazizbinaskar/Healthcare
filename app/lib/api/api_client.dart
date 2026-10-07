import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Base URL of the FastAPI backend.
/// * Flutter web served by the backend (recommended demo): same origin.
/// * `flutter run -d chrome`: pass --dart-define=API_BASE=http://localhost:8000
/// * Android emulator: --dart-define=API_BASE=http://10.0.2.2:8000
String apiBase() {
  const fromEnv = String.fromEnvironment('API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kIsWeb) return Uri.base.origin;
  return 'http://localhost:8000';
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => 'ApiException($status): $message';
}

class ApiClient {
  ApiClient(this.userId);
  final String userId;

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${apiBase()}/api$path').replace(queryParameters: q);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'X-User-Id': userId,
  };

  dynamic _decode(http.Response r) {
    final body = utf8.decode(r.bodyBytes);
    if (r.statusCode >= 400) {
      String msg = body;
      try {
        msg = (jsonDecode(body) as Map)['detail'].toString();
      } catch (_) {}
      throw ApiException(r.statusCode, msg);
    }
    return body.isEmpty ? null : jsonDecode(body);
  }

  Future<dynamic> get(String path, [Map<String, String>? q]) async =>
      _decode(await http.get(_u(path, q), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) async => _decode(
    await http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})),
  );

  // --- Typed helpers ---
  Future<Map<String, dynamic>> health() async =>
      await get('/health') as Map<String, dynamic>;
  Future<List<dynamic>> diseases() async =>
      await get('/diseases') as List<dynamic>;
  Future<Map<String, dynamic>> profile() async =>
      await get('/profile') as Map<String, dynamic>;
  Future<Map<String, dynamic>> onboard(Map<String, dynamic> profile) async =>
      await post('/onboarding', profile) as Map<String, dynamic>;
  Future<void> setLanguage(String lang) =>
      post('/profile/language', {'language': lang});
  Future<Map<String, dynamic>> checklist() async =>
      await get('/checklist') as Map<String, dynamic>;
  Future<void> check(String goalId, bool done) =>
      post('/checklist/$goalId', {'done': done});
  Future<Map<String, dynamic>> adapt(String goalId, String reason) async =>
      await post('/adapt/$goalId', {'reason': reason}) as Map<String, dynamic>;
  Future<List<dynamic>> bp() async => await get('/bp') as List<dynamic>;
  Future<Map<String, dynamic>> addBp(
    int sys,
    int dia,
    int? pulse,
    List<String> symptoms,
  ) async =>
      await post('/bp', {
            'systolic': sys,
            'diastolic': dia,
            'pulse': pulse,
            'symptoms': symptoms,
          })
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> safetyCheck(List<String> symptoms) async =>
      await post('/safety/check', {'symptoms': symptoms})
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> report() async =>
      await get('/report') as Map<String, dynamic>;
  String reportPdfUrl() => _u('/report.pdf', {'uid': userId}).toString();
  Future<void> resetDemo() => post('/demo/reset');
  Future<Map<String, dynamic>> intake() async =>
      await get('/intake') as Map<String, dynamic>;
  Future<Map<String, dynamic>> ask(String question) async =>
      await post('/ask', {'question': question}) as Map<String, dynamic>;
  Future<Map<String, dynamic>> meals() async =>
      await get('/meals') as Map<String, dynamic>;
  Future<List<dynamic>> glucose() async =>
      await get('/glucose') as List<dynamic>;
  Future<Map<String, dynamic>> addGlucose(
    int value,
    String context,
    List<String> symptoms,
  ) async =>
      await post('/glucose', {
            'value': value,
            'context': context,
            'symptoms': symptoms,
          })
          as Map<String, dynamic>;
  Future<Map<String, dynamic>> plan() async =>
      await get('/plan') as Map<String, dynamic>;
  Future<Map<String, dynamic>> water() async =>
      await get('/water') as Map<String, dynamic>;
  Future<Map<String, dynamic>> addWater(int delta, {int? target}) async =>
      await post('/water', {'delta': delta, 'target': ?target})
          as Map<String, dynamic>;

  Future<Map<String, dynamic>> mealCheck(
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    final req = http.MultipartRequest('POST', _u('/meal-check'))
      ..headers['X-User-Id'] = userId
      ..files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );
    final resp = await http.Response.fromStream(await req.send());
    return _decode(resp) as Map<String, dynamic>;
  }
}
