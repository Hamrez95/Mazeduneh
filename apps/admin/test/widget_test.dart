import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/main.dart';

void main() {
  testWidgets('admin shell renders branded navigation while dashboard loads', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MazedunehAdminApp());
    await tester.pump();

    expect(find.text('مدیریت مزه‌دونه'), findsOneWidget);
    expect(find.text('سفارش‌ها'), findsOneWidget);
    expect(find.text('محصولات'), findsOneWidget);
    expect(find.text('انبار'), findsOneWidget);
    expect(find.text('بیشتر'), findsOneWidget);

    await tester.tap(find.text('بیشتر'));
    await tester.pumpAndSettle();
    expect(find.text('گزارش‌ها'), findsOneWidget);
  });
}
