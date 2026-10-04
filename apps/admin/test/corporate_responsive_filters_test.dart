import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/corporate_api.dart';
import 'package:mazeduneh_admin/corporate_requests_page.dart';

void main() {
  setUp(() => OwnerSession.instance.establish(accessToken: 'corporate-responsive-test',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)), email: 'owner@example.test'));
  tearDown(OwnerSession.instance.clear);

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('corporate filters stay usable without overflow at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captured = <Uri>[];
      final client = MockClient((request) async {
        captured.add(request.url);
        return http.Response(jsonEncode(request.url.path.endsWith('/summary')
            ? {'newCount': 12, 'unfollowedCount': 0} : []), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(width == 360 ? 2 : 1)), child: child!,
        ),
        home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: CorporateRequestsPage(
          api: CorporateApiClient(client: client, baseUrl: 'https://api.test'),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('۱۲ جدید'), findsOneWidget);
      expect(find.text('وضعیت درخواست'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'شرکت');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(captured.any((uri) => uri.queryParameters['query'] == 'شرکت'), isTrue);
      await tester.ensureVisible(find.text('پیگیری‌های عقب‌افتاده'));
      await tester.tap(find.text('پیگیری‌های عقب‌افتاده'));
      await tester.pumpAndSettle();
      expect(captured.any((uri) => uri.queryParameters['overdue'] == 'true'), isTrue);
      await tester.ensureVisible(find.text('پیگیری عقب‌افتاده‌ای پیدا نشد'));
      expect(find.text('پیگیری عقب‌افتاده‌ای پیدا نشد'), findsOneWidget);
      await tester.ensureVisible(find.text('نیازمند برنامه‌ریزی'));
      await tester.tap(find.text('نیازمند برنامه‌ریزی'));
      await tester.pumpAndSettle();
      final planning = captured.where((uri) => uri.queryParameters['needsPlanning'] == 'true').last;
      expect(planning.queryParameters.containsKey('overdue'), isFalse);
      await tester.ensureVisible(find.text('همه درخواست‌های فعال برنامه‌ریزی شده‌اند'));
      expect(find.text('همه درخواست‌های فعال برنامه‌ریزی شده‌اند'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
