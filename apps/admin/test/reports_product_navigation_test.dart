import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_navigation.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/order_api.dart';
import 'package:mazeduneh_admin/reports_page.dart';

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'report-navigation-test',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'analyst@example.test',
      role: 'ReadOnlyAnalyst',
      permissions: const ['reports.read', 'inventory.read'],
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('product profitability opens inventory for that SKU', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AdminNavigationIntent? destination;
    final requestPaths = <String>[];
    final api = OrderApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async {
        requestPaths.add(request.url.path);
        if (request.url.path.endsWith('/analytics/products')) {
          return _json([
            {
              'productTitle': 'پسته اکبری',
              'sku': 'PI-AKB-250',
              'variantLabel': '۲۵۰ گرم',
              'unitsSold': 2,
              'revenue': 500000,
              'cost': 300000,
              'grossProfit': 200000,
            },
          ]);
        }
        return _json({
          'days': 30,
          'orderCount': 1,
          'unitsSold': 2,
          'revenue': 500000,
          'cost': 300000,
          'grossProfit': 200000,
          'grossMarginPercent': 40,
          'tax': 0,
          'netProfit': 200000,
          'shippingExpense': 0,
        });
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: ReportsPage(api: api, onNavigate: (intent) => destination = intent),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(requestPaths, contains('/api/v1/admin/analytics/products'));
    expect(find.text('پسته اکبری'), findsOneWidget);
    final inventoryAction = find.text('مشاهده در انبار');
    await tester.ensureVisible(inventoryAction);
    await tester.pumpAndSettle();
    await tester.tap(inventoryAction);

    expect(destination?.module, AdminModule.inventory);
    expect(destination?.sku, 'PI-AKB-250');
  });
}
