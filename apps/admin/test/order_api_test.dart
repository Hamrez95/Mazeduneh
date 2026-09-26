import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/order_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'order-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  test('fetchOrders sends Bearer token and parses payment data', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode([
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'customerName': 'Mina',
          'mobile': '09120000000',
          'province': 'Tehran',
          'city': 'Tehran',
          'payable': 2450000,
          'currency': 'IRR',
          'state': 'Paid',
          'createdAt': '2026-07-31T08:00:00Z',
          'reservationExpiresAt': '2026-07-31T08:20:00Z',
          'lineCount': 1,
          'paymentReference': 'SANDBOX-1',
          'paymentState': 'Succeeded'
        }
      ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    final orders = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchOrders(state: 'Paid');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(captured.url.path, '/api/v1/admin/orders');
    expect(captured.url.queryParameters['state'], 'Paid');
    expect(orders.single.nextState, 'Preparing');
    expect(orders.single.paymentReference, 'SANDBOX-1');
  });

  test('transition sends PATCH state and reason', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({
        'id': '11111111-1111-1111-1111-111111111111',
        'customerName': 'Mina',
        'mobile': '09120000000',
        'province': 'Tehran',
        'city': 'Tehran',
        'payable': 2450000,
        'currency': 'IRR',
        'state': 'Preparing',
        'createdAt': '2026-07-31T08:00:00Z',
        'reservationExpiresAt': '2026-07-31T08:20:00Z',
        'lineCount': 1,
        'paymentReference': 'SANDBOX-1',
        'paymentState': 'Succeeded'
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await OrderApiClient(client: client, baseUrl: 'https://api.test')
        .transition('11111111-1111-1111-1111-111111111111', 'Preparing', reason: 'ready');
    expect(captured.method, 'PATCH');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(jsonDecode(captured.body), {'state': 'Preparing', 'reason': 'ready'});
  });

  test('401 clears owner session', () async {
    final client = MockClient((request) async => http.Response('', 401));
    final api = OrderApiClient(client: client, baseUrl: 'https://api.test');
    await expectLater(api.fetchDashboard(), throwsA(isA<OrderApiException>()));
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });
}
