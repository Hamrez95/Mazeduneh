import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_api.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';

void main() {
  tearDown(OwnerSession.instance.clear);

  test('login establishes an in-memory owner session', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/admin/auth/login');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['email'], 'owner@example.com');
      expect(body['password'], 'secret');
      return http.Response(
        jsonEncode({
          'accessToken': 'signed-token',
          'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 10)).toIso8601String(),
          'email': 'owner@example.com',
          'role': 'Owner',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await AuthApiClient(client: client, baseUrl: 'https://api.example.com').login(
      email: 'owner@example.com',
      password: 'secret',
    );

    expect(OwnerSession.instance.isAuthenticated, isTrue);
    expect(OwnerSession.instance.bearerToken, 'signed-token');
    expect(OwnerSession.instance.email, 'owner@example.com');
  });

  test('admin catalog request sends bearer token', () async {
    OwnerSession.instance.establish(
      accessToken: 'admin-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer admin-token');
      return http.Response('[]', 200, headers: {'content-type': 'application/json'});
    });

    final products = await CatalogApiClient(client: client, baseUrl: 'https://api.example.com').fetchProducts();
    expect(products, isEmpty);
  });

  test('401 clears the owner session', () async {
    OwnerSession.instance.establish(
      accessToken: 'expired-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
    final client = MockClient((request) async => http.Response('{}', 401));

    await expectLater(
      CatalogApiClient(client: client, baseUrl: 'https://api.example.com').fetchProducts(),
      throwsA(isA<CatalogApiException>().having((error) => error.statusCode, 'statusCode', 401)),
    );
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });

  test('rate limited login has a safe Persian message', () async {
    final client = MockClient((request) async => http.Response('{}', 429));
    await expectLater(
      AuthApiClient(client: client, baseUrl: 'https://api.example.com').login(email: 'owner@example.com', password: 'secret'),
      throwsA(isA<AuthApiException>().having((error) => error.message, 'message', contains('کمی بعد'))),
    );
  });
}
