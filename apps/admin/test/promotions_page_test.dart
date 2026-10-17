import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/promotions_page.dart';

void main() {
  setUp(
    () => OwnerSession.instance.establish(
      accessToken: 'fixture',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      email: 'fixture@example.test',
    ),
  );
  tearDown(() => OwnerSession.instance.clear());
  test(
    'coupon client sends auth and proof and decodes Persian validation',
    () async {
      final api = PromotionsApiClient(
        baseUrl: 'http://localhost:5080/',
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/admin/promotions/WELCOME10');
          expect(r.headers['authorization'], 'Bearer fixture');
          expect(r.headers['X-Admin-Step-Up'], 'proof');
          expect(jsonDecode(r.body)['kind'], 'Percent');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'errors': {
                  'value': ['درصد معتبر نیست'],
                },
              }),
            ),
            400,
          );
        }),
      );
      await expectLater(
        api.send(
          'PUT',
          '/WELCOME10',
          body: {'kind': 'Percent'},
          proof: 'proof',
        ),
        throwsA(predicate((e) => e.toString().contains('درصد معتبر نیست'))),
      );
    },
  );
  testWidgets(
    'desktop list displays state and editor validates numeric fields',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PromotionsApiClient(
        client: MockClient((r) async => http.Response('[]', 200)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: PromotionsPage(api: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('هنوز کوپنی'), findsOneWidget);
      await tester.tap(find.text('کوپن جدید'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'کد انگلیسی؛ مثل WELCOME10'),
        'WELCOME10',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'نام کوپن'),
        'خوش‌آمد',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'درصد تخفیف'),
        'invalid',
      );
      await tester.tap(find.text('ذخیره کوپن'));
      await tester.pumpAndSettle();
      expect(find.text('عدد معتبر وارد کنید.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
