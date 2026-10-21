import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_navigation.dart';
import 'package:mazeduneh_admin/admin_permissions.dart';
import 'package:mazeduneh_admin/admin_shell.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/inventory_page.dart';
import 'package:mazeduneh_admin/order_api.dart';
import 'package:mazeduneh_admin/orders_page.dart';

void main() {
  setUp(
    () => OwnerSession.instance.establish(
      accessToken: 'navigation-flow-test',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.test',
    ),
  );
  tearDown(OwnerSession.instance.clear);

  test('commerce settings navigation uses its separate read permission', () {
    expect(AdminModule.pricing.permission, AdminPermissions.settingsRead);
    expect(AdminPermissions.settingsRead, isNot(AdminPermissions.pricingRead));
  });

  test('module navigation metadata is unique and round-trips from API targets', () {
    final modules = AdminModule.values;
    expect(modules.map((module) => module.apiValue).toSet(), hasLength(modules.length));
    expect(modules.map((module) => module.label).toSet(), hasLength(modules.length));
    for (final module in modules) {
      expect(AdminModule.fromApiValue(module.apiValue), module);
      expect(module.permission, isNotEmpty);
    }
  });

  test('direct order links restore safe record, filter, query and date range', () {
    final intent = AdminNavigationIntent.fromUri(Uri.parse(
      'https://admin.example.test/?module=orders&status=Processing&order=ord-42&'
      'q=KOO-250&from=2026-10-01T00%3A00%3A00.000Z&to=2026-10-08T00%3A00%3A00.000Z',
    ));

    expect(intent.module, AdminModule.orders);
    expect(intent.orderFilter, AdminOrderFilter.processing);
    expect(intent.orderId, 'ord-42');
    expect(intent.query, 'KOO-250');
    expect(intent.createdFromUtc, DateTime.utc(2026, 10, 1));
    expect(intent.createdToUtcExclusive, DateTime.utc(2026, 10, 8));
    expect(
      AdminNavigationIntent.fromUri(intent.toUri(Uri.parse('https://admin.example.test/'))),
      intent,
    );
  });

  test('direct product links restore the product and omit private searches', () {
    final product = AdminNavigationIntent.fromUri(Uri.parse(
      'https://admin.example.test/?module=products&product=akbari-pistachio',
    ));
    expect(product.module, AdminModule.products);
    expect(product.productSlug, 'akbari-pistachio');

    final unsafeSearch = AdminNavigationIntent.fromUri(Uri.parse(
      'https://admin.example.test/?module=orders&status=Paid&q=09123456789',
    ));
    expect(unsafeSearch.orderFilter, AdminOrderFilter.paid);
    expect(unsafeSearch.query, isNull);
  });

  testWidgets('orders page applies the SKU sent by a product navigation intent', (tester) async {
    Uri? orderRequest;
    final api = OrderApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async {
        orderRequest = request.url;
        return _json([]);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: OrdersPage(api: api, initialQuery: 'PI-AKB-250')),
      ),
    ));
    await tester.pumpAndSettle();

    expect(orderRequest?.queryParameters['q'], 'PI-AKB-250');
    expect(tester.takeException(), isNull);
  });

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
              'processing': 2,
              'shipped': 0,
              'delivered': 0,
              'paidRevenue': 0,
              'todayRevenue': 0,
              'lowStock': [],
              'expiringSoon': [],
              'problemOrders': 1,
            });
          }
          if (request.url.path.endsWith('/notifications')) {
            return _json({
              'awaitingPayment': 1,
              'lowStockItems': 0,
              'items': [],
            });
          }
          if (request.url.path.endsWith('/dashboard/preferences')) {
            return _json({
              'widgets': [
                {'id': 'metrics', 'visible': true},
                {'id': 'quickActions', 'visible': true},
                {'id': 'alerts', 'visible': true},
                {'id': 'lowStock', 'visible': true},
                {'id': 'expiring', 'visible': true},
              ],
            });
          }
          if (request.url.path.endsWith('/dashboard/health')) {
            return _json({
              'api': 'healthy',
              'database': 'healthy',
              'migrations': 'tracked',
              'adminAuthentication': 'configured',
              'ready': true,
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

      await tester.scrollUntilVisible(find.text('در حال پردازش'), 350, maxScrolls: 15);
      await tester.tap(find.text('در حال پردازش'));
      await tester.pumpAndSettle();
      expect(orderRequest?.queryParameters['state'], 'Processing');
      await tester.tap(find.byTooltip('بازگشت به داشبورد'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('سفارش مشکل‌دار'), 350, maxScrolls: 15);
      await tester.tap(find.text('سفارش مشکل‌دار'));
      await tester.pumpAndSettle();
      expect(orderRequest?.queryParameters['state'], 'Problem');
      await tester.tap(find.byTooltip('بازگشت به داشبورد'));
      await tester.pumpAndSettle();
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

