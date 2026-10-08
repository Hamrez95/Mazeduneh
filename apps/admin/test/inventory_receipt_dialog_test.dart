import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/inventory_receipt_dialog.dart';

const product = Product(id: '1', title: 'پسته', slug: 'pistachio', category: 'nuts', origin: 'IR', unitType: 'Weight',
  isPublished: true, variants: [ProductVariant(sku: 'PI-250', quantity: 250, displayLabel: '۲۵۰ گرم', price: 1000, availablePackages: 0)]);
Finder field(String label) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);

void main() {
  testWidgets('fractional receipt quantity is rejected without saving', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: BatchDialog(
            products: const [product],
            onSave: (_) async {
              attempts++;
              throw StateError('should not be called');
            },
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await tester.enterText(field('کد خرید / بچ'), 'LOT-FRACTION');
    await tester.enterText(field('نام تأمین‌کننده'), 'تأمین تست');
    await tester.enterText(field('تاریخ تولید'), '۲۰۲۵-۱۲-۰۱');
    await tester.enterText(field('تاریخ انقضا'), '۲۰۳۰-۰۱-۰۱');
    await tester.enterText(field('تعداد بستهٔ خریداری‌شده'), '۱٫۵');
    await tester.tap(find.text('ثبت خرید'));
    await tester.pumpAndSettle();

    expect(attempts, 0);
    expect(find.text('تعداد صحیح بین ۱ و ۱ میلیون وارد کنید.'), findsOneWidget);
    expect(tester.widget<TextField>(field('تعداد بستهٔ خریداری‌شده')).controller!.text, '۱٫۵');
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('receipt preserves failed draft and sends dated costs at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1100); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      InventoryReceiptCommand? captured;
      await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(width == 360 ? 2 : 1)), child: child!),
        home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: BatchDialog(products: const [product], onSave: (c) async {
          captured = c; throw Exception('network unavailable');
        })))));
      await tester.pumpAndSettle();
      for (final entry in {'کد خرید / بچ': 'receipt-1', 'نام تأمین‌کننده': 'تأمین تهران', 'نام شخص تماس (اختیاری)': 'خانم رضایی', 'شماره تماس تأمین‌کننده (اختیاری)': '۰۹۱۲۰۰۰۰۰۰۰', 'ایمیل تأمین‌کننده (اختیاری)': 'sales@example.test', 'نشانی تأمین‌کننده (اختیاری)': 'تهران، بازار بزرگ', 'یادداشت دربارهٔ تأمین‌کننده (اختیاری)': 'تحویل صبح', 'تعداد بستهٔ خریداری‌شده': '۱۲',
        'تاریخ خرید': '۲۰۲۶-۰۱-۰۱', 'تاریخ تولید': '۲۰۲۵-۱۲-۰۱', 'تاریخ انقضا': '۲۰۳۰-۰۱-۰۱',
        'قیمت خرید / مواد هر بسته (تومان)': '۴۰۰', 'بسته‌بندی هر بسته (تومان)': '۵۰', 'هزینهٔ جانبی هر بسته (تومان)': '۱۰'}.entries) {
        await tester.ensureVisible(field(entry.key)); await tester.pumpAndSettle();
        await tester.enterText(field(entry.key), entry.value);
      }
      await tester.tap(find.text('ثبت خرید')); await tester.pumpAndSettle();
      expect(captured?.costPrice, 4000); expect(captured?.packagingCost, 500);
      expect(captured?.receivedPackages, 12); expect(captured?.supplier, 'تأمین تهران');
      expect(captured?.supplierContactName, 'خانم رضایی'); expect(captured?.supplierPhone, '۰۹۱۲۰۰۰۰۰۰۰');
      expect(captured?.supplierEmail, 'sales@example.test'); expect(captured?.supplierAddress, 'تهران، بازار بزرگ');
      expect(captured?.supplierNotes, 'تحویل صبح');
      expect(captured?.purchasedAt.year, 2026);
      expect(find.textContaining('اطلاعات فرم حفظ شده'), findsOneWidget);
      expect((tester.widget<TextField>(field('کد خرید / بچ')).controller?.text), 'receipt-1');
      expect(tester.takeException(), isNull);
    });
  }
}
