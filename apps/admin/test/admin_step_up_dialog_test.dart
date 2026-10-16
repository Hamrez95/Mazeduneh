import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_step_up_dialog.dart';
import 'package:mazeduneh_admin/auth_api.dart';
import 'package:mazeduneh_admin/auth_session.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'owner-session',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.test',
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('step-up reveals the TOTP field only after a server challenge', (tester) async {
    final requests = <Map<String, dynamic>>[];
    String? stepUpToken;
    final auth = AuthApiClient(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (requests.length == 1) return http.Response('{}', 428);
        return http.Response(jsonEncode({
          'stepUpToken': 'fresh-step-up',
          'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String(),
        }), 200);
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => FilledButton(
          onPressed: () async => stepUpToken = await showAdminStepUpDialog(context, auth: auth),
          child: const Text('Open'),
        )),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('کد شش‌رقمی برنامهٔ تأیید'), findsNothing);

    final passwordField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'رمز عبور فعلی',
    );
    await tester.enterText(passwordField, 'current-password');
    await tester.pump();
    expect(tester.widget<TextField>(passwordField).controller!.text, 'current-password');

    final confirmButton = find.text('تأیید هویت');
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(requests, hasLength(1), reason: 'The password-only step-up request should reach the API first.');
    expect(find.text('کد شش‌رقمی برنامهٔ تأیید'), findsOneWidget);
    expect(requests.single, {'password': 'current-password'});

    final mfaField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'کد شش‌رقمی برنامهٔ تأیید',
    );
    await tester.enterText(mfaField, '123456');
    await tester.pump();
    await tester.ensureVisible(confirmButton);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    expect(requests.last, {'password': 'current-password', 'mfaCode': '123456'});
    expect(stepUpToken, 'fresh-step-up');
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2), reason: 'A live session proof should be reused until it expires.');
    expect(stepUpToken, 'fresh-step-up');
  });
}

