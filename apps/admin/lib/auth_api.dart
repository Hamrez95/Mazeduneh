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
    OwnerSession.instance.clear();
    final revision = OwnerSession.instance.revision;
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/login'),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode != 200) {
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    }

    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final token = body['accessToken'] as String?;
    final expiresAtRaw = body['expiresAt'] as String?;
    final ownerEmail = body['email'] as String? ?? email.trim();
    final role = body['role'] as String? ?? 'Owner';
    final permissions = _stringList(body['permissions']);
    final storeId = body['storeId'] as String? ?? 'default';
    if (token == null || expiresAtRaw == null) {
      throw AuthApiException('پاسخ ورود از سرور کامل نیست.');
    }

    // Do not publish provisional credentials or build protected pages until validated.
    final identity = await _readSession(token);
    final expiry = DateTime.tryParse(expiresAtRaw);
    if (expiry == null || !expiry.isAfter(DateTime.now().toUtc())) {
      throw AuthApiException('نشست دریافتی معتبر نیست.');
    }
    if (OwnerSession.instance.revision != revision)
      throw AuthApiException('درخواست ورود پایان یافته است؛ دوباره تلاش کنید.');
    OwnerSession.instance.establish(
      accessToken: token,
      expiresAt: expiry,
      email: ownerEmail,
      role: identity['role'] as String? ?? role,
      permissions: identity.containsKey('permissions')
          ? _stringList(identity['permissions'])
          : permissions,
      storeId: identity['storeId'] as String? ?? storeId,
    );
  }

  Future<void> acceptInvitation({
    required String token,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/accept-invite'),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({'token': token, 'password': password}),
    );
    if (response.statusCode != 204) {
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> logout() async {
    final token = OwnerSession.instance.bearerToken;
    // Remove local credentials and all protected routes immediately, even offline.
    OwnerSession.instance.clear();
    if (token == null) return;
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/logout'),
      headers: {'authorization': 'Bearer $token'},
    );
    if (response.statusCode != 204) {
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> validateSession() async {
    final token = OwnerSession.instance.bearerToken;
    if (token == null)
      throw AuthApiException('نشست شما منقضی شده است.', statusCode: 401);

    Map<String, dynamic> body;
    try {
      body = await _readSession(token);
    } catch (_) {
      if (OwnerSession.instance.bearerToken == token)
        OwnerSession.instance.clear();
      rethrow;
    }
    if (OwnerSession.instance.bearerToken != token) return;
    OwnerSession.instance.updateIdentity(
      role: body['role'] as String? ?? OwnerSession.instance.role ?? 'Owner',
      permissions: body.containsKey('permissions')
          ? _stringList(body['permissions'])
          : OwnerSession.instance.permissions,
      storeId: body['storeId'] as String?,
    );
  }

  Future<Map<String, dynamic>> _readSession(String token) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/auth/session'),
      headers: {'authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200)
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['authenticated'] != true)
      throw AuthApiException('نشست تأیید نشد.', statusCode: 401);
    return body;
  }

  List<String> _stringList(Object? value) => value is List
      ? value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList()
      : const [];

  String _message(http.Response response) {
    if (response.statusCode == 401) return 'ایمیل یا رمز عبور صحیح نیست.';
    if (response.statusCode == 400) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic> && body['message'] is String)
          return body['message'] as String;
      } catch (_) {}
      return 'دعوت معتبر نیست یا منقضی شده است.';
    }
    if (response.statusCode == 429)
      return 'تلاش‌های ورود زیاد بود؛ کمی بعد دوباره امتحان کنید.';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['message'] is String)
        return body['message'] as String;
    } catch (_) {}
    return 'ورود با خطا مواجه شد (${response.statusCode}).';
  }
}
