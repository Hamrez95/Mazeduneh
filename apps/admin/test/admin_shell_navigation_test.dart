import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/admin_shell.dart';
import 'package:mazeduneh_admin/auth_session.dart';

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
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: AdminShell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('سفارش‌ها'), findsWidgets);
        expect(find.text('دسترسی به این بخش محدود است.'), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
        expect(
          find.byType(BottomAppBar),
          width < 900 ? findsOneWidget : findsNothing,
        );
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
