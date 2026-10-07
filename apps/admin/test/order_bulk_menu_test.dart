import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/main.dart';
import 'package:mazeduneh_admin/order_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'bulk-order-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('bulk order menu opens and submits the selected transition', (tester) async {
    var bulkBody = <String, dynamic>{};
    var listRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/orders/bulk-state')) {
        bulkBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'updated': ['order-0001'], 'failed': []}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (request.url.path.endsWith('/orders')) {
        listRequests++;
        return http.Response(
          jsonEncode(listRequests == 1
              ? [{
                  'id': 'order-0001',
                  'customerName': 'مینا احمدی',
                  'mobile': 'مخفی',
                  'province': 'تهران',
                  'city': 'تهران',
                  'payable': 100000,
                  'currency': 'IRR',
                  'state': 'Paid',
                  'createdAt': '2026-10-01T10:00:00Z',
                  'reservationExpiresAt': '2026-10-01T11:00:00Z',
                  'lineCount': 1,
                }]
              : []),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('[]', 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OrdersPage(api: OrderApiClient(client: client, baseUrl: 'https://api.test')),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('عملیات گروهی'));
    await tester.pumpAndSettle();
    expect(find.text('انتقال به در حال آماده‌سازی'), findsOneWidget);

    await tester.tap(find.text('انتقال به در حال آماده‌سازی'));
    await tester.pumpAndSettle();
    expect(find.text('تغییر وضعیت گروهی'), findsOneWidget);
    await tester.tap(find.text('تأیید عملیات'));
    await tester.pumpAndSettle();

    expect(bulkBody['orderIds'], ['order-0001']);
    expect(bulkBody['state'], 'Preparing');
    expect(bulkBody['reason'], isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}
