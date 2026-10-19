import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/order_api.dart';
import 'package:mazeduneh_admin/orders_page.dart';
import 'package:mazeduneh_admin/product_management_page.dart';
import 'package:mazeduneh_admin/promotions_page.dart';

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
    await tester.enterText(find.byType(TextField).first, 'CODE-3');
    await tester.pumpAndSettle();
    expect(find.textContaining('کمپین 3 · CODE-3'), findsOneWidget);
    expect(find.textContaining('کمپین 11 · CODE-11'), findsNothing);
    expect(tester.takeException(), isNull);
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
