import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_navigation.dart';
import 'package:mazeduneh_admin/admin_shell.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/inventory_page.dart';
import 'package:mazeduneh_admin/order_api.dart';

void main() {
  setUp(
    () => OwnerSession.instance.establish(
      accessToken: 'navigation-flow-test',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.test',
    ),
  );
  tearDown(OwnerSession.instance.clear);

  testWidgets(
    'inventory navigation intent filters purchase history by exact SKU and batch',
    (tester) async {
      Uri? purchaseRequest;
      final orders = OrderApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/inventory/movements'))
            return _json([]);
          if (request.url.path.endsWith('/inventory/purchases')) {
            purchaseRequest = request.url;
            return _json({'items': [], 'nextCursor': null});
          }
          return _json([]);
        }),
      );
      final catalog = CatalogApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((_) async => _json([])),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InventoryPage(
                catalog: catalog,
                orders: orders,
                initialSku: 'PI-AKB-250',
                initialBatchCode: 'BATCH-042',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(purchaseRequest?.queryParameters['sku'], 'PI-AKB-250');
      expect(purchaseRequest?.queryParameters['batchCode'], 'BATCH-042');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dashboard KPI opens the exact order state and the shell returns to dashboard',
    (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uri? orderRequest;
      final orders = OrderApiClient(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/dashboard')) {
            return _json({
              'awaitingPayment': 1,
              'processing': 0,
              'shipped': 0,
              'delivered': 0,
              'paidRevenue': 0,
              'todayRevenue': 0,
              'lowStock': [],
              'expiringSoon': [],
            });
          }
          if (request.url.path.endsWith('/dashboard/preferences')) {
            return _json(DashboardPreferences.defaults.toJson());
          }
          if (request.url.path.endsWith('/notifications')) {
            return _json({
              'awaitingPayment': 1,
              'lowStockItems': 0,
              'items': [],
            });
          }
          if (request.url.path.endsWith('/admin/orders'))
            orderRequest = request.url;
          return _json([]);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AdminShell(dashboardApi: orders, ordersApi: orders),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('در انتظار پرداخت'));
      await tester.pumpAndSettle();

      expect(orderRequest?.queryParameters['state'], 'AwaitingPayment');
      expect(find.byTooltip('بازگشت به داشبورد'), findsOneWidget);
      await tester.tap(find.byTooltip('بازگشت به داشبورد'));
      await tester.pumpAndSettle();
      expect(find.text('وضعیت فروشگاه'), findsOneWidget);

      await tester.tap(find.text('در انتظار پرداخت'));
      await tester.pumpAndSettle();
      expect(orderRequest?.queryParameters['state'], 'AwaitingPayment');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('وضعیت فروشگاه'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'notification targets preserve validated order and inventory filters',
    () {
      expect(
        const AdminNavigationTarget(
          module: 'orders',
          filter: 'AwaitingPayment',
        ).toIntent(),
        const AdminNavigationIntent(
          module: AdminModule.orders,
          orderFilter: AdminOrderFilter.awaitingPayment,
        ),
      );
      expect(
        const AdminNavigationTarget(
          module: 'inventory',
          sku: 'PI-AKB-250',
          batchCode: 'BATCH-042',
        ).toIntent(),
        const AdminNavigationIntent(
          module: AdminModule.inventory,
          sku: 'PI-AKB-250',
          batchCode: 'BATCH-042',
        ),
      );
      expect(
        const AdminNavigationTarget(
          module: 'inventory',
          filter: 'AwaitingPayment',
        ).toIntent(),
        isNull,
      );
    },
  );
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

