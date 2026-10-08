import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_theme.dart';
import 'package:mazeduneh_admin/auth_api.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/secure_main.dart';

http.Response identity() => http.Response(
  jsonEncode({
    'authenticated': true,
    'role': 'Owner',
    'permissions': ['orders.read'],
  }),
  200,
);
http.Response login() => http.Response(
  jsonEncode({
    'accessToken': 'test-token',
    'expiresAt': DateTime.now()
        .toUtc()
        .add(const Duration(hours: 1))
        .toIso8601String(),
    'email': 'owner@example.test',
  }),
  200,
);

void main() {
  setUp(OwnerSession.instance.clear);
  tearDown(OwnerSession.instance.clear);

  Future<void> pumpApp(
    WidgetTester tester,
    MockClient client, {
    String fragment = '',
    Widget? child,
  }) async {
    await tester.pumpWidget(
      MazedunehSecureAdminApp(
        authApi: AuthApiClient(
          client: client,
          baseUrl: 'https://api.example.test',
        ),
        initialUri: Uri.parse('https://admin.example.test/#$fragment'),
        child: child ?? const Scaffold(body: Text('protected data')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('default release root mounts the permission-filtered shared shell', (tester) async {
    OwnerSession.instance.establish(
      accessToken: 'test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      email: 'analyst@example.test',
      role: 'ReadOnlyAnalyst',
      permissions: ['orders.read'],
    );
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MazedunehSecureAdminApp(
        authApi: AuthApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'authenticated': true,
                'role': 'ReadOnlyAnalyst',
                'permissions': ['orders.read'],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
          baseUrl: 'https://api.example.test',
        ),
        initialUri: Uri.parse('https://admin.example.test/'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.ancestor(
        of: find.text('سفارش‌ها'),
        matching: find.byType(ListTile),
      ),
      findsOneWidget,
    );
    expect(find.text('محصولات'), findsNothing);
  });

  testWidgets(
    'release app uses the central theme and login preserves failed drafts',
    (tester) async {
      await pumpApp(tester, MockClient((_) async => http.Response('{}', 401)));
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .scaffoldBackgroundColor,
        AdminColors.canvas,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'owner@example.test',
      );
      await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
      await tester.tap(find.byTooltip('نمایش رمز عبور'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('ایمیل یا رمز عبور صحیح نیست.'), findsOneWidget);
      expect(find.text('protected data'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'owner@example.test',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        'wrong-password',
      );
    },
  );

  testWidgets(
    'provisional login and invalid session never build protected content',
    (tester) async {
      final validation = Completer<http.Response>();
      await pumpApp(
        tester,
        MockClient(
          (request) async =>
              request.url.path.endsWith('/login') ? login() : validation.future,
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'owner@example.test',
      );
      await tester.enterText(find.byType(TextFormField).last, 'test-password');
      await tester.tap(find.text('ورود به پنل'));
      await tester.pump();
      expect(OwnerSession.instance.isAuthenticated, isFalse);
      expect(find.text('protected data'), findsNothing);
      validation.complete(http.Response('{}', 401));
      await tester.pumpAndSettle();
      expect(OwnerSession.instance.isAuthenticated, isFalse);
      expect(find.text('protected data'), findsNothing);
    },
  );

  testWidgets('restored invalid session is removed before protected content', (
    tester,
  ) async {
    OwnerSession.instance.establish(
      accessToken: 'revoked',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      email: 'old@example.test',
    );
    await pumpApp(tester, MockClient((_) async => http.Response('{}', 401)));
    expect(find.text('protected data'), findsNothing);
    expect(find.text('ورود به پنل'), findsOneWidget);
    expect(OwnerSession.instance.email, isNull);
  });

  testWidgets(
    'logout disposes detail routes and a fresh session cannot recover old data',
    (tester) async {
      final apiClient = MockClient(
        (request) async => request.url.path.endsWith('/logout')
            ? http.Response('', 204)
            : request.url.path.endsWith('/login')
            ? login()
            : identity(),
      );
      final api = AuthApiClient(
        client: apiClient,
        baseUrl: 'https://api.example.test',
      );
      await api.login(email: 'owner@example.test', password: 'test-password');
      await pumpApp(
        tester,
        apiClient,
        child: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('old private detail')),
                ),
              ),
              child: const Text('detail'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('detail'));
      await tester.pumpAndSettle();
      expect(find.text('old private detail'), findsOneWidget);
      await api.logout();
      await tester.pumpAndSettle();
      expect(find.text('old private detail'), findsNothing);
      expect(find.text('ورود به پنل'), findsOneWidget);
      await api.login(email: 'owner@example.test', password: 'test-password');
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
      expect(find.text('old private detail'), findsNothing);
    },
  );

  testWidgets('logout removes default root dialogs containing private data', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => request.url.path.endsWith('/logout')
          ? http.Response('', 204)
          : identity(),
    );
    OwnerSession.instance.establish(
      accessToken: 'test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      email: 'owner@example.test',
    );
    await pumpApp(
      tester,
      client,
      child: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  const AlertDialog(content: Text('private root dialog')),
            ),
            child: const Text('open dialog'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('private root dialog'), findsOneWidget);
    await AuthApiClient(client: client).logout();
    await tester.pumpAndSettle();
    expect(find.text('private root dialog'), findsNothing);
    expect(find.text('ورود به پنل'), findsOneWidget);
  });

  testWidgets('same-frame session replacement cannot reparent private root routes', (tester) async {
    final client = MockClient((_) async => identity());
    OwnerSession.instance.establish(accessToken: 'session-a', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)), email: 'a@example.test');
    await pumpApp(tester, client, child: Builder(builder: (context) => Scaffold(body: FilledButton(
      onPressed: () => showDialog<void>(context: context, builder: (_) => const AlertDialog(content: Text('session-a-private'))),
      child: const Text('open dialog'),
    ))));
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    OwnerSession.instance.clear();
    OwnerSession.instance.establish(accessToken: 'session-b', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)), email: 'b@example.test');
    await tester.pumpAndSettle();
    expect(find.text('session-a-private'), findsNothing);
    expect(find.text('open dialog'), findsOneWidget);
  });

  testWidgets('expiry removes private root dialogs without waiting for another request', (tester) async {
    final client = MockClient((_) async => identity());
    OwnerSession.instance.establish(accessToken: 'short-session', expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 10)), email: 'owner@example.test');
    await pumpApp(tester, client, child: Builder(builder: (context) => Scaffold(body: FilledButton(
      onPressed: () => showDialog<void>(context: context, builder: (_) => const AlertDialog(content: Text('expired private data'))),
      child: const Text('open dialog'),
    ))));
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('expired private data'), findsNothing);
    expect(find.text('ورود به پنل'), findsOneWidget);
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });

  for (final status in [204, 400]) {
    testWidgets(
      'release fragment invitation handles status $status and preserves invalid draft',
      (tester) async {
        await pumpApp(
          tester,
          MockClient((request) async {
            expect(request.url.path, '/api/v1/admin/auth/accept-invite');
            expect(jsonDecode(request.body)['token'], 'fragment-test-token');
            return http.Response(
              status == 204
                  ? ''
                  : jsonEncode({
                      'message': 'دعوت معتبر نیست یا منقضی شده است.',
                    }),
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
          fragment: 'invite=fragment-test-token',
        );
        await tester.enterText(
          find.byType(TextFormField).first,
          'new-test-password',
        );
        await tester.enterText(
          find.byType(TextFormField).last,
          'new-test-password',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        if (status == 204) {
          expect(find.text('حساب شما فعال شد'), findsOneWidget);
          await tester.tap(find.text('رفتن به صفحه ورود'));
          await tester.pumpAndSettle();
          expect(find.text('ورود به پنل'), findsOneWidget);
        } else {
          expect(
            find.text('دعوت معتبر نیست یا منقضی شده است.'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).first)
                .controller!
                .text,
            'new-test-password',
          );
        }
        expect(find.text('protected data'), findsNothing);
      },
    );
  }
}
