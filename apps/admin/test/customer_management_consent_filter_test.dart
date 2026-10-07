import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/customer_api.dart';
import 'package:mazeduneh_admin/customer_management_page.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'customer-filter-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('consent chips filter the customer list through the admin API', (tester) async {
    final consentFilters = <String?>[];
    final client = MockClient((request) async {
      consentFilters.add(request.url.queryParameters['marketingConsent']);
      return http.Response(jsonEncode([]), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomerManagementPage(
        api: CustomerApiClient(client: client, baseUrl: 'https://api.test'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(consentFilters, [null]);
    await tester.tap(find.widgetWithText(ChoiceChip, 'رضایت ثبت‌شده'));
    await tester.pumpAndSettle();
    expect(consentFilters, [null, 'true']);

    await tester.tap(find.widgetWithText(ChoiceChip, 'بدون رضایت'));
    await tester.pumpAndSettle();
    expect(consentFilters, [null, 'true', 'false']);

    await tester.tap(find.widgetWithText(ChoiceChip, 'همه'));
    await tester.pumpAndSettle();
    expect(consentFilters, [null, 'true', 'false', null]);
    expect(tester.takeException(), isNull);
  });
}
