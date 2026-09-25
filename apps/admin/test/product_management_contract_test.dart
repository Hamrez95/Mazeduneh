import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'catalog-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });

  tearDown(OwnerSession.instance.clear);

  test('creates an unpublished weighted product with three independent variants', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({
        'id': '11111111-1111-1111-1111-111111111111',
        'title': 'Pistachio',
        'slug': 'pistachio-test',
        'category': 'Nuts',
        'origin': 'Kerman',
        'currency': 'IRR',
        'unitType': 'Weight',
        'isPublished': false,
        'variants': [
          {'sku': 'TEST-250', 'quantity': 250, 'baseUnit': 'gram', 'displayLabel': '250 g', 'price': 1000000, 'availablePackages': 3},
          {'sku': 'TEST-500', 'quantity': 500, 'baseUnit': 'gram', 'displayLabel': '500 g', 'price': 1900000, 'availablePackages': 2},
          {'sku': 'TEST-1000', 'quantity': 1000, 'baseUnit': 'gram', 'displayLabel': '1000 g', 'price': 3600000, 'availablePackages': 1}
        ],
        'createdAt': '2026-07-31T08:00:00Z'
      }), 201, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    final command = CreateProductCommand(
      title: 'Pistachio',
      slug: 'pistachio-test',
      category: 'Nuts',
      origin: 'Kerman',
      unitType: 'Weight',
      isPublished: false,
      variants: const [
        CreateVariantCommand(sku: 'TEST-250', quantity: 250, displayLabel: '250 g', price: 1000000, availablePackages: 3),
        CreateVariantCommand(sku: 'TEST-500', quantity: 500, displayLabel: '500 g', price: 1900000, availablePackages: 2),
        CreateVariantCommand(sku: 'TEST-1000', quantity: 1000, displayLabel: '1000 g', price: 3600000, availablePackages: 1),
      ],
    );

    final product = await CatalogApiClient(client: client, baseUrl: 'https://api.test').createProduct(command);
    final body = jsonDecode(captured.body) as Map<String, dynamic>;

    expect(captured.headers['authorization'], 'Bearer catalog-test-token');
    expect(body['isPublished'], isFalse);
    expect((body['variants'] as List<dynamic>).length, 3);
    expect(product.variants.length, 3);
    expect(product.isPublished, isFalse);
  });
}
