import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/main.dart';
import 'package:mazeduneh_admin/order_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'dashboard-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });

  tearDown(OwnerSession.instance.clear);

  testWidgets('dashboard quick actions expose a guided route on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/dashboard')) {
        return http.Response(
          jsonEncode({
            'awaitingPayment': 2,
            'processing': 3,
            'shipped': 4,
            'delivered': 8,
            'paidRevenue': 1200000,
            'todayRevenue': 850000,
            'periodDays': 1,
            'periodOrderCount': 2,
            'periodRevenue': 850000,
            'averageOrderValue': 425000,
            'lowStock': [],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'awaitingPayment': 2, 'lowStockItems': 0, 'items': []}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    int? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: DashboardPage(
            api: OrderApiClient(client: client, baseUrl: 'https://api.test'),
            onNavigate: (value) => destination = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('امروز چه کاری انجام دهید؟'),
      500,
      maxScrolls: 10,
    );
    expect(find.text('امروز چه کاری انجام دهید؟'), findsOneWidget);
    expect(find.text('ثبت محصول'), findsOneWidget);
    expect(find.text('پیگیری سفارش‌ها'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('پیگیری سفارش‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پیگیری سفارش‌ها'));
    expect(destination, 1);
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('read-only dashboard offers permitted view routes at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      OwnerSession.instance.updateIdentity(role: 'ReadOnlyAnalyst', permissions: [
        'dashboard.read', 'products.read', 'orders.read', 'inventory.read',
      ]);
      int? destination;
      await tester.pumpWidget(_dashboardHarness(onNavigate: (value) => destination = value));
      await tester.pumpAndSettle();
      expect(find.text('وضعیت فروشگاه'), findsOneWidget);
      expect(find.text('سلام حمیدرضا 🌿'), findsNothing);
      await tester.scrollUntilVisible(find.text('مشاهده محصولات'), 400, maxScrolls: 15);
      expect(find.text('ثبت محصول'), findsNothing);
      expect(find.text('اصلاح موجودی'), findsNothing);
      expect(find.text('پیگیری فروش سازمانی'), findsNothing);
      expect(find.text('مشاهده موجودی'), findsOneWidget);

      await tester.ensureVisible(find.text('پیگیری سفارش‌ها'));
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('dashboard-action-1'));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
      // Focus the actual InkWell's descendant and activate it with the keyboard.
      Focus.of(tester.element(find.text('پیگیری سفارش‌ها'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(destination, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dashboard-only role gets an educational empty action state', (tester) async {
    OwnerSession.instance.updateIdentity(role: 'DashboardViewer', permissions: ['dashboard.read']);
    await tester.pumpWidget(_dashboardHarness());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('مسیر عملیاتی برای نقش شما فعال نیست'), 400, maxScrolls: 15);
    expect(find.text('ثبت محصول'), findsNothing);
    expect(find.text('پیگیری سفارش‌ها'), findsNothing);
    expect(find.text('مشاهده موجودی'), findsNothing);
    expect(find.textContaining('با مدیر فروشگاه هماهنگ کنید'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permitted actions stay readable at 360 px and double text scale', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_dashboardHarness(textScale: 2));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ثبت محصول'), 400, maxScrolls: 25);
    expect(tester.takeException(), isNull);
  });

}


Widget _dashboardHarness({ValueChanged<int>? onNavigate, double textScale = 1}) {
  final client = MockClient((request) async => http.Response(
        jsonEncode(request.url.path.endsWith('/dashboard')
            ? {'awaitingPayment': 0, 'processing': 0, 'shipped': 0, 'delivered': 0,
               'paidRevenue': 0, 'todayRevenue': 0, 'lowStock': [], 'expiringSoon': []}
            : {'awaitingPayment': 0, 'lowStockItems': 0, 'items': []}),
        200, headers: {'content-type': 'application/json; charset=utf-8'},
      ));
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: DashboardPage(api: OrderApiClient(client: client, baseUrl: 'https://api.test'), onNavigate: onNavigate),
    ),
  );
}
