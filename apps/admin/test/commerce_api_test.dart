import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/commerce_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'commerce-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.test',
    );
  });

  tearDown(OwnerSession.instance.clear);

  test(
    'commerce settings update sends bearer and fresh step-up proof',
    () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'taxRatePercent': 9,
            'shippingMethods': [
              {
                'code': 'pickup',
                'title': 'تحویل حضوری',
                'price': 0,
                'freeAbove': 0,
                'isActive': true,
                'internalCost': 0,
              },
            ],
            'updatedAt': '2026-10-09T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final settings = CommerceSettings(
        taxRatePercent: 9,
        shippingMethods: [
          ShippingMethod(
            code: 'pickup',
            title: 'تحویل حضوری',
            price: 0,
            freeAbove: 0,
            isActive: true,
            internalCost: 0,
          ),
        ],
      );

      await CommerceApiClient(
        client: client,
        baseUrl: 'https://api.test',
      ).updateSettings(settings, stepUpToken: 'fresh-proof');

      expect(captured.method, 'PUT');
      expect(captured.url.path, '/api/v1/admin/commerce/settings');
      expect(captured.headers['authorization'], 'Bearer commerce-test-token');
      expect(captured.headers['x-admin-step-up'], 'fresh-proof');
      expect(jsonDecode(captured.body)['taxRatePercent'], 9);
    },
  );
}
