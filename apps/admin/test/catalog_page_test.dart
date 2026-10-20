import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/catalog_page.dart';
import 'package:mazeduneh_admin/admin_navigation.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('catalog page loads directly from its feature module', (tester) async {
    final paths = <String>[];
    final api = CatalogApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: CatalogPage(api: api)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(paths, containsAll([
      '/api/v1/products/admin',
      '/api/v1/categories/admin',
    ]));
    expect(find.text('محصولی پیدا نشد'), findsOneWidget);
  });

  testWidgets('product cost input is limited to pricing writers', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProductDialog(canWriteCosts: false)),
    ));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'قیمت تمام‌شده (تومان)',
      ),
      findsNothing,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProductDialog(canWriteCosts: true)),
    ));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'قیمت تمام‌شده (تومان)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('product gallery removes duplicates and supports primary selection', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProductDialog(canWriteCosts: true)),
    ));
    final primary = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'تصویر اصلی',
    );
    final gallery = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'پیوند تصاویر گالری (اختیاری)',
    );
    await tester.enterText(primary, 'https://images.example/main.webp');
    await tester.enterText(gallery, 'https://images.example/main.webp\nhttps://images.example/extra.webp\nhttps://images.example/extra.webp');
    await tester.pumpAndSettle();

    expect(find.byTooltip('تصویر اصلی'), findsOneWidget);
    expect(find.byTooltip('حذف تصویر'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('تصویر اصلی'));
    await tester.tap(find.byTooltip('تصویر اصلی'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(primary).controller!.text, 'https://images.example/extra.webp');
    expect(tester.widget<TextField>(gallery).controller!.text, 'https://images.example/main.webp');
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens related orders for the selected product variant', (tester) async {
    AdminNavigationIntent? destination;
    final api = CatalogApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async => http.Response(
        jsonEncode(request.url.path == '/api/v1/products/admin' ? [productJson()] : []),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )),
    );

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: CatalogPage(api: api, onNavigate: (intent) => destination = intent)),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('نمایش سفارش‌های ۲۵۰ گرم'));

    expect(destination, const AdminNavigationIntent(module: AdminModule.orders, query: 'AK-250'));
  });

  testWidgets('edits a published product and keeps its stock and publication state', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final api = CatalogApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT') {
          return http.Response(jsonEncode(productJson(title: 'پسته ویرایش‌شده')), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.url.path == '/api/v1/products/admin') {
          return http.Response(jsonEncode([productJson()]), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: CatalogPage(api: api)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('منتشرشده'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'ویرایش'));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش محصول'), findsOneWidget);
    expect(find.textContaining('ویرایش، وضعیت انتشار را تغییر نمی‌دهد.'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byKey(const ValueKey('edit-product-title'))).controller!.text,
      'پسته اکبری',
    );

    await tester.enterText(find.byKey(const ValueKey('edit-product-title')), 'پسته ویرایش‌شده');
    await tester.ensureVisible(find.text('ذخیره تغییرات'));
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();

    final update = requests.singleWhere((request) => request.method == 'PUT');
    final payload = jsonDecode(update.body) as Map<String, dynamic>;
    expect(update.url.path, '/api/v1/products/akbari');
    expect(payload['title'], 'پسته ویرایش‌شده');
    expect(payload['isPublished'], isNull);
    expect((payload['variants'] as List).single['price'], 100000);
    expect((payload['variants'] as List).single['availablePackages'], 4);
    expect((payload['variants'] as List).single['costPrice'], 60000);
    expect(find.text('تغییرات محصول ذخیره شد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides product editing from a read-only role', (tester) async {
    OwnerSession.instance.establish(
      accessToken: 'read-only-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'analyst@example.com',
      role: 'ReadOnlyAnalyst',
      permissions: const ['products.read'],
    );
    final api = CatalogApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async => http.Response(
            jsonEncode(request.url.path == '/api/v1/products/admin' ? [productJson()] : []),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );

    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: CatalogPage(api: api)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'ویرایش'), findsNothing);
  });
}

Map<String, dynamic> productJson({String title = 'پسته اکبری'}) => {
      'id': 'product-1',
      'title': title,
      'slug': 'akbari',
      'category': 'مغزیجات',
      'origin': 'رفسنجان',
      'unitType': 'Weight',
      'isPublished': true,
      'shortDescription': 'پسته تازه',
      'description': 'پسته اکبری رفسنجان',
      'seoTitle': 'پسته اکبری',
      'seoDescription': 'خرید پسته',
      'seoKeywords': 'پسته, اکبری',
      'primaryImage': 'https://images.example/akbari.webp',
      'galleryImages': ['https://images.example/akbari-2.webp'],
      'specifications': {'درجه': 'AA'},
      'variants': [
        {
          'sku': 'AK-250',
          'quantity': 250,
          'baseUnit': 'gram',
          'displayLabel': '۲۵۰ گرم',
          'price': 100000,
          'availablePackages': 4,
          'costPrice': 60000,
        },
      ],
    };
