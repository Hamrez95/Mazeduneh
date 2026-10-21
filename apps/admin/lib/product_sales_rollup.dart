import 'order_api.dart';

/// Sums the variant-level report rows into product totals without discarding
/// the variant breakdown used to explain those totals.
List<ProductSalesRollup> rollUpProductSales(
  Iterable<AdminProductProfitability> rows,
) {
  final groups = <String, _MutableProductSalesRollup>{};
  for (final row in rows) {
    final title = row.productTitle.trim();
    final unit = _normalizedUnit(row.baseUnit);
    final key = '${title.toLowerCase()}\u0000$unit';
    final group = groups.putIfAbsent(
      key,
      () => _MutableProductSalesRollup(title: title, baseUnit: unit),
    );
    group.packagesSold += row.unitsSold;
    group.revenue += row.revenue;
    group.discount += row.discount;
    group.cost += row.cost;
    group.grossProfit += row.grossProfit;
    if (row.quantitySold == null) {
      group.hasMissingQuantity = true;
    } else {
      group.quantitySold += row.quantitySold!;
    }
    group.variants.add(ProductSalesVariantRollup(
      label: row.variantLabel,
      sku: row.sku,
      packagesSold: row.unitsSold,
      quantitySold: row.quantitySold,
      revenue: row.revenue,
    ));
  }

  final result = groups.values.map((group) => group.freeze()).toList()
    ..sort((a, b) {
      final byProfit = b.grossProfit.compareTo(a.grossProfit);
      return byProfit != 0 ? byProfit : a.productTitle.compareTo(b.productTitle);
    });
  return result;
}

String _normalizedUnit(String? unit) => switch (unit?.trim().toLowerCase()) {
  'gram' || 'g' => 'gram',
  'count' || 'piece' || 'unit' || 'each' => 'count',
  _ => 'unknown',
};

class ProductSalesRollup {
  const ProductSalesRollup({
    required this.productTitle,
    required this.baseUnit,
    required this.packagesSold,
    required this.quantitySold,
    required this.hasMissingQuantity,
    required this.revenue,
    required this.discount,
    required this.cost,
    required this.grossProfit,
    required this.variants,
  });

  final String productTitle;
  final String baseUnit;
  final int packagesSold;
  final num quantitySold;
  final bool hasMissingQuantity;
  final num revenue;
  final num discount;
  final num cost;
  final num grossProfit;
  final List<ProductSalesVariantRollup> variants;
}

class ProductSalesVariantRollup {
  const ProductSalesVariantRollup({
    required this.label,
    required this.sku,
    required this.packagesSold,
    required this.quantitySold,
    required this.revenue,
  });

  final String label;
  final String sku;
  final int packagesSold;
  final num? quantitySold;
  final num revenue;
}

class _MutableProductSalesRollup {
  _MutableProductSalesRollup({required this.title, required this.baseUnit});

  final String title;
  final String baseUnit;
  int packagesSold = 0;
  num quantitySold = 0;
  bool hasMissingQuantity = false;
  num revenue = 0;
  num discount = 0;
  num cost = 0;
  num grossProfit = 0;
  final List<ProductSalesVariantRollup> variants = [];

  ProductSalesRollup freeze() => ProductSalesRollup(
    productTitle: title,
    baseUnit: baseUnit,
    packagesSold: packagesSold,
    quantitySold: quantitySold,
    hasMissingQuantity: hasMissingQuantity,
    revenue: revenue,
    discount: discount,
    cost: cost,
    grossProfit: grossProfit,
    variants: List.unmodifiable(variants
      ..sort((a, b) => a.label.compareTo(b.label))),
  );
}
