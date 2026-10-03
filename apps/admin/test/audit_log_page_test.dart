import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/audit_log_api.dart';
import 'package:mazeduneh_admin/audit_log_page.dart';
import 'package:mazeduneh_admin/auth_session.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'audit-page-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('shows an expandable audit event with before and after snapshots', (tester) async {
    final api = AuditLogApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((_) async => http.Response(jsonEncode([
        {
          'id': 'event-1', 'actor': 'owner@example.com', 'action': 'product.publication',
          'entityType': 'Product', 'entityId': 'pistachio-akbari-premium',
          'beforeJson': '{"isPublished":false}', 'afterJson': '{"isPublished":true}',
          'reason': 'انتشار محصول', 'requestId': 'trace-1', 'occurredAt': '2026-08-01T08:00:00Z',
        }
      ]), 200, headers: {'content-type': 'application/json; charset=utf-8'})),
    );
    await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: AuditLogPage(api: api))));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('گزارش فعالیت‌های حساس'), findsOneWidget);
    expect(find.text('تغییر انتشار محصول'), findsOneWidget);
    await tester.tap(find.text('تغییر انتشار محصول'));
    await tester.pumpAndSettle();
    expect(find.text('قبل از تغییر'), findsOneWidget);
    expect(find.text('بعد از تغییر'), findsOneWidget);
  });

  testWidgets('renders the educational empty state', (tester) async {
    final api = AuditLogApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((_) async => http.Response('[]', 200, headers: {'content-type': 'application/json; charset=utf-8'})),
    );
    await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: AuditLogPage(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('هنوز فعالیت حساسی ثبت نشده است'), findsOneWidget);
  });
}
