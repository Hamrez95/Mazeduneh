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
        return http.Response(jsonEncode({'stepUpToken': 'fresh-step-up'}), 200);
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
    expect(find.text('کد تأیید دومرحله‌ای'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'current-password');
    await tester.tap(find.text('تأیید هویت'));
    await tester.pumpAndSettle();
    expect(find.text('کد تأیید دومرحله‌ای'), findsOneWidget);
    expect(requests.single, {'password': 'current-password'});

    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('تأیید هویت'));
    await tester.pumpAndSettle();
    expect(requests.last, {'password': 'current-password', 'mfaCode': '123456'});
    expect(stepUpToken, 'fresh-step-up');
  });
}
