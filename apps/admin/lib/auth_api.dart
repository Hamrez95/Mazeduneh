import 'dart:convert';

import 'package:http/http.dart' as http;

import 'admin_config.dart';
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
  AuthApiClient({http.Client? client, String? baseUrl, String? storeId})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
      storeId = _normalizeStoreId(storeId ?? adminStoreId);

  final http.Client _client;
  final String baseUrl;
  final String storeId;

  Future<void> login({required String email, required String password}) async {
    OwnerSession.instance.clear();
    final revision = OwnerSession.instance.revision;
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/login'),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'storeId': storeId,
      }),
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
    final loginStoreId = body['storeId'] as String? ?? 'default';
    if (token == null || expiresAtRaw == null) {
      throw AuthApiException('پاسخ ورود از سرور کامل نیست.');
    }
    if (loginStoreId != storeId) {
      throw AuthApiException(
        'حساب شما به فروشگاه پیکربندی‌شده دسترسی ندارد.',
        statusCode: 403,
      );
    }

    // Do not publish provisional credentials or build protected pages until validated.
    final identity = await _readSession(token);
    final authenticatedStoreId = identity['storeId'] as String?;
    if (authenticatedStoreId == null || authenticatedStoreId != storeId) {
      throw AuthApiException(
        'حساب شما به فروشگاه پیکربندی‌شده دسترسی ندارد.',
        statusCode: 403,
      );
    }
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
      storeId: authenticatedStoreId,
    );
  }

  Future<String> stepUp({required String password, String? totpCode}) async {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) {
      throw AuthApiException('نشست شما منقضی شده است.', statusCode: 401);
    }
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/step-up'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'password': password,
        if (totpCode != null && totpCode.isNotEmpty) 'totpCode': totpCode,
      }),
    );
    if (response.statusCode == 401) OwnerSession.instance.clear();
    if (response.statusCode != 200) {
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final stepUpToken = body['stepUpToken'] as String?;
    final expiresAt = DateTime.tryParse(body['expiresAt'] as String? ?? '');
    if (stepUpToken == null ||
        stepUpToken.isEmpty ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now().toUtc()) ||
        expiresAt.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
        )) {
      throw AuthApiException('پاسخ تأیید هویت از سرور کامل نیست.');
    }
    OwnerSession.instance.rememberStepUpToken(stepUpToken, expiresAt);
    return stepUpToken;
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

  static String _normalizeStoreId(String value) {
    final normalizedStoreId = value.trim();
    return normalizedStoreId.isEmpty ? 'default' : normalizedStoreId;
  }

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
