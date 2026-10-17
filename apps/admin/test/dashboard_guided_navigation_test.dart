import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/admin_navigation.dart';
import 'package:mazeduneh_admin/dashboard_page.dart';
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
      if (request.url.path.endsWith('/dashboard/health')) {
        return http.Response(
          jsonEncode({
            'api': 'healthy',
            'database': 'healthy',
            'migrations': 'tracked',
            'adminAuthentication': 'configured',
            'payment': 'sandbox-enabled',
            'mediaStorage': 'local',
            'ready': true,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
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

    AdminNavigationIntent? destination;
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
    await tester.scrollUntilVisible(find.text('پرداخت: حالت آزمایشی فعال'), 350, maxScrolls: 20);
    expect(find.textContaining('پرداخت آزمایشی فعال است؛ پیش از فروش واقعی، درگاه عملیاتی را تنظیم کنید.'), findsOneWidget);
    expect(find.text('ذخیره‌سازی رسانه: محلی'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('پیگیری سفارش‌ها'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پیگیری سفارش‌ها'));
    expect(destination?.module, AdminModule.orders);
  });

  testWidgets('dashboard recommends setup when payment and storage are disabled', (tester) async {
    await tester.pumpWidget(_dashboardHarness(paymentStatus: 'disabled', storageStatus: 'not-configured'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('ذخیره‌سازی رسانه: پیکربندی نشده'), 350, maxScrolls: 20);
    expect(find.textContaining('درگاه پرداخت غیرفعال است؛ پرداخت اینترنتی سفارش‌ها انجام نمی‌شود.'), findsOneWidget);
    expect(find.textContaining('ذخیره‌سازی رسانه راه‌اندازی نشده است؛ تنظیمات سرویس فایل را بررسی کنید.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard order KPI and low-stock alert navigate to the relevant modules', (tester) async {
    AdminNavigationIntent? destination;
    await tester.pumpWidget(_dashboardHarness(
      onNavigate: (value) => destination = value,
      lowStock: const [
        {'productTitle': 'پسته اکبری', 'sku': 'PI-AKB-250', 'variantLabel': '۲۵۰ گرم', 'availablePackages': 2},
      ],
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('در انتظار پرداخت'), 350, maxScrolls: 20);
    await tester.pumpAndSettle();
    await tester.tap(find.text('در انتظار پرداخت'));
    expect(destination, const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.awaitingPayment));

    destination = null;
    await tester.scrollUntilVisible(find.text('میانگین ارزش سفارش'), 350, maxScrolls: 20);
    await tester.pumpAndSettle();
    await tester.tap(find.text('میانگین ارزش سفارش'));
    expect(destination?.module, AdminModule.reports);
    final today = DateUtils.dateOnly(DateTime.now());
    expect(destination?.createdFromUtc, DateTime(today.year, today.month, today.day).toUtc());
    expect(destination?.createdToUtcExclusive, DateTime(today.year, today.month, today.day + 1).toUtc());

    destination = null;
    await tester.scrollUntilVisible(find.text('پسته اکبری'), 350, maxScrolls: 20);
    await tester.ensureVisible(find.text('پسته اکبری'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پسته اکبری'));
    expect(destination, const AdminNavigationIntent(module: AdminModule.inventory, sku: 'PI-AKB-250'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard priorities navigate to the exact operational filters', (tester) async {
    AdminNavigationIntent? destination;
    await tester.pumpWidget(_dashboardHarness(
      onNavigate: (value) => destination = value,
      problemOrders: 2,
      awaitingPayment: 3,
      corporateRequests: 1,
      lowStock: const [
        {'productTitle': 'پسته اکبری', 'sku': 'PI-AKB-250', 'variantLabel': '۲۵۰ گرم', 'availablePackages': 2},
      ],
      expiringSoon: const [
        {
          'productTitle': 'پسته اکبری',
          'sku': 'PI-AKB-250',
          'variantLabel': '۲۵۰ گرم',
          'batchCode': 'LOT-1405-01',
          'expiresAt': '2026-01-02T03:04:00',
          'remainingPackages': 3,
        },
      ],
    ));
    await tester.pumpAndSettle();

    Future<void> openPriority(String id) async {
      final target = find.byKey(ValueKey('dashboard-priority-$id'));
      await tester.scrollUntilVisible(target, 350, maxScrolls: 20);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
    }

    await openPriority('problem-orders');
    expect(destination, const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.problem));
    await openPriority('awaiting-payment');
    expect(destination, const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.awaitingPayment));
    await openPriority('low-stock');
    expect(destination, const AdminNavigationIntent(module: AdminModule.inventory));
    await openPriority('expiring-stock');
    expect(destination, const AdminNavigationIntent(module: AdminModule.inventory));
    await openPriority('corporate-requests');
    expect(destination, const AdminNavigationIntent(module: AdminModule.corporate));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard priority list explains when there is nothing to follow up', (tester) async {
    await tester.pumpWidget(_dashboardHarness());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('مورد فوری برای پیگیری ندارید'), 350, maxScrolls: 20);
    expect(find.text('مورد فوری برای پیگیری ندارید'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period order KPI carries the selected local day into the orders route', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    AdminNavigationIntent? destination;
    await tester.pumpWidget(_dashboardHarness(onNavigate: (value) => destination = value));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('تعداد سفارش بازه'), 350, maxScrolls: 20);
    await tester.ensureVisible(find.text('تعداد سفارش بازه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعداد سفارش بازه'));

    expect(destination?.module, AdminModule.orders);
    expect(destination?.createdFromUtc, DateTime(today.year, today.month, today.day).toUtc());
    expect(destination?.createdToUtcExclusive, DateTime(today.year, today.month, today.day + 1).toUtc());
  });

  testWidgets('net profit KPI uses and opens the selected report period', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final analyticsRequests = <Uri>[];
    AdminNavigationIntent? destination;
    await tester.pumpWidget(_dashboardHarness(
      onNavigate: (value) => destination = value,
      analyticsRequests: analyticsRequests,
      netProfit: 275000,
    ));
    await tester.pumpAndSettle();

    expect(analyticsRequests, hasLength(1));
    expect(analyticsRequests.single.path, '/api/v1/admin/analytics');
    expect(
      analyticsRequests.single.queryParameters['from'],
      DateTime(today.year, today.month, today.day).toUtc().toIso8601String(),
    );
    expect(
      analyticsRequests.single.queryParameters['to'],
      DateTime(today.year, today.month, today.day + 1).toUtc().toIso8601String(),
    );

    await tester.scrollUntilVisible(find.text('سود خالص بازه'), 350, maxScrolls: 20);
    await tester.ensureVisible(find.text('سود خالص بازه'));
    expect(find.textContaining('۲۷۵'), findsOneWidget);
    await tester.tap(find.text('سود خالص بازه'));

    expect(destination?.module, AdminModule.reports);
    expect(destination?.createdFromUtc, DateTime(today.year, today.month, today.day).toUtc());
    expect(destination?.createdToUtcExclusive, DateTime(today.year, today.month, today.day + 1).toUtc());
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard cost breakdown shows period costs and opens its report at 360px', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateUtils.dateOnly(DateTime.now());
    AdminNavigationIntent? destination;

    await tester.pumpWidget(_dashboardHarness(
      onNavigate: (value) => destination = value,
      analyticsOrderCount: 2,
      grossProfit: 430000,
      productCost: 380000,
      packagingCost: 25000,
      additionalCost: 9000,
      shippingRevenue: 35000,
      shippingExpense: 8000,
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('ریز سود و هزینه'), 350, maxScrolls: 20);
    expect(find.text('بهای محصول'), findsOneWidget);
    expect(find.textContaining('۳۸۰'), findsOneWidget);
    expect(find.text('بسته‌بندی'), findsOneWidget);
    expect(find.text('هزینه‌های جانبی'), findsOneWidget);
    expect(find.textContaining('مالیات پرداختنی در سود محاسبه نمی‌شود'), findsOneWidget);

    final detailsButton = find.ancestor(of: find.text('جزئیات کامل در گزارش سود'), matching: find.byWidgetPredicate((widget) => widget is TextButton));
    await tester.scrollUntilVisible(detailsButton, 350, maxScrolls: 20);
    await tester.pumpAndSettle();
    await tester.tap(detailsButton);
    expect(destination?.module, AdminModule.reports);
    expect(destination?.createdFromUtc, DateTime(today.year, today.month, today.day).toUtc());
    expect(destination?.createdToUtcExclusive, DateTime(today.year, today.month, today.day + 1).toUtc());
    expect(tester.takeException(), isNull);
  });

  testWidgets('expiring stock keeps its Persian-digit date readable on mobile', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_dashboardHarness(textScale: 2, expiringSoon: const [
      {
        'productTitle': 'پسته اکبری',
        'sku': 'PI-AKB-250',
        'variantLabel': '۲۵۰ گرم',
        'batchCode': 'LOT-1405-01',
        'expiresAt': '2026-01-02T03:04:00',
        'remainingPackages': 3,
      },
    ]));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('انقضا: ۲۰۲۶/۰۱/۰۲ ۰۳:۰۴'), 300, maxScrolls: 20);
    expect(find.text('نزدیک به انقضا'), findsOneWidget);
    expect(find.text('انقضا: ۲۰۲۶/۰۱/۰۲ ۰۳:۰۴'), findsOneWidget);
    expect(find.textContaining('۳ بسته'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 768.0, 1280.0]) {
    testWidgets('read-only dashboard offers permitted view routes at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      OwnerSession.instance.updateIdentity(role: 'ReadOnlyAnalyst', permissions: [
        'dashboard.read', 'products.read', 'orders.read', 'inventory.read',
      ]);
      AdminNavigationIntent? destination;
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
      final action = find.byKey(const ValueKey('dashboard-action-orders'));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      // Focus the actual InkWell's descendant and activate it with the keyboard.
      Focus.of(tester.element(find.text('پیگیری سفارش‌ها'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(destination?.module, AdminModule.orders);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dashboard-only role gets an educational empty action state', (tester) async {
    OwnerSession.instance.updateIdentity(role: 'DashboardViewer', permissions: ['dashboard.read']);
    final analyticsRequests = <Uri>[];
    await tester.pumpWidget(_dashboardHarness(
      financialsVisible: false,
      analyticsRequests: analyticsRequests,
      problemOrders: 2,
      awaitingPayment: 3,
      corporateRequests: 4,
      lowStock: const [
        {'productTitle': 'پسته اکبری', 'sku': 'PI-AKB-250', 'variantLabel': '۲۵۰ گرم', 'availablePackages': 2},
      ],
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('مسیر عملیاتی برای نقش شما فعال نیست'), 400, maxScrolls: 15);
    expect(find.byKey(const ValueKey('dashboard-priority-problem-orders')), findsNothing);
    expect(find.byKey(const ValueKey('dashboard-priority-corporate-requests')), findsNothing);
    expect(find.text('۲ سفارش مشکل‌دار'), findsNothing);
    expect(find.text('ثبت محصول'), findsNothing);
    expect(find.text('پیگیری سفارش‌ها'), findsNothing);
    expect(find.text('مشاهده موجودی'), findsNothing);
    expect(find.textContaining('با مدیر فروشگاه هماهنگ کنید'), findsOneWidget);
    expect(find.text('سود خالص بازه'), findsNothing);
    expect(find.text('ریز سود و هزینه'), findsNothing);
    expect(analyticsRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role dashboard editor keeps visibility and ordering in the saved preference', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DashboardPreferences? saved;
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(body: Center(child: FilledButton(
        onPressed: () => showDialog<DashboardPreferences>(
          context: context,
          builder: (_) => DashboardPreferencesDialog(
            initial: DashboardPreferences.defaults,
            onSave: (value) async {
              attempts++;
              if (attempts == 1) throw OrderApiException('خطای موقت', statusCode: 503);
              return value;
            },
          ),
        ).then((value) => saved = value),
        child: const Text('تنظیم'),
      )))),
    ));
    await tester.tap(find.text('تنظیم'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byTooltip('انتقال به پایین').first);
    await tester.pump();
    await tester.tap(find.text('ذخیره چیدمان'));
    await tester.pumpAndSettle();
    expect(find.text('سرویس موقتاً در دسترس نیست؛ بعداً دوباره تلاش کنید.'), findsOneWidget);
    expect(saved, isNull);
    await tester.tap(find.text('ذخیره چیدمان'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.widgets[1].id, 'metrics');
    expect(saved!.widgets[1].visible, isFalse);
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


Widget _dashboardHarness({
  ValueChanged<AdminNavigationIntent>? onNavigate,
  double textScale = 1,
  List<Map<String, dynamic>> lowStock = const [],
  List<Map<String, dynamic>> expiringSoon = const [],
  int problemOrders = 0,
  int awaitingPayment = 0,
  int corporateRequests = 0,
  String paymentStatus = 'sandbox-enabled',
  String storageStatus = 'local',
  bool financialsVisible = true,
  num netProfit = 275000,
  num grossProfit = 275000,
  num productCost = 0,
  num packagingCost = 0,
  num additionalCost = 0,
  num shippingRevenue = 0,
  num shippingExpense = 0,
  int analyticsOrderCount = 0,
  List<Uri>? analyticsRequests,
}) {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/dashboard/health')) {
      return http.Response(
        jsonEncode({
          'api': 'healthy',
          'database': 'healthy',
          'migrations': 'tracked',
          'adminAuthentication': 'configured',
          'payment': paymentStatus,
          'mediaStorage': storageStatus,
          'ready': true,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (request.url.path.endsWith('/analytics')) {
      analyticsRequests?.add(request.url);
      return http.Response(
        jsonEncode({
          'days': 1,
          'orderCount': analyticsOrderCount,
          'unitsSold': 3,
          'revenue': 850000,
          'cost': 575000,
          'grossProfit': grossProfit,
          'grossMarginPercent': 32.35,
          'tax': 0,
          'netProfit': netProfit,
          'shippingRevenue': shippingRevenue,
          'shippingExpense': shippingExpense,
          'productCost': productCost,
          'packagingCost': packagingCost,
          'additionalCost': additionalCost,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(
      jsonEncode(request.url.path.endsWith('/dashboard')
          ? {
              'awaitingPayment': awaitingPayment,
              'problemOrders': problemOrders,
              'corporateNewRequests': corporateRequests,
              'processing': 0,
              'shipped': 0,
              'delivered': 0,
              'paidRevenue': 0,
              'todayRevenue': 0,
              'financialsVisible': financialsVisible,
              'lowStock': lowStock,
              'expiringSoon': expiringSoon,
            }
          : {'awaitingPayment': 0, 'lowStockItems': 0, 'items': []}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
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


