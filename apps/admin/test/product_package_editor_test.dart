import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/catalog_page.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/edit_product_dialog.dart';
import 'package:mazeduneh_admin/product_package_editor.dart';
import 'package:mazeduneh_admin/admin_theme.dart';
import 'package:mazeduneh_admin/auth_session.dart';

Future<void> fill(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  tearDown(OwnerSession.instance.clear);
  for (final width in [390.0, 1280.0]) {
    testWidgets('creates two weighted packages in one product at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      CreateProductCommand? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAdminTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<CreateProductCommand>(
                    context: context,
                    builder: (_) => const ProductDialog(canWriteCosts: true),
                  );
                },
                child: const Text('بازکردن'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('بازکردن'));
      await tester.pumpAndSettle();
      await fill(tester, 'create-product-title', 'کوکی پروتئینی');
      await fill(tester, 'create-product-slug', 'protein-cookie');
      await fill(tester, 'create-product-origin', 'مزه‌دونه');
      await fill(tester, 'package-0-quantity', '250');
      await fill(tester, 'package-0-price', '200000');
      await fill(tester, 'package-0-stock', '4');
      await fill(tester, 'package-0-cost', '100000');
      await tester.ensureVisible(find.text('افزودن وزن یا تعداد دیگر'));
      await tester.tap(find.text('افزودن وزن یا تعداد دیگر'));
      await tester.pumpAndSettle();
      await fill(tester, 'package-1-quantity', '500');
      await fill(tester, 'package-1-price', '380000');
      await fill(tester, 'package-1-stock', '2');
      await tester.tap(find.text('ذخیره پیش‌نویس'));
      await tester.pumpAndSettle();
      expect(result, isNotNull);
      expect(result!.variants.length, 2);
      expect(result!.isPublished, isFalse);
      expect(result!.variants[0].quantity, 250);
      expect(result!.variants[0].price, 2000000);
      expect(result!.variants[0].costPrice, 1000000);
      expect(result!.variants[1].quantity, 500);
      expect(result!.variants[1].price, 3800000);
      expect(result!.variants[1].availablePackages, 2);
      expect(result!.variants[0].displayLabel, '۲۵۰ گرم');
      expect(result!.variants[1].displayLabel, '۵۰۰ گرم');
      expect(result!.variants.map((v) => v.sku).toSet().length, 2);
      expect(tester.takeException(), isNull);
    });
  }
  test('package command keeps stored cost and precise rial amounts', () {
    final draft = ProductPackageDraft(
      original: const ProductVariant(
        sku: 'CK-250',
        quantity: 250,
        displayLabel: '۲۵۰ گرم',
        price: 2000000.01,
        availablePackages: 3,
        costPrice: 750000,
        packagingCost: 1200,
      ),
    );
    final command = draft.command(
      'Weight',
      generatedSku: 'unused',
      canWriteCosts: false,
    );
    expect(command.price, 2000000.01);
    expect(command.costPrice, 750000);
    expect(command.packagingCost, 1200);
    expect(command.availablePackages, 3);
    draft.dispose();
  });
  testWidgets(
    'existing product accepts another package without changing its old stock',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      OwnerSession.instance.establish(
        accessToken: 'test',
        email: 'owner@test.local',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      final product = Product.fromJson({
        'id': 'p1',
        'slug': 'protein-cookie',
        'title': 'کوکی',
        'category': 'سالم',
        'origin': 'مزه‌دونه',
        'unitType': 'Weight',
        'variants': [
          {
            'sku': 'CK-250',
            'quantity': 250,
            'displayLabel': '۲۵۰ گرم',
            'price': 2000000,
            'availablePackages': 3,
            'costPrice': 750000,
          },
        ],
      });
      UpdateProductCommand? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAdminTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<UpdateProductCommand>(
                    context: context,
                    builder: (_) => ProductEditDialog(
                      product: product,
                      categories: const [],
                    ),
                  );
                },
                child: const Text('بازکردن'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('بازکردن'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('افزودن وزن یا تعداد دیگر'));
      await tester.tap(find.text('افزودن وزن یا تعداد دیگر'));
      await tester.pumpAndSettle();
      await fill(tester, 'package-1-quantity', '500');
      await fill(tester, 'package-1-price', '380000');
      await tester.tap(find.text('ذخیره تغییرات'));
      await tester.pumpAndSettle();
      expect(result!.variants.length, 2);
      expect(result!.variants.first.availablePackages, 3);
      expect(result!.variants.first.costPrice, 750000);
      expect(result!.variants.last.price, 3800000);
      expect(result!.variants.last.availablePackages, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
