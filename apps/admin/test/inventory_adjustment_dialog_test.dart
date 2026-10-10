import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/inventory_page.dart';
import 'package:mazeduneh_admin/order_api.dart';

void main() {
  testWidgets('a conflict keeps the adjustment draft and retries with the same operation key', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final keys = <String>[];
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AdjustmentDialog(
              variant: const ProductVariant(
                sku: 'PI-250', quantity: 250, displayLabel: '۲۵۰ گرم',
                price: 5000, availablePackages: 4,
              ),
              onSubmit: (command, operationKey) async {
                attempts++;
                keys.add(operationKey);
                expect(command.delta, -2);
                expect(command.reason, 'شکسته');
                if (attempts == 1) {
                  throw OrderApiException('موجودی تغییر کرده است؛ انبار را تازه‌سازی کنید.', statusCode: 409);
                }
              },
            ),
          ),
          child: const Text('باز کردن اصلاح'),
        )),
      ),
    ));

    await tester.tap(find.text('باز کردن اصلاح'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '-۲');
    await tester.enterText(fields.at(1), 'شکسته');
    await tester.tap(find.text('ثبت اصلاح'));
    await tester.pumpAndSettle();

    expect(find.text('موجودی تغییر کرده است؛ انبار را تازه‌سازی کنید.'), findsOneWidget);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, '-۲');
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text, 'شکسته');
    await tester.tap(find.text('ثبت اصلاح'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(keys, hasLength(2));
    expect(keys.first, keys.last);
    expect(find.text('ثبت اصلاح'), findsNothing);
  });

  testWidgets('a fractional adjustment is rejected and is never submitted', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AdjustmentDialog(
              variant: const ProductVariant(
                sku: 'PI-250', quantity: 250, displayLabel: '۲۵۰ گرم',
                price: 5000, availablePackages: 4,
              ),
              onSubmit: (_, __) async { attempts++; },
            ),
          ),
          child: const Text('باز کردن اصلاح'),
        )),
      ),
    ));

    await tester.tap(find.text('باز کردن اصلاح'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '۱٫۵');
    await tester.enterText(fields.at(1), 'اصلاح تست');
    await tester.tap(find.text('ثبت اصلاح'));
    await tester.pumpAndSettle();

    expect(attempts, 0);
    expect(find.text('عدد معتبر وارد کنید.'), findsOneWidget);
    expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, '۱٫۵');
  });
}
