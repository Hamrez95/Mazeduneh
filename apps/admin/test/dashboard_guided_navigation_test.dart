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
      accessToken: 'dashboard-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });

  tearDown(OwnerSession.instance.clear);

  testWidgets('dashboard quick actions expose a guided route on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/dashboard')) {
        return http.Response(
          jsonEncode({
            'awaitingPayment': 2,
            'processing': 3,
            'shipped': 4,
            'delivered': 8,
            'paidRevenue': 1200000,
            'todayRevenue': 850000,
            'lowStock': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'awaitingPayment': 2, 'lowStockItems': 0, 'items': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    int? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: DashboardPage(
            api: OrderApiClient(client: client, baseUrl: 'https://api.test'),
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('امروز چه کاری انجام دهید؟'), findsOneWidget);
    expect(find.text('ثبت محصول'), findsOneWidget);
    expect(find.text('پیگیری سفارش‌ها'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('پیگیری سفارش‌ها'));
    expect(destination, 1);
  });
}
