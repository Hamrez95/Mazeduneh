import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/customer_api.dart';
import 'package:mazeduneh_admin/customer_management_page.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'customer-filter-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('consent chips filter the customer list through the admin API', (tester) async {
    final consentFilters = <String?>[];
    final searchQueries = <String?>[];
    final client = MockClient((request) async {
      consentFilters.add(request.url.queryParameters['marketingConsent']);
      searchQueries.add(request.url.queryParameters['q']);
      return http.Response(jsonEncode([]), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomerManagementPage(
        api: CustomerApiClient(client: client, baseUrl: 'https://api.test'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(consentFilters, [null]);
    await tester.tap(find.widgetWithText(ChoiceChip, 'رضایت ثبت‌شده'));
    await tester.pumpAndSettle();
    expect(consentFilters, [null, 'true']);

    await tester.tap(find.widgetWithText(ChoiceChip, 'بدون رضایت'));
    await tester.pumpAndSettle();
    expect(consentFilters, [null, 'true', 'false']);

    await tester.tap(find.widgetWithText(ChoiceChip, 'همه'));
    await tester.pumpAndSettle();
    expect(consentFilters, [null, 'true', 'false', null]);

    await tester.enterText(find.byType(TextField), 'مینا');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(searchQueries.last, 'مینا');
    expect(consentFilters.last, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('customer profile shows consent history from the API', (tester) async {
    final customer = {
      'id': 'consent-customer',
      'fullName': 'مینا نمونه',
      'mobile': '09120000123',
      'normalizedMobile': '09120000123',
      'marketingConsent': false,
      'createdAt': '2026-10-01T00:00:00Z',
      'updatedAt': '2026-10-02T00:00:00Z',
      'orderCount': 1,
      'totalSpend': 1000,
      'averageOrderValue': 1000,
      'lastPurchaseAt': '2026-10-02T00:00:00Z',
      'addresses': [],
      'consentHistory': [
        {
          'id': 'event-1',
          'channel': 'sms',
          'purpose': 'marketing',
          'granted': false,
          'source': 'receipt_self_service',
          'policyVersion': 'marketing-v1',
          'actor': 'customer',
          'recordedAt': '2026-10-02T00:00:00Z',
          'orderId': 'order-1',
        },
      ],
    };
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/customers/')) {
        return http.Response(jsonEncode([customer]), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (request.url.path.endsWith('/customers/consent-customer')) {
        return http.Response(jsonEncode(customer), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomerManagementPage(
          api: CustomerApiClient(client: client, baseUrl: 'https://api.test'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مینا نمونه'));
    await tester.pumpAndSettle();

    expect(find.text('سوابق رضایت تبلیغاتی'), findsOneWidget);
    expect(find.text('رضایت دریافت پیامک تبلیغاتی لغو شد'), findsOneWidget);
    expect(find.textContaining('لغو از رسید سفارش'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only role does not see customer CSV export', (tester) async {
    OwnerSession.instance.updateIdentity(role: 'ReadOnlyAnalyst', permissions: ['customers.read']);
    final client = MockClient((request) async => http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomerManagementPage(
          api: CustomerApiClient(client: client, baseUrl: 'https://api.test'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('خروجی CSV'), findsNothing);
    expect(tester.takeException(), isNull);
  });

}
