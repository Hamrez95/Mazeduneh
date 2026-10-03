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
    tester.view.physicalSize = const Size(360, 800);
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
    expect(find.text('مدیر اصلی'), findsOneWidget);
    expect(find.byTooltip('مدیر اصلی قابل غیرفعال‌سازی نیست'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the short add-user form from the educational empty state', (tester) async {
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
    await tester.tap(find.text('افزودن کاربر').last);
    await tester.pumpAndSettle();
    expect(find.text('برای شروع فقط اطلاعات ضروری را وارد کنید؛ رمز عبور و token در این صفحه ذخیره نمی‌شود.'), findsOneWidget);
    expect(find.text('نام نمایشی'), findsOneWidget);
    expect(find.text('ایمیل کاری'), findsOneWidget);
  });
}

Map<String, dynamic> userJson() => {
      'id': 'owner-1',
      'email': 'owner@example.com',
      'displayName': 'مدیر اصلی',
      'role': 'Owner',
      'isActive': true,
      'permissions': ['users.read'],
      'createdAt': '2026-10-03T12:00:00Z',
      'deactivatedAt': null,
    };
