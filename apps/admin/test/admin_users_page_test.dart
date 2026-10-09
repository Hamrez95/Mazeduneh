import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_users_api.dart';
import 'package:mazeduneh_admin/admin_users_page.dart';
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
    tester.view.physicalSize = const Size(360, 1600);
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

  testWidgets('lets the owner edit a member permission and submits the selected set', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final requests = <http.Request>[];
    final permissions = <String>['inventory.read'];
    var failPermissionUpdate = true;
    final api = AdminUsersApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/roles')) {
          return http.Response(jsonEncode([
            {'role': 'WarehouseOperator', 'permissions': ['inventory.read', 'inventory.write'], 'titleFa': 'اپراتور انبار'},
          ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        if (request.url.path.endsWith('/permissions')) {
          if (failPermissionUpdate) {
            return http.Response(jsonEncode({'message': 'خطای آزمایشی'}), 500, headers: {'content-type': 'application/json; charset=utf-8'});
          }
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
      }),
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Directionality(textDirection: TextDirection.rtl, child: AdminUsersPage(api: api)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دسترسی‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('دسترسی‌های همکار'), findsOneWidget);
    final exportPermission = find.widgetWithText(CheckboxListTile, 'دریافت خروجی سفارش‌ها');
    await tester.ensureVisible(exportPermission);
    await tester.tap(exportPermission);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره دسترسی‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('دسترسی‌های همکار'), findsOneWidget);
    expect(find.text('خطای آزمایشی'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(exportPermission).value, isTrue);

    failPermissionUpdate = false;
    await tester.tap(find.text('ذخیره دسترسی‌ها'));
    await tester.pumpAndSettle();

    final update = requests.lastWhere((request) => request.url.path.endsWith('/permissions'));
    expect((jsonDecode(update.body) as Map<String, dynamic>)['permissions'], ['inventory.read', 'orders.export']);
    expect(requests.where((request) => request.url.path.endsWith('/permissions')), hasLength(2));
    expect(find.text('دسترسی‌های کاربر به‌روزرسانی شد.'), findsOneWidget);
  });
}

Map<String, dynamic> userJson({String role = 'Owner', List<String> permissions = const ['users.read']}) => {
      'id': role == 'Owner' ? 'owner-1' : 'member-1',
      'email': role == 'Owner' ? 'owner@example.com' : 'warehouse@example.com',
      'displayName': role == 'Owner' ? 'مدیر اصلی' : 'اپراتور انبار',
      'role': role,
      'isActive': true,
      'permissions': permissions,
      'createdAt': '2026-10-03T12:00:00Z',
      'deactivatedAt': null,
    };
