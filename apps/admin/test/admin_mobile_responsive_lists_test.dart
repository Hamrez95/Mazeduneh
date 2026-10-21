import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/inventory_page.dart';
import 'package:mazeduneh_admin/order_api.dart';
import 'package:mazeduneh_admin/orders_page.dart';
import 'package:mazeduneh_admin/product_management_page.dart';
import 'package:mazeduneh_admin/promotions_page.dart';
import 'package:mazeduneh_admin/reports_page.dart';

void setMobileViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'responsive-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      email: 'owner@example.test',
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('mobile product cards retain search and pagination', (
    tester,
  ) async {
    setMobileViewport(tester, const Size(320, 900));
    final products = List.generate(
      12,
      (index) => Product(
        id: 'product-$index',
        title: 'محصول ${index + 1}',
        slug: 'product-${index + 1}',
        category: 'خشکبار',
        origin: 'کرمان',
        unitType: 'Weight',
        isPublished: true,
        variants: [
          ProductVariant(
            sku: 'SKU-${index + 1}',
            quantity: 250,
            displayLabel: '۲۵۰ گرم',
            price: 100000,
            availablePackages: 10,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductManagementPage(
            products: products,
            api: CatalogApiClient(
              client: MockClient((_) async => http.Response('{}', 200)),
            ),
            onReload: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('صفحهٔ بعد'), findsOneWidget);
    expect(find.text('محصول 1'), findsOneWidget);
    expect(find.text('محصول 11'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('صفحهٔ بعد'));
    await tester.pumpAndSettle();
    expect(find.text('محصول 11'), findsOneWidget);
    expect(find.text('محصول 1'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'SKU-3');
    await tester.pumpAndSettle();
    expect(find.text('محصول 3'), findsOneWidget);
    expect(find.text('محصول 11'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelled and expired orders do not look successfully completed on mobile',
    (tester) async {
      setMobileViewport(tester, const Size(390, 844));
      final orders = [
        _order('11111111-1111-1111-1111-111111111111', 'Cancelled'),
        _order('22222222-2222-2222-2222-222222222222', 'Expired'),
      ];
      final api = OrderApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/admin/orders');
          return http.Response(
            jsonEncode(orders),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
        baseUrl: 'https://api.test',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OrdersPage(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('سفارش لغو شده است'), findsOneWidget);
      expect(find.text('مهلت پرداخت سفارش پایان یافته است'), findsOneWidget);
      expect(find.text('فرآیند تکمیل شده'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('order list keeps its page between cards and the table', (
    tester,
  ) async {
    setMobileViewport(tester, const Size(390, 900));
    final orders = List.generate(12, (index) {
      final row = _order(
        '${(index + 1).toString().padLeft(8, '0')}-1111-1111-1111-111111111111',
        'Preparing',
      );
      row['customerName'] = 'مشتری ${index + 1}';
      return row;
    });
    final api = OrderApiClient(
      client: MockClient((_) async => http.Response(
        jsonEncode(orders),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )),
      baseUrl: 'https://api.test',
    );
    var textScale = 1.0;
    Widget app() => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(body: OrdersPage(api: api)),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('مشتری 1'), findsOneWidget);
    expect(find.text('مشتری 11'), findsNothing);
    await tester.tap(find.byTooltip('صفحهٔ بعد'));
    await tester.pumpAndSettle();
    expect(find.text('مشتری 11'), findsOneWidget);

    for (final width in [320.0, 360.0, 390.0, 768.0, 900.0, 1024.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 1000);
      textScale = width == 360 ? 2 : 1;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('مشتری 11'), findsOneWidget);
      expect(find.text('مشتری 1'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'orders at $width px');
    }
  });

  testWidgets('inventory cards keep search and paging on narrow layouts', (
    tester,
  ) async {
    setMobileViewport(tester, const Size(320, 900));
    final variants = List.generate(
      12,
      (index) => {
        'sku': 'SKU-${index + 1}',
        'quantity': 250,
        'displayLabel': '۲۵۰ گرم',
        'price': 100000,
        'availablePackages': 10,
      },
    );
    final catalog = CatalogApiClient(
      client: MockClient((_) async => http.Response(
        jsonEncode([
          {
            'id': 'product-1',
            'title': 'پسته',
            'slug': 'pistachio',
            'category': 'خشکبار',
            'origin': 'کرمان',
            'unitType': 'Weight',
            'isPublished': true,
            'variants': variants,
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )),
      baseUrl: 'https://api.test',
    );
    final orders = OrderApiClient(
      client: MockClient((request) async => http.Response(
        jsonEncode(request.url.path.endsWith('/inventory/purchases')
            ? {'items': [], 'nextCursor': null}
            : []),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )),
      baseUrl: 'https://api.test',
    );

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: InventoryPage(catalog: catalog, orders: orders)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('SKU-1'), findsOneWidget);
    expect(find.textContaining('SKU-11'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('صفحهٔ بعد').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('صفحهٔ بعد').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('SKU-11'), findsOneWidget);

    for (final width in [360.0, 390.0, 768.0, 900.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpAndSettle();
      expect(find.textContaining('SKU-11'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'inventory at $width px');
    }
    await tester.enterText(find.byType(TextField).first, 'SKU-12');
    await tester.pumpAndSettle();
    expect(find.text('۲۵۰ گرم · SKU-12'), findsOneWidget);
    expect(find.text('۲۵۰ گرم · SKU-11'), findsNothing);
  });

  testWidgets('reports remain usable across phone, tablet, and zoom widths', (
    tester,
  ) async {
    setMobileViewport(tester, const Size(390, 900));
    final api = OrderApiClient(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/analytics/products') ||
            request.url.path.endsWith('/analytics/price-history/skus')) {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'days': 30,
            'orderCount': 12,
            'unitsSold': 24,
            'revenue': 2400000,
            'cost': 1600000,
            'grossProfit': 800000,
            'grossMarginPercent': 33.3,
            'tax': 0,
            'netProfit': 800000,
            'shippingExpense': 0,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
      baseUrl: 'https://api.test',
    );
    var textScale = 1.0;

    Widget app() => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(body: Directionality(
        textDirection: TextDirection.rtl,
        child: ReportsPage(api: api),
      )),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final width in [320.0, 360.0, 390.0, 768.0, 900.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 1000);
      textScale = width == 360 ? 1.6 : 1;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('گزارش‌ها'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'reports at $width px');
    }
  });

  testWidgets('mobile promotion cards keep search and pagination', (
    tester,
  ) async {
    setMobileViewport(tester, const Size(360, 900));
    final rows = List.generate(
      12,
      (index) => {
        'code': 'CODE-${index + 1}',
        'uses': index,
        'discountTotal': index * 1000,
        'paidOrders': index,
        'revenue': index * 10000,
        'rule': {
          'name': 'کمپین ${index + 1}',
          'kind': 'Percent',
          'automatic': false,
          'active': true,
          'startsAt': '2026-01-01T00:00:00Z',
          'endsAt': '2027-01-01T00:00:00Z',
          'maxUses': null,
        },
      },
    );
    final api = PromotionsApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(rows),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      baseUrl: 'https://api.test',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PromotionsPage(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('صفحهٔ بعد'), findsOneWidget);
    expect(find.textContaining('کمپین 1 · CODE-1'), findsOneWidget);
    expect(find.textContaining('کمپین 11 · CODE-11'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('صفحهٔ بعد'));
    await tester.pumpAndSettle();
    expect(find.textContaining('کمپین 11 · CODE-11'), findsOneWidget);
    tester.view.physicalSize = const Size(1280, 1000);
    await tester.pumpAndSettle();
    expect(find.textContaining('کمپین 11'), findsOneWidget);
    expect(find.textContaining('کمپین 1 · CODE-1'), findsNothing);
    tester.view.physicalSize = const Size(360, 900);
    await tester.pumpAndSettle();
    expect(find.textContaining('کمپین 11 · CODE-11'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'CODE-3');
    await tester.pumpAndSettle();
    expect(find.textContaining('کمپین 3 · CODE-3'), findsOneWidget);
    expect(find.textContaining('کمپین 11 · CODE-11'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('promotion editor fits a narrow phone viewport', (tester) async {
    setMobileViewport(tester, const Size(320, 900));
    final api = PromotionsApiClient(
      client: MockClient((_) async => http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )),
      baseUrl: 'https://api.test',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PromotionsPage(api: api)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('کوپن جدید'));
    await tester.pumpAndSettle();

    expect(find.text('کد انگلیسی؛ مثل WELCOME10'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final width in [360.0, 390.0, 768.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'promotion form at $width px');
    }
  });
}

Map<String, dynamic> _order(String id, String state) => {
  'id': id,
  'customerName': 'مشتری آزمایشی',
  'mobile': '09120000000',
  'province': 'تهران',
  'city': 'تهران',
  'payable': 100000,
  'currency': 'IRR',
  'state': state,
  'createdAt': '2026-10-19T08:00:00Z',
  'reservationExpiresAt': '2026-10-20T08:00:00Z',
  'lineCount': 1,
  'paymentReference': null,
  'paymentState': 'Failed',
  'isPrivate': false,
};
