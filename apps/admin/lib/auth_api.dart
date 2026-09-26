import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl;

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthApiClient {
  AuthApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;

  Future<void> login({required String email, required String password}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/login'),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode != 200) {
      throw AuthApiException(_message(response), statusCode: response.statusCode);
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final token = body['accessToken'] as String?;
    final expiresAtRaw = body['expiresAt'] as String?;
    final ownerEmail = body['email'] as String? ?? email.trim();
    if (token == null || expiresAtRaw == null) {
      throw AuthApiException('پاسخ ورود از سرور کامل نیست.');
    }

    OwnerSession.instance.establish(
      accessToken: token,
      expiresAt: DateTime.parse(expiresAtRaw),
      email: ownerEmail,
    );
  }

  Future<void> validateSession() async {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) throw AuthApiException('نشست شما منقضی شده است.', statusCode: 401);

    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/auth/session'),
      headers: {'authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 401) OwnerSession.instance.clear();
      throw AuthApiException(_message(response), statusCode: response.statusCode);
    }
  }

  String _message(http.Response response) {
    if (response.statusCode == 401) return 'ایمیل یا رمز عبور صحیح نیست.';
    if (response.statusCode == 429) return 'تلاش‌های ورود زیاد بود؛ کمی بعد دوباره امتحان کنید.';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['message'] is String) return body['message'] as String;
    } catch (_) {}
    return 'ورود با خطا مواجه شد (${response.statusCode}).';
  }
}
