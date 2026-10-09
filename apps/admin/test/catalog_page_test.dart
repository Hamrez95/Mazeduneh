import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/catalog_page.dart';

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
    expect(find.text('قیمت تمام‌شده ریال'), findsNothing);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProductDialog(canWriteCosts: true)),
    ));
    expect(find.text('قیمت تمام‌شده ریال'), findsOneWidget);
  });
}
