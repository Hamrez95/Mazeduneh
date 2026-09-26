import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/demo_main.dart';

void main() {
  testWidgets('partner demo shows seeded dashboard and navigates to orders', (tester) async {
    await tester.pumpWidget(const MazedunehPartnerDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('سلام حمیدرضا 🌿'), findsOneWidget);
    expect(find.text('فروش امروز'), findsOneWidget);
    expect(find.textContaining('داده آزمایشی'), findsWidgets);

    final ordersDestination = find.text('سفارش‌ها').last;
    await tester.tap(ordersDestination);
    await tester.pumpAndSettle();

    expect(find.text('NS-1048'), findsOneWidget);
    expect(find.text('پرداخت‌شده'), findsWidgets);
  });

  testWidgets('partner demo product page can add a local draft', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MazedunehPartnerDemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('محصولات').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('محصول نمونه'));
    await tester.pumpAndSettle();

    expect(find.textContaining('محصول نمایشی جدید'), findsOneWidget);
  });
}
