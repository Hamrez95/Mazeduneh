import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_shell.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/order_api.dart';

http.Response jsonResponse(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'deep-navigation-test',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'analyst@example.test',
      role: 'ReadOnlyAnalyst',
      permissions: const ['dashboard.read', 'inventory.read', 'orders.read'],
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets(
    'dashboard targets preserve batch and order filters through shell back navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final purchaseQueries = <Map<String, String>>[];
      final orderQueries = <Map<String, String>>[];
      final orderApi = OrderApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/dashboard/health')) {
            return jsonResponse({
              'api': 'healthy',
              'database': 'healthy',
              'migrations': 'tracked',
              'adminAuthentication': 'configured',
              'payment': 'sandbox-enabled',
              'mediaStorage': 'local',
              'ready': true,
            });
          }
          if (path.endsWith('/dashboard/preferences')) {
            return jsonResponse({
              'widgets': [
                for (final id in DashboardPreferences.ids)
                  {'id': id, 'visible': true},
              ],
            });
          }
          if (path.endsWith('/dashboard')) {
            return jsonResponse({
              'awaitingPayment': 1,
              'processing': 0,
              'shipped': 0,
              'delivered': 0,
              'paidRevenue': 0,
              'todayRevenue': 0,
              'periodDays': 1,
              'periodOrderCount': 1,
              'periodRevenue': 0,
              'averageOrderValue': 0,
              'newCustomers': 0,
              'corporateNewRequests': 0,
              'problemOrders': 0,
              'financialsVisible': false,
              'lowStock': [],
              'expiringSoon': [
                {
                  'productTitle': 'پسته اکبری',
                  'sku': 'PI-AKB-250',
                  'variantLabel': '۲۵۰ گرم',
                  'batchCode': 'BATCH-1405-07',
                  'expiresAt': DateTime.now()
                      .toUtc()
                      .add(const Duration(days: 5))
                      .toIso8601String(),
                  'remainingPackages': 3,
                },
              ],
            });
          }
          if (path.endsWith('/notifications')) {
            return jsonResponse({
              'awaitingPayment': 1,
              'lowStockItems': 0,
              'items': [],
            });
          }
          if (path.endsWith('/inventory/purchases')) {
            purchaseQueries.add(request.url.queryParameters);
            return jsonResponse({
              'items': [
                {
                  'id': 'batch-1',
                  'sku': 'PI-AKB-250',
                  'productTitle': 'پسته اکبری',
                  'variantLabel': '۲۵۰ گرم',
                  'batchCode': 'BATCH-1405-07',
                  'receivedPackages': 5,
                  'remainingPackages': 3,
                  'producedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
                  'expiresAt': DateTime.utc(2026, 10, 14).toIso8601String(),
                  'costPrice': 100,
                  'packagingCost': 0,
                  'additionalCost': 0,
                  'isExpired': false,
                  'isExpiringSoon': true,
                },
              ],
              'nextCursor': null,
            });
          }
          if (path.endsWith('/orders')) {
            orderQueries.add(request.url.queryParameters);
            return http.Response('[]', 200);
          }
          return http.Response('[]', 200);
        }),
      );
      final catalogApi = CatalogApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => jsonResponse([])),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AdminShell(
              dashboardApi: orderApi,
              ordersApi: orderApi,
              catalogApi: catalogApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('نزدیک به انقضا'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final batchTitle = find.text('پسته اکبری');
      final batchContext = tester.element(batchTitle);
      Scrollable.of(
        batchContext,
      ).position.jumpTo(Scrollable.of(batchContext).position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.text('پسته اکبری'));
      await tester.pumpAndSettle();
      expect(purchaseQueries, contains(containsPair('sku', 'PI-AKB-250')));
      expect(
        purchaseQueries,
        contains(containsPair('batchCode', 'BATCH-1405-07')),
      );

      await tester.tap(find.byTooltip('بازگشت به داشبورد'));
      await tester.pumpAndSettle();
      expect(find.text('امروز چه کاری انجام دهید؟'), findsOneWidget);

      final orderMetric = find.text('در انتظار پرداخت');
      final orderContext = tester.element(orderMetric);
      await Scrollable.ensureVisible(orderContext, alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('در انتظار پرداخت'));
      await tester.pumpAndSettle();
      expect(
        orderQueries.any((query) => query['state'] == 'AwaitingPayment'),
        isTrue,
      );
      expect(find.byTooltip('بازگشت به داشبورد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
