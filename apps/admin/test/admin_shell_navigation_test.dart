import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_shell.dart';
import 'package:mazeduneh_admin/admin_theme.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/order_api.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('sidebar badge preserves order label width at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(OwnerSession.instance.clear);
      OwnerSession.instance.establish(
        accessToken: 'badge-test', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
        email: 'badge@example.test', role: 'ReadOnlyAnalyst', permissions: ['dashboard.read', 'orders.read'],
      );
      final api = OrderApiClient(baseUrl: 'https://api.test', client: MockClient((request) async {
        final Object body = request.url.path.endsWith('/dashboard')
            ? {'awaitingPayment': 2, 'processing': 1, 'shipped': 0, 'delivered': 0,
                'paidRevenue': 0, 'todayRevenue': 0, 'financialsVisible': false, 'lowStock': [], 'expiringSoon': []}
            : request.url.path.endsWith('/dashboard/preferences')
                ? {'widgets': [for (final id in DashboardPreferences.ids) {'id': id, 'visible': id == 'metrics'}]}
                : request.url.path.endsWith('/notifications') ? {'awaitingPayment': 2, 'lowStockItems': 0, 'items': []} : {};
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      await tester.pumpWidget(MaterialApp(
        theme: buildAdminTheme(),
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: Directionality(textDirection: TextDirection.rtl, child: AdminShell(dashboardApi: api, ordersApi: api)),
      ));
      await tester.pumpAndSettle();
      final title = find.text('سفارش‌ها').first;
      final tile = find.ancestor(of: title, matching: find.byType(ListTile)).first;
      final badge = find.descendant(of: tile, matching: find.text('۳'));
      expect(badge, findsOneWidget);
      expect(tester.getSize(title).width, greaterThan(60));
      expect(tester.getSize(title).height, lessThan(50 * scale));
      expect(tester.getSize(badge).width, lessThan(72));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('mobile shell keeps primary navigation focused and moves secondary pages to more', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: Directionality(textDirection: TextDirection.rtl, child: AdminShell())));
    await tester.pump();

    expect(find.text('بیشتر'), findsOneWidget);
    expect(find.text('اعلان‌ها'), findsNothing);

    await tester.tap(find.text('بیشتر'));
    await tester.pumpAndSettle();

    expect(find.text('بخش‌های بیشتر'), findsOneWidget);
    expect(find.text('اعلان‌ها'), findsOneWidget);
    expect(find.text('فروش سازمانی'), findsOneWidget);
  });
  for (final width in [360.0, 390.0, 768.0, 1280.0]) {
    testWidgets(
      'secure navigation shell stays readable at $width px with enlarged text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(OwnerSession.instance.clear);

        OwnerSession.instance.establish(
          accessToken: 'shell-test-token',
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
          email: 'analyst@example.test',
          role: 'ReadOnlyAnalyst',
          permissions: ['orders.read'],
        );
        final ordersApi = OrderApiClient(
          client: MockClient((_) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
          baseUrl: 'https://api.test',
        );
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: AdminShell(ordersApi: ordersApi),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('سفارش‌ها'), findsWidgets);
        expect(find.text('هنوز سفارشی ثبت نشده است'), findsOneWidget);
        expect(find.text('دسترسی به این بخش محدود است.'), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(
          find.byType(BottomAppBar),
          width < 900 ? findsOneWidget : findsNothing,
        );
        await tester.ensureVisible(
          find.text('سفارش‌های جدید بعد از ثبت در این فهرست دیده می‌شوند.'),
        );
        await tester.pumpAndSettle();
        final layoutException = tester.takeException();
        expect(
          layoutException,
          isNull,
          reason: layoutException is FlutterError
              ? layoutException.toStringDeep()
              : '$layoutException',
        );
      },
    );
  }

}
