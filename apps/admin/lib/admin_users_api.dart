import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl;

class AdminUsersApiException implements Exception {
  AdminUsersApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AdminUsersApiClient {
  AdminUsersApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;

  Future<List<AdminUser>> fetchUsers({String? storeId}) async {
    final response = await _client.get(_uri('/api/v1/admin/users', storeId: storeId), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw AdminUsersApiException(_message(response), statusCode: response.statusCode);
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body.map((item) => AdminUser.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<AdminRole>> fetchRoles() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/users/roles'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw AdminUsersApiException(_message(response), statusCode: response.statusCode);
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return body.map((item) => AdminRole.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<AdminUserInvitation> createUser({required String email, required String displayName, required String role, required List<String> permissions, String? storeId}) async {
    final response = await _client.post(
      _uri('/api/v1/admin/users', storeId: storeId),
      headers: _headers(json: true),
      body: jsonEncode({'email': email.trim(), 'displayName': displayName.trim(), 'role': role, 'permissions': permissions}),
    );
    _guard(response);
    if (response.statusCode != 201) throw AdminUsersApiException(_message(response), statusCode: response.statusCode);
    return AdminUserInvitation.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminUser> setPermissions(String id, List<String> permissions, {String? storeId}) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/api/v1/admin/users/$id/permissions').replace(queryParameters: {
        if (storeId != null && storeId.trim().isNotEmpty) 'storeId': storeId.trim(),
      }),
      headers: _headers(json: true),
      body: jsonEncode({'permissions': permissions}),
    );
    _guard(response);
    if (response.statusCode != 200) throw AdminUsersApiException(_message(response), statusCode: response.statusCode);
    return AdminUser.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminUser> setStatus(String id, bool isActive, {String? storeId}) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/api/v1/admin/users/$id/status').replace(queryParameters: {
        if (storeId != null && storeId.trim().isNotEmpty) 'storeId': storeId.trim(),
      }),
      headers: _headers(json: true),
      body: jsonEncode({'isActive': isActive}),
    );
    _guard(response);
    if (response.statusCode != 200) throw AdminUsersApiException(_message(response), statusCode: response.statusCode);
    return AdminUser.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Uri _uri(String path, {String? storeId}) => Uri.parse('$baseUrl$path').replace(queryParameters: {
        if (storeId != null && storeId.trim().isNotEmpty) 'storeId': storeId.trim(),
      });

  Map<String, String> _headers({bool json = false}) {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) throw AdminUsersApiException('نشست شما منقضی شده است.', statusCode: 401);
    return {
      'authorization': 'Bearer $token',
      if (json) 'content-type': 'application/json; charset=utf-8',
    };
  }

  void _guard(http.Response response) {
    if (response.statusCode == 401) OwnerSession.instance.clear();
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        if (body['message'] is String) return body['message'] as String;
        if (body['errors'] is Map) return 'اطلاعات کاربر کامل یا معتبر نیست.';
      }
    } catch (_) {}
    if (response.statusCode == 403) return 'فقط مدیر اصلی می‌تواند کاربران را مدیریت کند.';
    if (response.statusCode == 409) return 'کاربری با این ایمیل در این فروشگاه وجود دارد.';
    return 'ارتباط با مدیریت کاربران برقرار نشد (${response.statusCode}).';
  }
}

class AdminUserInvitation {
  const AdminUserInvitation({required this.user, required this.invitationToken, required this.expiresAt});

  final AdminUser user;
  final String invitationToken;
  final DateTime expiresAt;

  factory AdminUserInvitation.fromJson(Map<String, dynamic> json) => AdminUserInvitation(
        user: AdminUser.fromJson(json['user'] as Map<String, dynamic>),
        invitationToken: json['invitationToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  String get shareUrl {
    final uri = Uri.base.replace(fragment: 'invite=$invitationToken');
    return uri.toString();
  }
}

class AdminUser {
  const AdminUser({required this.id, required this.email, required this.displayName, required this.role, required this.isActive, required this.permissions, required this.createdAt, this.deactivatedAt, this.storeId = 'default', this.hasPassword = false});

  final String id;
  final String storeId;
  final String email;
  final String displayName;
  final String role;
  final bool isActive;
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime? deactivatedAt;
  final bool hasPassword;

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'].toString(),
        storeId: json['storeId'] as String? ?? 'default',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        role: json['role'] as String? ?? 'Owner',
        isActive: json['isActive'] as bool? ?? false,
        permissions: (json['permissions'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        deactivatedAt: json['deactivatedAt'] is String ? DateTime.parse(json['deactivatedAt'] as String) : null,
        hasPassword: json['hasPassword'] as bool? ?? false,
      );

  String get roleLabel => AdminUsersRoleLabels.of(role);
}

class AdminRole {
  const AdminRole({required this.role, required this.permissions, required this.titleFa});

  final String role;
  final List<String> permissions;
  final String titleFa;

  factory AdminRole.fromJson(Map<String, dynamic> json) => AdminRole(
        role: json['role'] as String? ?? '',
        permissions: (json['permissions'] as List<dynamic>? ?? const []).whereType<String>().toList(),
        titleFa: json['titleFa'] as String? ?? json['role'] as String? ?? '',
      );
}

abstract final class AdminUsersRoleLabels {
  static String of(String role) => switch (role) {
        'Owner' => 'مدیر اصلی',
        'StoreManager' => 'مدیر فروشگاه',
        'SalesOperator' => 'اپراتور فروش',
        'WarehouseOperator' => 'اپراتور انبار',
        'Accountant' => 'حسابدار',
        'CustomerSupport' => 'پشتیبانی مشتری',
        'CorporateSales' => 'فروش سازمانی',
        'ContentManager' => 'مدیر محتوا',
        'MarketingManager' => 'مدیر بازاریابی',
        'ReadOnlyAnalyst' => 'تحلیلگر فقط‌خواندنی',
        _ => role,
      };
}

\n