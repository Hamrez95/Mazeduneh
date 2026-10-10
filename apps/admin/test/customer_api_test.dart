import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/customer_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'customer-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  test('fetchCustomers keeps filters and parses the privacy consent contract', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode([
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'fullName': 'مینا احمدی',
          'mobile': '۰۹۱۲۰۰۰۰۰۰۰',
          'normalizedMobile': '09120000000',
          'marketingConsent': true,
          'createdAt': '2026-07-31T08:00:00Z',
          'updatedAt': '2026-07-31T08:10:00Z',
          'orderCount': 3,
          'totalSpend': 7200000,
          'averageOrderValue': 2400000,
          'lastPurchaseAt': '2026-07-30T12:00:00Z',
          'addresses': [],
        }
      ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    final customers = await CustomerApiClient(client: client, baseUrl: 'https://api.test')
        .fetchCustomers(query: 'مینا', marketingConsent: true, limit: 50);
    expect(captured.url.path, '/api/v1/admin/customers/');
    expect(captured.url.queryParameters['q'], 'مینا');
    expect(captured.url.queryParameters['marketingConsent'], 'true');
    expect(captured.url.queryParameters['limit'], '50');
    expect(captured.headers['authorization'], 'Bearer customer-test-token');
    expect(customers.single.marketingConsent, isTrue);
    expect(customers.single.orderCount, 3);
    expect(customers.single.totalSpend, 7200000);
    expect(customers.single.averageOrderValue, 2400000);
    expect(customers.single.lastPurchaseAt, isNotNull);
  });

  test('exportCustomersCsv sends the authenticated filtered export contract', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes([0xEF, 0xBB, 0xBF, 0xD8, 0xB4], 200, headers: {'content-type': 'text/csv; charset=utf-8'});
    });

    final bytes = await CustomerApiClient(client: client, baseUrl: 'https://api.test')
        .exportCustomersCsv(query: '0912', marketingConsent: false, limit: 500);
    expect(captured.url.path, '/api/v1/admin/customers/export.csv');
    expect(captured.url.queryParameters['q'], '0912');
    expect(captured.url.queryParameters['marketingConsent'], 'false');
    expect(captured.url.queryParameters['limit'], '500');
    expect(captured.headers['authorization'], 'Bearer customer-test-token');
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
  });
}
