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

  test('package catalog API loads and saves audited package definitions', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response(jsonEncode([
          {
            'code': 'premium',
            'name': 'پریمیوم',
            'description': 'پک ویژه',
            'isActive': true,
            'unitPrice': 250000,
            'items': [
              {'name': 'پسته', 'quantity': 1, 'unit': 'بسته', 'unitPrice': 250000}
            ],
          }
        ]), 200);
      }
      return http.Response(jsonEncode({
        'code': 'premium',
        'name': 'پریمیوم',
        'description': 'پک ویژه',
        'isActive': true,
        'unitPrice': 250000,
        'items': [
          {'name': 'پسته', 'quantity': 1, 'unit': 'بسته', 'unitPrice': 250000}
        ],
      }), 200);
    });
    final api = CorporateApiClient(client: client, baseUrl: 'https://api.test');

    final packages = await api.fetchPackages();
    expect(packages.single.name, 'پریمیوم');
    expect(packages.single.items.single.unitPrice, 250000);
    final saved = await api.savePackage(
      code: 'premium',
      name: 'پریمیوم',
      description: 'پک ویژه',
      isActive: true,
      items: packages.single.items,
    );

    expect(saved.unitPrice, 250000);
    expect(requests[0].url.path, '/api/v1/admin/corporate-requests/packages');
    expect(requests[0].headers['authorization'], 'Bearer corporate-test-token');
    expect(requests[1].method, 'PUT');
    expect(requests[1].url.path, '/api/v1/admin/corporate-requests/packages/premium');
    expect(jsonDecode(requests[1].body)['items'].single['unitPrice'], 250000);
  });

  test('corporate metrics parse the conversion and first-contact funnel', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({
      'newCount': 2,
      'unfollowedCount': 1,
      'totalCount': 10,
      'activeCount': 6,
      'finalizedCount': 4,
      'conversionRatePercent': 40.0,
      'activePipelineBudget': 1250000,
      'averageHoursToFirstContact': 3.5,
      'firstContactCount': 5,
    }), 200));

    final summary = await CorporateApiClient(client: client, baseUrl: 'https://api.test').fetchSummary();

    expect(summary.totalCount, 10);
    expect(summary.activeCount, 6);
    expect(summary.finalizedCount, 4);
    expect(summary.conversionRatePercent, 40.0);
    expect(summary.activePipelineBudget, 1250000);
    expect(summary.averageHoursToFirstContact, 3.5);
    expect(summary.firstContactCount, 5);
  });

}
