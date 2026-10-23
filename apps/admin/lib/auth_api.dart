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

class AdminGoogleAuthConfig {
  const AdminGoogleAuthConfig({required this.enabled, this.clientId});
  final bool enabled;
  final String? clientId;
}

class AdminGoogleAuthChallenge {
  const AdminGoogleAuthChallenge({required this.id, required this.nonce});
  final String id;
  final String nonce;
}

class AdminGoogleLoginResult {
  const AdminGoogleLoginResult({required this.status, this.email});
  final String status;
  final String? email;
}

class AuthApiClient {
  AuthApiClient({http.Client? client, String? baseUrl, String? storeId})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), ''),
      storeId = _normalizeStoreId(storeId ?? adminStoreId);

  final http.Client _client;
  final String baseUrl;
  final String storeId;

  Future<void> login({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    OwnerSession.instance.clear();
    final revision = OwnerSession.instance.revision;
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/login'),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'storeId': storeId,
        if (mfaCode != null && mfaCode.trim().isNotEmpty)
          'mfaCode': _asciiDigits(mfaCode.trim()),
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
    await _establishSession(
      body,
      emailFallback: email.trim(),
      revision: revision,
    );
  }

  Future<AdminGoogleAuthConfig> googleAuthConfig() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/auth/google/config'),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _googleMessage(response),
        statusCode: response.statusCode,
      );
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return AdminGoogleAuthConfig(
      enabled: body['enabled'] == true,
      clientId: body['clientId'] as String?,
    );
  }

  Future<AdminGoogleAuthChallenge> createGoogleAuthChallenge() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/google/challenge'),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: '{}',
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _googleMessage(response),
        statusCode: response.statusCode,
      );
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final id = body['challengeId'] as String?;
    final nonce = body['nonce'] as String?;
    if (id == null || nonce == null || id.isEmpty || nonce.isEmpty) {
      throw AuthApiException('آماده‌سازی ورود با گوگل کامل نشد.');
    }
    return AdminGoogleAuthChallenge(id: id, nonce: nonce);
  }

  Future<AdminGoogleLoginResult> loginWithGoogle({
    required String credential,
    required String challengeId,
    String? password,
    String? mfaCode,
  }) async {
    OwnerSession.instance.clear();
    final revision = OwnerSession.instance.revision;
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/google/login'),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'credential': credential,
        'challengeId': challengeId,
        'storeId': storeId,
        if (password != null && password.isNotEmpty) 'password': password,
        if (mfaCode != null && mfaCode.trim().isNotEmpty)
          'mfaCode': _asciiDigits(mfaCode.trim()),
      }),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _googleMessage(response),
        statusCode: response.statusCode,
      );
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status == 'link_required') {
      return AdminGoogleLoginResult(
        status: status!,
        email: body['email'] as String?,
      );
    }
    if (status != 'authenticated')
      throw AuthApiException('پاسخ ورود گوگل کامل نیست.');
    await _establishSession(body, emailFallback: '', revision: revision);
    return const AdminGoogleLoginResult(status: 'authenticated');
  }

  Future<void> acceptInvitationWithGoogle({
    required String credential,
    required String challengeId,
    required String invitationToken,
    String? mfaCode,
  }) async {
    OwnerSession.instance.clear();
    final revision = OwnerSession.instance.revision;
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/auth/google/accept-invite'),
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'credential': credential,
        'challengeId': challengeId,
        'invitationToken': invitationToken,
        if (mfaCode != null && mfaCode.trim().isNotEmpty)
          'mfaCode': _asciiDigits(mfaCode.trim()),
      }),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _googleMessage(response),
        statusCode: response.statusCode,
      );
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (body['status'] != 'authenticated')
      throw AuthApiException('پذیرش دعوت با گوگل کامل نشد.');
    await _establishSession(body, emailFallback: '', revision: revision);
  }

  Future<void> _establishSession(
    Map<String, dynamic> body, {
    required String emailFallback,
    required int revision,
  }) async {
    final token = body['accessToken'] as String?;
    final expiresAtRaw = body['expiresAt'] as String?;
    final ownerEmail = body['email'] as String? ?? emailFallback;
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

    // Keep the token provisional until the API confirms the issued session.
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
    if (OwnerSession.instance.revision != revision) {
      throw AuthApiException('درخواست ورود پایان یافته است؛ دوباره تلاش کنید.');
    }
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

  Future<String> stepUp({required String password, String? mfaCode}) async {
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
        if (mfaCode != null && mfaCode.trim().isNotEmpty)
          'mfaCode': _asciiDigits(mfaCode.trim()),
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
    final now = DateTime.now().toUtc();
    if (stepUpToken == null ||
        stepUpToken.isEmpty ||
        expiresAt == null ||
        !expiresAt.isAfter(now) ||
        expiresAt.isAfter(now.add(const Duration(minutes: 5)))) {
      throw AuthApiException('پاسخ تأیید هویت از سرور کامل نیست.');
    }
    OwnerSession.instance.rememberStepUpToken(stepUpToken, expiresAt);
    return stepUpToken;
  }

  Future<AdminMfaStatus> getMfaStatus() async {
    final response = await _mfaRequest('GET', '/auth/mfa');
    if (response.statusCode != 200)
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return AdminMfaStatus(
      enabled: body['enabled'] == true,
      pendingExpiresAt: DateTime.tryParse(
        body['pendingEnrollmentExpiresAt'] as String? ?? '',
      ),
    );
  }

  Future<AdminMfaEnrollment> beginMfaEnrollment({
    required String password,
    String? mfaCode,
  }) async {
    final response = await _mfaRequest(
      'POST',
      '/auth/mfa/enrollment',
      body: {
        'password': password,
        if (mfaCode != null && mfaCode.trim().isNotEmpty)
          'mfaCode': mfaCode.trim(),
      },
    );
    if (response.statusCode != 200)
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final secret = body['secret'] as String?;
    final provisioningUri = body['provisioningUri'] as String?;
    final expiresAt = DateTime.tryParse(body['expiresAt'] as String? ?? '');
    if (secret == null || provisioningUri == null || expiresAt == null) {
      throw AuthApiException('پاسخ ثبت تأیید دومرحله‌ای کامل نیست.');
    }
    return AdminMfaEnrollment(
      secret: secret,
      provisioningUri: provisioningUri,
      expiresAt: expiresAt,
    );
  }

  Future<void> confirmMfaEnrollment(String code) async {
    final response = await _mfaRequest(
      'POST',
      '/auth/mfa/confirm',
      body: {'mfaCode': _asciiDigits(code.trim())},
    );
    if (response.statusCode != 200)
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final token = body['accessToken'] as String?;
    final expiresAt = DateTime.tryParse(body['expiresAt'] as String? ?? '');
    if (token == null ||
        token.isEmpty ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw AuthApiException('پاسخ فعال‌سازی تأیید دومرحله‌ای کامل نیست.');
    }
    OwnerSession.instance.replaceAccessToken(
      accessToken: token,
      expiresAt: expiresAt,
    );
  }

  Future<void> disableMfa({
    required String password,
    required String mfaCode,
  }) async {
    final response = await _mfaRequest(
      'POST',
      '/auth/mfa/disable',
      body: {'password': password, 'mfaCode': _asciiDigits(mfaCode.trim())},
    );
    if (response.statusCode != 204)
      throw AuthApiException(
        _message(response),
        statusCode: response.statusCode,
      );
  }

  Future<http.Response> _mfaRequest(
    String method,
    String path, {
    Object? body,
  }) async {
    final token = OwnerSession.instance.bearerToken;
    if (token == null)
      throw AuthApiException('نشست شما منقضی شده است.', statusCode: 401);
    final uri = Uri.parse('$baseUrl/api/v1/admin$path');
    final headers = {
      'authorization': 'Bearer $token',
      'content-type': 'application/json; charset=utf-8',
    };
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      _ => await _client.post(uri, headers: headers, body: jsonEncode(body)),
    };
    if (response.statusCode == 401) OwnerSession.instance.clear();
    return response;
  }

  static String _asciiDigits(String value) =>
      value.replaceAllMapped(RegExp(r'[۰-۹٠-٩]'), (match) {
        final digit = match.group(0)!;
        final codePoint = digit.codeUnitAt(0);
        return String.fromCharCode(
          codePoint >= 0x6f0
              ? codePoint - 0x6f0 + 0x30
              : codePoint - 0x660 + 0x30,
        );
      });

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

  String _googleMessage(http.Response response) {
    if (response.statusCode == 428) return 'کد تأیید دومرحله‌ای را وارد کنید.';
    if (response.statusCode == 429)
      return 'تلاش‌های ورود زیاد بود؛ کمی بعد دوباره امتحان کنید.';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['message'] is String) {
        final message = (body['message'] as String).trim();
        if (message.isNotEmpty) return message;
      }
      if (body is Map<String, dynamic> && body['detail'] is String) {
        final detail = (body['detail'] as String).trim();
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}
    if (response.statusCode == 401) return 'پاسخ گوگل یا رمز حساب صحیح نیست.';
    return _message(response);
  }

  String _message(http.Response response) {
    if (response.statusCode == 401) return 'ایمیل یا رمز عبور صحیح نیست.';
    if (response.statusCode == 428) return 'کد تأیید دومرحله‌ای را وارد کنید.';
    if (response.statusCode == 403) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body is Map<String, dynamic> && body['code'] == 'mfa_invalid')
          return 'کد تأیید دومرحله‌ای معتبر نیست.';
      } catch (_) {}
    }
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

class AdminMfaStatus {
  const AdminMfaStatus({required this.enabled, this.pendingExpiresAt});
  final bool enabled;
  final DateTime? pendingExpiresAt;
}

class AdminMfaEnrollment {
  const AdminMfaEnrollment({
    required this.secret,
    required this.provisioningUri,
    required this.expiresAt,
  });
  final String secret;
  final String provisioningUri;
  final DateTime expiresAt;
}
