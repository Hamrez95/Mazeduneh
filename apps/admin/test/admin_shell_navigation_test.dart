import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/admin_shell.dart';

void main() {
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
}
