import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  test('fetchProducts uses admin endpoint and parses publication state', () async {
    late Uri requestedUri;
    final client = MockClient((request) async {
      requestedUri = request.url;
      expect(request.headers['authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode([
          {
            'id': '1',
            'title': 'پسته اکبری',
            'slug': 'akbari',
            'category': 'مغزیجات',
            'origin': 'رفسنجان',
            'unitType': 'Weight',
            'isPublished': false,
            'variants': [
              {
                'sku': 'AK-250',
                'quantity': 250,
                'baseUnit': 'gram',
                'displayLabel': '۲۵۰ گرم',
                'price': 100000,
                'availablePackages': 4,
              }
            ],
          }
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final products = await CatalogApiClient(client: client, baseUrl: 'https://api.test').fetchProducts();

    expect(requestedUri.path, '/api/v1/products/admin');
    expect(products, hasLength(1));
    expect(products.single.isWeight, isTrue);
    expect(products.single.isPublished, isFalse);
    expect(products.single.totalStock, 4);
  });

  test('setPublication sends PATCH with requested state', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('', 204);
    });

    final api = CatalogApiClient(client: client, baseUrl: 'https://api.test');
    await api.setPublication('akbari', true);

    expect(captured.method, 'PATCH');
    expect(captured.headers['authorization'], 'Bearer test-token');
    expect(captured.url.path, '/api/v1/products/akbari/publication');
    expect(jsonDecode(captured.body), {'isPublished': true});
  });

  test('updateProduct sends a PUT without changing the publication state', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'id': '1',
          'title': 'پسته ویرایش‌شده',
          'slug': 'akbari',
          'category': 'مغزیجات',
          'origin': 'رفسنجان',
          'unitType': 'Weight',
          'isPublished': true,
          'variants': [],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    const command = UpdateProductCommand(
      title: 'پسته ویرایش‌شده',
      category: 'مغزیجات',
      origin: 'رفسنجان',
      unitType: 'Weight',
      variants: [
        CreateVariantCommand(
          sku: 'AK-250',
          quantity: 250,
          displayLabel: '۲۵۰ گرم',
          price: 125000,
          availablePackages: 4,
        ),
      ],
    );
    final api = CatalogApiClient(client: client, baseUrl: 'https://api.test');

    final updated = await api.updateProduct('akbari', command);

    expect(captured.method, 'PUT');
    expect(captured.url.path, '/api/v1/products/akbari');
    expect(captured.headers['authorization'], 'Bearer test-token');
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(payload['title'], 'پسته ویرایش‌شده');
    expect(payload['isPublished'], isNull);
    expect((payload['variants'] as List).single['availablePackages'], 4);
    expect(updated.isPublished, isTrue);
  });

  test('new products default to draft', () {
    const command = CreateProductCommand(
      title: 'کوکی', slug: 'cookie', category: 'سالم', origin: 'مزه‌دونه', unitType: 'Count',
      variants: [CreateVariantCommand(sku: 'CK-1', quantity: 1, displayLabel: '۱ عدد', price: 1000, availablePackages: 2)],
    );
    expect(command.toJson()['isPublished'], isFalse);
  });

  test('createProduct surfaces Persian conflict message', () async {
    final client = MockClient((request) async => http.Response(
          utf8.decode(utf8.encode(jsonEncode({'message': 'SKU تکراری است.'}))),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ));

    final api = CatalogApiClient(client: client, baseUrl: 'https://api.test');
    const command = CreateProductCommand(
      title: 'کوکی', slug: 'cookie', category: 'سالم', origin: 'مزه‌دونه', unitType: 'Count',
      variants: [CreateVariantCommand(sku: 'CK-1', quantity: 1, displayLabel: '۱ عدد', price: 1000, availablePackages: 2)],
    );

    expect(() => api.createProduct(command), throwsA(isA<CatalogApiException>().having((e) => e.message, 'message', 'SKU تکراری است.')));
  });
}
