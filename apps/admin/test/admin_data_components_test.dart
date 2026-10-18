import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/admin_table.dart';
import 'package:mazeduneh_admin/admin_theme.dart';
import 'package:mazeduneh_admin/analytics_panels.dart';
import 'package:mazeduneh_admin/order_api.dart';

Widget harness(Widget child) => MaterialApp(
  theme: buildAdminTheme(),
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);
void main() {
  testWidgets(
    'record table searches Persian digits, pages, sorts and opens a record',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? opened;
      await tester.pumpWidget(
        harness(
          AdminRecordTable<int>(
            records: List.generate(12, (i) => i + 1),
            searchText: (n) => 'کالا $n',
            onOpen: (n) => opened = n,
            columns: [
              AdminColumn(
                'شماره',
                (n) => Text('کالا $n'),
                compare: (a, b) => a.compareTo(b),
              ),
            ],
          ),
        ),
      );
      expect(find.text('کالا 1'), findsOneWidget);
      expect(find.text('کالا 12'), findsNothing);
      await tester.ensureVisible(find.byTooltip('صفحهٔ بعد'));
      await tester.tap(find.byTooltip('صفحهٔ بعد'));
      await tester.pumpAndSettle();
      expect(find.text('کالا 12'), findsOneWidget);
      await tester.tap(find.text('کالا 12'));
      expect(opened, 12);
      await tester.enterText(find.byType(TextField), '۲');
      await tester.pumpAndSettle();
      expect(find.text('کالا 2'), findsOneWidget);
      expect(find.text('کالا 12'), findsOneWidget);
      expect(find.text('کالا 11'), findsNothing);
      await tester.tap(find.text('شماره'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [360.0, 1280.0]) {
    testWidgets('real analytics handle losses and sparse days at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = AdminAnalytics(
        days: 7,
        orderCount: 2,
        unitsSold: 3,
        revenue: 300000,
        cost: 250000,
        grossProfit: 50000,
        grossMarginPercent: 16,
        tax: 0,
        netProfit: -10000,
        shippingExpense: 60000,
        dailySales: [
          AdminDailySales(
            day: DateTime.utc(2026, 10, 10),
            orderCount: 1,
            revenue: 100000,
            netProfit: -20000,
          ),
          AdminDailySales(
            day: DateTime.utc(2026, 10, 12),
            orderCount: 1,
            revenue: 200000,
            netProfit: 10000,
          ),
        ],
        orderStates: const [
          AdminOrderStateCount('Paid', 2),
          AdminOrderStateCount('Cancelled', 1),
        ],
      );
      await tester.pumpWidget(harness(AdminAnalyticsPanels(analytics: data)));
      await tester.pumpAndSettle();
      expect(find.text('روند فروش و سود'), findsOneWidget);
      expect(find.text('وضعیت سفارش‌ها'), findsOneWidget);
      await tester.tap(find.text('سود'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'analytics remains compatible with older responses and reads chart records',
    () {
      final base = <String, dynamic>{
        'days': 7,
        'orderCount': 0,
        'unitsSold': 0,
        'revenue': 0,
        'cost': 0,
        'grossProfit': 0,
        'grossMarginPercent': 0,
      };
      expect(AdminAnalytics.fromJson(base).dailySales, isEmpty);
      final data = AdminAnalytics.fromJson({
        ...base,
        'dailySales': [
          {
            'day': '2026-10-18',
            'orderCount': 1,
            'revenue': 100,
            'netProfit': -20,
          },
        ],
        'orderStates': [
          {'state': 'Paid', 'count': 1},
        ],
      });
      expect(data.dailySales.single.day, DateTime.utc(2026, 10, 18));
      expect(data.dailySales.single.netProfit, -20);
      expect(data.orderStates.single.count, 1);
    },
  );
}
