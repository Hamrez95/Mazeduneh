import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_users_api.dart';
import 'package:mazeduneh_admin/admin_users_page.dart';
import 'package:mazeduneh_admin/auth_api.dart';
import 'package:mazeduneh_admin/auth_session.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'users-page-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  testWidgets('shows responsive user cards and protects the owner account', (tester) async {
    tester.view.physicalSize = const Size(360, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = AdminUsersApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async => http.Response(
            jsonEncode(request.url.path.endsWith('/roles')
                ? [
                    {'role': 'WarehouseOperator', 'permissions': ['inventory.read', 'inventory.write'], 'titleFa': 'اپراتور انبار'},
                  ]
                : [userJson()]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );

    await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: AdminUsersPage(api: api))));
    await tester.pumpAndSettle();
    expect(find.text('کاربران و دسترسی‌ها'), findsOneWidget);
    expect(find.text('مدیر اصلی').first, findsOneWidget);
    expect(find.byTooltip('مدیر اصلی قابل ویرایش نیست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the short add-user form from the educational empty state', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = AdminUsersApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async => http.Response(
            jsonEncode(request.url.path.endsWith('/roles')
                ? [
                    {'role': 'WarehouseOperator', 'permissions': ['inventory.read'], 'titleFa': 'اپراتور انبار'},
                  ]
                : []),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );

    await tester.pumpWidget(MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: AdminUsersPage(api: api))));
    await tester.pumpAndSettle();
    expect(find.textContaining('هنوز کاربر دیگری برای این فروشگاه ثبت نشده است'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'افزودن کاربر'));
    await tester.pumpAndSettle();
    expect(find.text('برای شروع فقط اطلاعات ضروری را وارد کنید؛ رمز عبور و token در این صفحه ذخیره نمی‌شود.'), findsOneWidget);
    expect(find.text('نام نمایشی'), findsOneWidget);
    expect(find.text('ایمیل کاری'), findsOneWidget);
  });

  testWidgets('filters users by status, role, and name or email', (tester) async {
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = AdminUsersApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async => http.Response(
            jsonEncode(request.url.path.endsWith('/roles')
                ? [
                    {'role': 'WarehouseOperator', 'permissions': ['inventory.read'], 'titleFa': 'اپراتور انبار'},
                    {'role': 'Accountant', 'permissions': ['reports.read'], 'titleFa': 'حسابدار'},
                  ]
                : [
                    userJson(role: 'WarehouseOperator', hasPassword: true),
                    userJson(role: 'Accountant'),
                  ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );

    await tester.pumpWidget(MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: AdminUsersPage(api: api)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('کارمند انبار'), findsOneWidget);
    expect(find.text('حسابدار فروشگاه'), findsOneWidget);
    expect(find.text('همه (۲)'), findsOneWidget);
    expect(find.text('فعال (۱)'), findsOneWidget);
    expect(find.text('دعوت‌شده (۱)'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'فعال (۱)'));
    await tester.pumpAndSettle();
    expect(find.text('کارمند انبار'), findsOneWidget);
    expect(find.text('حسابدار فروشگاه'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'همه (۲)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('admin-users-search')), 'warehouse@example.com');
    await tester.pumpAndSettle();
    expect(find.text('کارمند انبار'), findsOneWidget);
    expect(find.text('حسابدار فروشگاه'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('admin-users-search')), 'no-match');
    await tester.pumpAndSettle();
    expect(find.text('همکاری با این مشخصات پیدا نشد'), findsOneWidget);
    await tester.tap(find.text('پاک‌کردن فیلترها'));
    await tester.pumpAndSettle();
    expect(find.text('کارمند انبار'), findsOneWidget);
    expect(find.text('حسابدار فروشگاه'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسابدار').last);
    await tester.pumpAndSettle();
    expect(find.text('کارمند انبار'), findsNothing);
    expect(find.text('حسابدار فروشگاه'), findsOneWidget);
  });

  testWidgets('lets the owner edit a member permission and submits the selected set', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final permissions = <String>['inventory.read'];
    final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/step-up')) {
          return http.Response(jsonEncode({
            'stepUpToken': 'fresh-proof',
            'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String(),
          }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.url.path.endsWith('/roles')) {
          return http.Response(jsonEncode([
            {'role': 'WarehouseOperator', 'permissions': ['inventory.read', 'inventory.write'], 'titleFa': 'اپراتور انبار'},
          ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.url.path.endsWith('/permissions')) {
          final selected = (jsonDecode(request.body) as Map<String, dynamic>)['permissions'] as List<dynamic>;
          permissions
            ..clear()
            ..addAll(selected.cast<String>());
          return http.Response(jsonEncode(userJson(role: 'WarehouseOperator', permissions: permissions)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.url.path.endsWith('/users')) {
          return http.Response(jsonEncode([userJson(role: 'WarehouseOperator', permissions: permissions)]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
    final api = AdminUsersApiClient(baseUrl: 'https://api.test', client: client);
    final auth = _FakeAuthApiClient();

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Directionality(textDirection: TextDirection.rtl, child: AdminUsersPage(api: api, auth: auth)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دسترسی‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('دسترسی‌های همکار'), findsOneWidget);
    final exportPermission = find.widgetWithText(CheckboxListTile, 'دریافت خروجی سفارش‌ها');
    await tester.ensureVisible(exportPermission);
    await tester.tap(exportPermission);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره دسترسی‌ها'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await confirmStepUp(tester);
    await tester.pumpAndSettle();
    expect(find.text('تأیید دوبارهٔ هویت'), findsNothing);
    expect(requests.map((request) => request.url.path), contains('/api/v1/admin/users/WarehouseOperator-user/permissions'));

    final update = requests.lastWhere((request) => request.url.path.endsWith('/permissions'));
    expect(update.headers['x-admin-step-up'], 'fresh-proof');
    expect((jsonDecode(update.body) as Map<String, dynamic>)['permissions'], ['inventory.read', 'orders.export']);
    expect(requests.where((request) => request.url.path.endsWith('/permissions')), hasLength(1));
    expect(find.text('دسترسی‌های کاربر به‌روزرسانی شد.'), findsOneWidget);
  });

  testWidgets('lets the owner inspect and revoke a member session after step-up', (tester) async {
    tester.view.physicalSize = const Size(360, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    var activeSessions = true;
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/auth/step-up')) {
        return http.Response(jsonEncode({
          'stepUpToken': 'fresh-proof',
          'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String(),
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (request.url.path.endsWith('/roles')) {
        return http.Response(jsonEncode([
          {'role': 'WarehouseOperator', 'permissions': ['inventory.read'], 'titleFa': 'اپراتور انبار'},
        ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (request.url.path.endsWith('/revoke')) {
        activeSessions = false;
        return http.Response('', 204);
      }
      if (request.url.path.endsWith('/sessions')) {
        return http.Response(jsonEncode(activeSessions ? [
          {'sessionId': 'session-1', 'createdAt': '2026-10-03T12:00:00Z', 'expiresAt': '2026-10-03T20:00:00Z'},
        ] : []), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode([userJson(role: 'WarehouseOperator', hasPassword: true)]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = AdminUsersApiClient(baseUrl: 'https://api.test', client: client);
    final auth = _FakeAuthApiClient();

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Directionality(textDirection: TextDirection.rtl, child: AdminUsersPage(api: api, auth: auth)))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('نشست‌ها'));
    await tester.tap(find.text('نشست‌ها'));
    await tester.pumpAndSettle();
    expect(find.textContaining('نشست‌های کارمند انبار'), findsOneWidget);
    expect(find.textContaining('اعتبار تا:'), findsOneWidget);

    await tester.tap(find.ancestor(of: find.text('لغو نشست'), matching: find.byWidgetPredicate((widget) => widget is TextButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(of: find.text('لغو نشست'), matching: find.byWidgetPredicate((widget) => widget is FilledButton)));
    await tester.pumpAndSettle();
    await confirmStepUp(tester);
    await tester.pumpAndSettle();

    final revoke = requests.singleWhere((request) => request.url.path.endsWith('/revoke'));
    expect(revoke.url.path, '/api/v1/admin/users/WarehouseOperator-user/sessions/session-1/revoke');
    expect(revoke.headers['x-admin-step-up'], 'fresh-proof');
    expect(find.text('نشست فعال دیگری برای این همکار وجود ندارد.'), findsOneWidget);
    expect(find.text('نشست لغو شد؛ دسترسی همان لحظه قطع شد.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> confirmStepUp(WidgetTester tester) async {
  expect(find.text('تأیید دوبارهٔ هویت'), findsOneWidget);
  final passwordField = find.byType(TextField).last;
  await tester.tap(passwordField);
  await tester.enterText(passwordField, 'owner-password');
  await tester.pump();
  expect(tester.widget<TextField>(passwordField).controller!.text, 'owner-password');
  final confirmButton = find.text('تأیید هویت');
  await tester.ensureVisible(confirmButton);
  await tester.tap(confirmButton);
  await tester.pumpAndSettle();
}

Map<String, dynamic> userJson({String role = 'Owner', List<String> permissions = const ['users.read'], bool hasPassword = false}) => {
      'id': role == 'Owner' ? 'owner-1' : '$role-user',
      'email': switch (role) {
        'Owner' => 'owner@example.com',
        'Accountant' => 'accountant@example.com',
        _ => 'warehouse@example.com',
      },
      'displayName': switch (role) {
        'Owner' => 'مدیر اصلی',
        'Accountant' => 'حسابدار فروشگاه',
        _ => 'کارمند انبار',
      },
      'role': role,
      'isActive': true,
      'hasPassword': hasPassword,
      'permissions': permissions,
      'createdAt': '2026-10-03T12:00:00Z',
      'deactivatedAt': null,
    };

class _FakeAuthApiClient extends AuthApiClient {
  @override
  Future<String> stepUp({required String password, String? mfaCode}) async =>
      'fresh-proof';
}
