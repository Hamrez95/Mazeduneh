import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/order_api.dart';
import 'package:mazeduneh_admin/product_sales_rollup.dart';

AdminProductProfitability _variant({
  required String title,
  required String sku,
  required String label,
  required int packs,
  required num revenue,
  required num? quantity,
  String? unit = 'gram',
  num discount = 0,
}) => AdminProductProfitability(
  productTitle: title,
  sku: sku,
  variantLabel: label,
  unitsSold: packs,
  revenue: revenue,
  cost: revenue / 2,
  grossProfit: revenue / 2 - discount,
  discount: discount,
  quantitySold: quantity,
  baseUnit: unit,
);

void main() {
  test('combines package variants into exact product totals and retains mix', () {
    final rows = rollUpProductSales([
      _variant(
        title: 'کوکی پروتئینی',
        sku: 'KOO-250',
        label: '250g',
        packs: 8,
        revenue: 16000000,
        quantity: 2000,
        discount: 1000000,
      ),
      _variant(
        title: 'کوکی پروتئینی',
        sku: 'KOO-500',
        label: '500g',
        packs: 3,
        revenue: 11400000,
        quantity: 1500,
        discount: 500000,
      ),
    ]);

    expect(rows, hasLength(1));
    final total = rows.single;
    expect(total.packagesSold, 11);
    expect(total.quantitySold, 3500);
    expect(total.hasMissingQuantity, isFalse);
    expect(total.revenue, 27400000);
    expect(total.discount, 1500000);
    expect(total.variants.map((variant) => variant.sku), ['KOO-250', 'KOO-500']);
  });

  test('keeps units separate and marks legacy missing quantities', () {
    final rows = rollUpProductSales([
      _variant(
        title: 'محصول چندواحدی',
        sku: 'MIX-250',
        label: '250g',
        packs: 2,
        revenue: 2000,
        quantity: 500,
      ),
      _variant(
        title: 'محصول چندواحدی',
        sku: 'MIX-OLD',
        label: 'وزن قدیمی',
        packs: 1,
        revenue: 1000,
        quantity: null,
      ),
      _variant(
        title: 'محصول چندواحدی',
        sku: 'MIX-COUNT',
        label: 'یک عدد',
        packs: 4,
        revenue: 4000,
        quantity: 4,
        unit: 'count',
      ),
    ]);

    expect(rows, hasLength(2));
    final gram = rows.singleWhere((row) => row.baseUnit == 'gram');
    expect(gram.packagesSold, 3);
    expect(gram.quantitySold, 500);
    expect(gram.hasMissingQuantity, isTrue);
    final count = rows.singleWhere((row) => row.baseUnit == 'count');
    expect(count.packagesSold, 4);
    expect(count.quantitySold, 4);
    expect(count.hasMissingQuantity, isFalse);
  });
}
