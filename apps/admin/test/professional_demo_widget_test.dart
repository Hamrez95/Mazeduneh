import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/professional_demo_main.dart';

Future<void> signInToProfessionalDemo(WidgetTester tester) async {
  await tester.tap(find.text('پرکردن خودکار'));
  final Finder loginButton = find.text('ورود به پنل نمایشی');
  await tester.ensureVisible(loginButton);
  await tester.pumpAndSettle();
  await tester.tap(loginButton);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('professional demo signs in and opens dashboard', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MazedunehProfessionalDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('ورود به پنل مدیریت'), findsOneWidget);
    expect(find.text('admin@mazeduneh.ir'), findsOneWidget);

    await signInToProfessionalDemo(tester);

    expect(find.textContaining('سلام حمیدرضا'), findsOneWidget);
    expect(find.text('فروش ثبت‌شده'), findsOneWidget);
    expect(find.textContaining('داده آزمایشی'), findsWidgets);
  });

  testWidgets('professional demo can add a local draft product', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MazedunehProfessionalDemoApp());
    await tester.pumpAndSettle();
    await signInToProfessionalDemo(tester);

    await tester.tap(find.text('محصولات').last);
    await tester.pumpAndSettle();

    final Finder addButton = find.text('محصول نمونه');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('محصول نمایشی جدید'), findsOneWidget);
    expect(find.text('پیش‌نویس'), findsWidgets);
  });
}
