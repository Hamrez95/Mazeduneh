import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl;

class AuditLogApiException implements Exception {
  AuditLogApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuditLogApiClient {
  AuditLogApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;

  Future<List<AdminAuditLogEntry>> fetchLogs({String? entityType, String? entityId, int limit = 100}) async {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) throw AuditLogApiException('نشست شما منقضی شده است.', statusCode: 401);
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/audit-log').replace(queryParameters: {
        if (entityType != null && entityType.trim().isNotEmpty) 'entityType': entityType.trim(),
        if (entityId != null && entityId.trim().isNotEmpty) 'entityId': entityId.trim(),
        'limit': '$limit',
      }),
      headers: {'authorization': 'Bearer $token'},
    );
    if (response.statusCode == 401) {
      OwnerSession.instance.clear();
      throw AuditLogApiException('نشست شما منقضی شده است؛ دوباره وارد شوید.', statusCode: 401);
    }
    if (response.statusCode != 200) throw AuditLogApiException(_message(response), statusCode: response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => AdminAuditLogEntry.fromJson(item as Map<String, dynamic>)).toList();
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['message'] is String) return body['message'] as String;
    } catch (_) {}
    return 'ارتباط با سرویس گزارش فعالیت برقرار نشد (${response.statusCode}).';
  }
}

class AdminAuditLogEntry {
  const AdminAuditLogEntry({
    required this.id,
    required this.actor,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.beforeJson,
    required this.afterJson,
    required this.reason,
    required this.requestId,
    required this.occurredAt,
  });

  final String id;
  final String actor;
  final String action;
  final String entityType;
  final String entityId;
  final String? beforeJson;
  final String? afterJson;
  final String reason;
  final String requestId;
  final DateTime occurredAt;

  factory AdminAuditLogEntry.fromJson(Map<String, dynamic> json) => AdminAuditLogEntry(
        id: json['id'].toString(),
        actor: json['actor'] as String? ?? 'نامشخص',
        action: json['action'] as String? ?? 'unknown',
        entityType: json['entityType'] as String? ?? 'Unknown',
        entityId: json['entityId'] as String? ?? '',
        beforeJson: _snapshot(json['beforeJson']),
        afterJson: _snapshot(json['afterJson']),
        reason: json['reason'] as String? ?? 'بدون توضیح',
        requestId: json['requestId'] as String? ?? '',
        occurredAt: DateTime.parse(json['occurredAt'] as String),
      );

  String get actionLabel => switch (action) {
        'inventory.adjustment' => 'اصلاح موجودی',
        'product.publication' => 'تغییر انتشار محصول',
        'admin-user.created' => 'افزودن کاربر مدیریتی',
        'admin-user.status-changed' => 'تغییر وضعیت کاربر مدیریتی',
        _ => action,
      };

  String get entityLabel => switch (entityType) {
        'ProductVariant' => 'SKU محصول',
        'Product' => 'محصول',
        'AdminUser' => 'کاربر مدیریتی',
        _ => entityType,
      };

  static String? _snapshot(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }
}
