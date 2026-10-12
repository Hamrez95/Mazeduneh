import 'dart:convert';
import 'dart:async';

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
      if (request.url.path.endsWith('/session')) {
        expect(OwnerSession.instance.isAuthenticated, isFalse);
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'role': 'Owner',
            'permissions': ['orders.read', 'products.write'],
            'storeId': 'tenant-north',
          }),
          200,
        );
      }
      expect(request.url.path, '/api/v1/admin/auth/login');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['email'], 'owner@example.com');
      expect(body['password'], 'secret');
      expect(body['storeId'], 'tenant-north');
      return http.Response(
        jsonEncode({
          'accessToken': 'signed-token',
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
          'email': 'owner@example.com',
          'role': 'Owner',
          'permissions': ['orders.read', 'products.write'],
          'storeId': 'tenant-north',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    await AuthApiClient(
      client: client,
      baseUrl: 'https://api.example.com',
      storeId: 'tenant-north',
    ).login(email: 'owner@example.com', password: 'secret');

    expect(OwnerSession.instance.isAuthenticated, isTrue);
    expect(OwnerSession.instance.bearerToken, 'signed-token');
    expect(OwnerSession.instance.email, 'owner@example.com');
    expect(OwnerSession.instance.role, 'Owner');
    expect(OwnerSession.instance.can('orders.read'), isTrue);
    expect(OwnerSession.instance.permissions, contains('products.write'));
    expect(OwnerSession.instance.storeId, 'tenant-north');
  });

  test('login rejects a server session bound to another store', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'role': 'WarehouseOperator',
            'permissions': ['inventory.read'],
            'storeId': 'tenant-south',
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'accessToken': 'signed-token',
          'expiresAt': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 10))
              .toIso8601String(),
          'storeId': 'tenant-north',
        }),
        200,
      );
    });

    await expectLater(
      AuthApiClient(
        client: client,
        baseUrl: 'https://api.example.com',
        storeId: 'tenant-north',
      ).login(email: 'member@example.com', password: 'secret'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });

  test(
    'session validation refreshes role and permissions from the server',
    () async {
      OwnerSession.instance.establish(
        accessToken: 'signed-token',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        email: 'owner@example.com',
        role: 'StoreManager',
      );
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/auth/session');
        return http.Response(
          jsonEncode({
            'authenticated': true,
            'email': 'owner@example.com',
            'role': 'StoreManager',
            'permissions': ['orders.read'],
            'storeId': 'default',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await AuthApiClient(
        client: client,
        baseUrl: 'https://api.example.com',
      ).validateSession();

      expect(OwnerSession.instance.role, 'StoreManager');
      expect(OwnerSession.instance.can('orders.read'), isTrue);
      expect(OwnerSession.instance.can('products.write'), isFalse);
    },
  );

  test('admin catalog request sends bearer token', () async {
    OwnerSession.instance.establish(
      accessToken: 'admin-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer admin-token');
      return http.Response(
        '[]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final products = await CatalogApiClient(
      client: client,
      baseUrl: 'https://api.example.com',
    ).fetchProducts();
    expect(products, isEmpty);
  });

  test('step-up sends owner TOTP and caches the short-lived token in memory', () async {
    OwnerSession.instance.establish(
      accessToken: 'admin-session',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
    late http.Request captured;
    final token = await AuthApiClient(
      client: MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'stepUpToken': 'short-lived-window',
          'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String()}), 200);
      }),
      baseUrl: 'https://api.example.com',
    ).stepUp(password: 'fresh-password', totpCode: '123456');

    expect(captured.url.path, '/api/v1/admin/auth/step-up');
    expect(captured.headers['authorization'], 'Bearer admin-session');
    expect(jsonDecode(captured.body), {'password': 'fresh-password', 'totpCode': '123456'});
    expect(token, 'short-lived-window');
    expect(OwnerSession.instance.validStepUpToken, token);
    expect(OwnerSession.instance.bearerToken, 'admin-session');
  });

  test('non-owner step-up can remain password-only', () async {
    OwnerSession.instance.establish(accessToken: 'staff-session',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'staff@example.com', role: 'StoreManager');
    late http.Request captured;
    await AuthApiClient(client: MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'stepUpToken': 'staff-window',
        'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String()}), 200);
    }), baseUrl: 'https://api.example.com').stepUp(password: 'fresh-password');
    expect(jsonDecode(captured.body), {'password': 'fresh-password'});
  });

  test('incorrect step-up password does not clear the authenticated session', () async {
    OwnerSession.instance.establish(
      accessToken: 'admin-session',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
    await expectLater(
      AuthApiClient(client: MockClient((request) async => http.Response.bytes(
        utf8.encode(jsonEncode({'message': 'رمز عبور تأیید نشد.'})), 403,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ))).stepUp(password: 'wrong-password'),
      throwsA(isA<AuthApiException>().having((error) => error.statusCode, 'statusCode', 403)),
    );
    expect(OwnerSession.instance.bearerToken, 'admin-session');
  });

  test('401 clears the owner session', () async {
    OwnerSession.instance.establish(
      accessToken: 'expired-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
    final client = MockClient((request) async => http.Response('{}', 401));

    await expectLater(
      CatalogApiClient(
        client: client,
        baseUrl: 'https://api.example.com',
      ).fetchProducts(),
      throwsA(
        isA<CatalogApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });

  test('rate limited login has a safe Persian message', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['storeId'], 'default');
      return http.Response('{}', 429);
    });
    await expectLater(
      AuthApiClient(
        client: client,
        baseUrl: 'https://api.example.com',
      ).login(email: 'owner@example.com', password: 'secret'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          contains('کمی بعد'),
        ),
      ),
    );
  });
  test('logout clears immediately and a delayed response cannot erase a new session', () async {
    OwnerSession.instance.establish(accessToken: 'old-token', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)), email: 'old@example.test');
    final response = Completer<http.Response>();
    final future = AuthApiClient(client: MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer old-token');
      return response.future;
    })).logout();
    expect(OwnerSession.instance.isAuthenticated, isFalse);
    OwnerSession.instance.establish(accessToken: 'new-token', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)), email: 'new@example.test');
    response.complete(http.Response('', 204));
    await future;
    expect(OwnerSession.instance.bearerToken, 'new-token');
  });

  test('an authenticated false session response cannot establish credentials', () async {
    final api = AuthApiClient(client: MockClient((request) async => request.url.path.endsWith('/login')
      ? http.Response(jsonEncode({'accessToken': 'provisional', 'expiresAt': DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String()}), 200)
      : http.Response('{"authenticated":false}', 200)));
    await expectLater(api.login(email: 'owner@example.test', password: 'test-password'), throwsA(isA<AuthApiException>()));
    expect(OwnerSession.instance.bearerToken, isNull);
  });

}
