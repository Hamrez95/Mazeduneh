import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/corporate_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'corporate-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });

  tearDown(OwnerSession.instance.clear);

  test('fetchRequests sends the overdue follow-up filter', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode([
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'customerName': 'مشتری سازمانی',
            'companyName': 'شرکت تست',
            'mobile': '09120000000',
            'city': 'تهران',
            'occasion': 'نوروز',
            'orderQuantity': 100,
            'packageType': 'premium',
            'status': 'Contacted',
            'assignedTo': 'sales@example.com',
            'nextFollowUpAt': '2026-09-30T10:00:00Z',
            'createdAt': '2026-09-20T10:00:00Z',
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final items = await CorporateApiClient(client: client, baseUrl: 'https://api.test')
        .fetchRequests(overdueOnly: true);

    expect(captured.url.path, '/api/v1/admin/corporate-requests');
    expect(captured.url.queryParameters['overdue'], 'true');
    expect(items.single.companyName, 'شرکت تست');
  });

  test('fetchRequests sends planning with existing search and status filters', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('[]', 200);
    });
    await CorporateApiClient(client: client, baseUrl: 'https://api.test').fetchRequests(
      needsPlanningOnly: true, status: 'New', query: 'شرکت', city: 'تهران',
    );
    expect(captured.url.queryParameters['needsPlanning'], 'true');
    expect(captured.url.queryParameters['status'], 'New');
    expect(captured.url.queryParameters['query'], 'شرکت');
    expect(captured.url.queryParameters.containsKey('overdue'), isFalse);
  });

}
