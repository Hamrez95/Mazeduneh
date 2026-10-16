import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_mfa_settings_dialog.dart';
import 'package:mazeduneh_admin/auth_api.dart';
import 'package:mazeduneh_admin/auth_session.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'unverified-session',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'member@example.test',
      role: 'StoreManager',
      permissions: const ['orders.read'],
      storeId: 'tenant-a',
    );
  });

  tearDown(() {
    OwnerSession.instance.clear();
  });

  testWidgets('enrolls a personal authenticator on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <http.Request>[];
    final auth = AuthApiClient(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'enabled': false}), 200);
        }
        if (request.url.path.endsWith('/enrollment')) {
          return http.Response(
            jsonEncode({
              'secret': 'JBSWY3DPEHPK3PXP',
              'provisioningUri':
                  'otpauth://totp/Mazeduneh%20Admin?secret=JBSWY3DPEHPK3PXP',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 10))
                  .toIso8601String(),
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'accessToken': 'verified-session',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 9))
                .toIso8601String(),
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAdminMfaSettingsDialog(context, auth: auth),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'رمز عبور فعلی',
      ),
      'current-password',
    );
    await tester.pump();
    await tester.tap(find.text('شروع راه‌اندازی'));
    await tester.pumpAndSettle();
    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    final codeField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'کد ۶ رقمی برنامه',
    );
    await tester.enterText(codeField, '123456');
    await tester.pump();
    await tester.ensureVisible(find.text('تأیید و فعال‌سازی'));
    await tester.tap(find.text('تأیید و فعال‌سازی'));
    await tester.pumpAndSettle();
    expect(requests.map((request) => request.url.path), [
      '/api/v1/admin/auth/mfa',
      '/api/v1/admin/auth/mfa/enrollment',
      '/api/v1/admin/auth/mfa/confirm',
    ]);
    expect(OwnerSession.instance.bearerToken, 'verified-session');
    expect(find.text('تأیید دومرحله‌ای فعال است'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
