import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/audit_log_api.dart';
import 'package:mazeduneh_admin/auth_session.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'audit-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  test('fetchLogs sends owner auth, filters and parses snapshots', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode([
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'actor': 'owner@example.com',
          'action': 'inventory.adjustment',
          'entityType': 'ProductVariant',
          'entityId': 'PI-AKB-250',
          'beforeJson': '{"availablePackages": 4}',
          'afterJson': '{"availablePackages": 5}',
          'reason': 'اصلاح شمارش',
          'requestId': 'trace-1',
          'occurredAt': '2026-08-01T08:00:00Z',
        }
      ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    final logs = await AuditLogApiClient(client: client, baseUrl: 'https://api.test').fetchLogs(entityType: 'ProductVariant', entityId: 'PI-AKB-250', limit: 20);
    expect(captured.url.path, '/api/v1/admin/audit-log');
    expect(captured.url.queryParameters, {'entityType': 'ProductVariant', 'entityId': 'PI-AKB-250', 'limit': '20'});
    expect(captured.headers['authorization'], 'Bearer audit-test-token');
    expect(logs.single.actionLabel, 'اصلاح موجودی');
    expect(logs.single.beforeJson, contains('availablePackages'));
  });

  test('401 clears owner session', () async {
    final api = AuditLogApiClient(client: MockClient((_) async => http.Response('', 401)), baseUrl: 'https://api.test');
    await expectLater(api.fetchLogs(), throwsA(isA<AuditLogApiException>()));
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });
}
