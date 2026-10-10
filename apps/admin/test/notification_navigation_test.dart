import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/admin_navigation.dart';
import 'package:mazeduneh_admin/notifications_page.dart';
import 'package:mazeduneh_admin/notification_tile.dart';
import 'package:mazeduneh_admin/order_api.dart';

const notice = AdminNotification(type: 'awaiting-payment', title: '12 سفارش در انتظار پرداخت', detail: 'بررسی 2 سفارش', target: AdminNavigationTarget(module: 'orders', filter: 'AwaitingPayment'));

Widget harness(Widget child, {double textScale = 1}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)),
    );

http.Response notices({int status = 200, bool empty = false}) => http.Response(
      jsonEncode({'awaitingPayment': 12, 'lowStockItems': 0, 'items': empty ? [] : [
        {'type': notice.type, 'title': notice.title, 'detail': notice.detail, 'target': {'module': 'orders', 'filter': 'AwaitingPayment'}},
      ]}), status, headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => OwnerSession.instance.establish(accessToken: 'notification-test',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)), email: 'owner@example.test'));
  tearDown(OwnerSession.instance.clear);

  testWidgets('notice has Persian digits and keyboard queue navigation at 360 px with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AdminNavigationIntent? destination;
    await tester.pumpWidget(harness(AdminNotificationTile(item: notice, onNavigate: (value) => destination = value), textScale: 2));
    expect(find.text('۱۲ سفارش در انتظار پرداخت'), findsOneWidget);
    expect(find.text('بررسی ۲ سفارش'), findsOneWidget);
    final button = find.widgetWithText(TextButton, 'مشاهده سفارش‌ها');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    Focus.of(tester.element(find.text('مشاهده سفارش‌ها'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(destination, const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.awaitingPayment));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown notification type never guesses a route', (tester) async {
    await tester.pumpWidget(harness(AdminNotificationTile(
      item: const AdminNotification(type: 'future-provider-event', title: 'اعلان', detail: 'توضیح'), onNavigate: (_) {},
    )));
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('اعلان'), findsOneWidget);
  });

  testWidgets('restricted role sees the notice without a forbidden destination', (tester) async {
    OwnerSession.instance.updateIdentity(role: 'LimitedViewer', permissions: ['dashboard.read']);
    await tester.pumpWidget(harness(AdminNotificationTile(item: notice, onNavigate: (_) {})));
    expect(find.text('مشاهده سفارش‌ها'), findsNothing);
  });

  testWidgets('stock notice goes to inventory', (tester) async {
    AdminNavigationIntent? destination;
    await tester.pumpWidget(harness(AdminNotificationTile(
      item: const AdminNotification(type: 'low-stock', title: 'موجودی کم', detail: '1 بسته', target: AdminNavigationTarget(module: 'inventory', sku: 'SKU-1', batchCode: 'B-1')),
      onNavigate: (value) => destination = value,
    )));
    await tester.tap(find.text('مشاهده موجودی'));
    expect(destination, const AdminNavigationIntent(module: AdminModule.inventory, sku: 'SKU-1', batchCode: 'B-1'));
  });

  testWidgets('notification center retains stale notices after a failed refresh and recovers', (tester) async {
    var calls = 0;
    final client = MockClient((_) async => ++calls == 2 ? notices(status: 503) : notices());
    AdminNavigationIntent? destination;
    await tester.pumpWidget(harness(NotificationsPage(
      api: OrderApiClient(client: client, baseUrl: 'https://api.test'), onNavigate: (value) => destination = value,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('بارگذاری مجدد'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اعلان‌های قبلی نمایش داده می‌شوند'), findsOneWidget);
    expect(find.text('۱۲ سفارش در انتظار پرداخت'), findsOneWidget);
    await tester.tap(find.byTooltip('بارگذاری مجدد'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اعلان‌های قبلی نمایش داده می‌شوند'), findsNothing);
    await tester.tap(find.text('مشاهده سفارش‌ها'));
    expect(destination, const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.awaitingPayment));
  });

  testWidgets('forbidden refresh hides previously loaded notices', (tester) async {
    var calls = 0;
    final client = MockClient((_) async => ++calls == 1 ? notices() : notices(status: 403));
    await tester.pumpWidget(harness(NotificationsPage(api: OrderApiClient(client: client, baseUrl: 'https://api.test'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('بارگذاری مجدد'));
    await tester.pumpAndSettle();
    expect(find.text('دسترسی به این بخش محدود است.'), findsOneWidget);
    expect(find.text('۱۲ سفارش در انتظار پرداخت'), findsNothing);
  });

  testWidgets('empty notification center explains where future notices appear', (tester) async {
    await tester.pumpWidget(harness(NotificationsPage(api: OrderApiClient(
      client: MockClient((_) async => notices(empty: true)), baseUrl: 'https://api.test',
    ))));
    await tester.pumpAndSettle();
    expect(find.text('فعلاً اعلان مهمی ندارید'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification center shows loading until the first response arrives', (tester) async {
    final pending = Completer<http.Response>();
    await tester.pumpWidget(harness(NotificationsPage(api: OrderApiClient(
      client: MockClient((_) => pending.future), baseUrl: 'https://api.test',
    ))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(notices());
    await tester.pumpAndSettle();
    expect(find.text('۱۲ سفارش در انتظار پرداخت'), findsOneWidget);
  });

  testWidgets('first-load error provides a safe refresh path', (tester) async {
    var calls = 0;
    final client = MockClient((_) async => ++calls == 1 ? notices(status: 503) : notices());
    await tester.pumpWidget(harness(NotificationsPage(api: OrderApiClient(client: client, baseUrl: 'https://api.test'))));
    await tester.pumpAndSettle();
    expect(find.text('بارگذاری اطلاعات انجام نشد.'), findsOneWidget);
    await tester.tap(find.byTooltip('بارگذاری مجدد'));
    await tester.pumpAndSettle();
    expect(find.text('۱۲ سفارش در انتظار پرداخت'), findsOneWidget);
  });

}
