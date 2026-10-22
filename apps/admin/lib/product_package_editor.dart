import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'catalog_api.dart';
import 'formatters.dart';

/// One sellable package of a product. Monetary inputs are toman; API uses rial.
class ProductPackageDraft {
  ProductPackageDraft({this.original}) {
    final v = original;
    if (v != null) {
      sku.text = v.sku;
      quantity.text = toPersianDigits(v.quantity);
      label.text = v.displayLabel;
      price.text = _toman(v.price);
      cost.text = _toman(v.costPrice);
      stock.text = formatPersianInteger(v.availablePackages);
    }
  }
  final ProductVariant? original;
  /// Weight entered by the operator is converted to the catalog's canonical grams.
  String quantityUnit = 'gram';
  final sku = TextEditingController(),
      quantity = TextEditingController(),
      label = TextEditingController();
  final price = TextEditingController(),
      cost = TextEditingController(),
      stock = TextEditingController(text: '۰');
  static String _toman(num rial) => formatTomanInput(rial);
  String displayLabel(String unitType) => label.text.trim().isNotEmpty
      ? label.text.trim()
      : '${formatPersianNumber(parsePersianNumber(quantity.text) ?? 0, fractionDigits: (parsePersianNumber(quantity.text) ?? 0) % 1 == 0 ? 0 : 2)} ${unitType == 'Weight' ? (quantityUnit == 'kilogram' ? 'کیلوگرم' : 'گرم') : 'عدد'}';
  num canonicalQuantity(String unitType) {
    final value = parsePersianNumber(quantity.text)!;
    return unitType == 'Weight' && quantityUnit == 'kilogram' ? value * 1000 : value;
  }
  void changeWeightUnit(String nextUnit) {
    if (nextUnit == quantityUnit) return;
    final entered = parsePersianNumber(quantity.text);
    if (entered != null) {
      final canonicalGrams = quantityUnit == 'kilogram' ? entered * 1000 : entered;
      final converted = nextUnit == 'kilogram' ? canonicalGrams / 1000 : canonicalGrams;
      quantity.text = toPersianDigits(converted);
    }
    quantityUnit = nextUnit;
  }
  CreateVariantCommand command(
    String unitType, {
    required String generatedSku,
    required bool canWriteCosts,
  }) => CreateVariantCommand(
    sku: sku.text.trim().isEmpty ? generatedSku : sku.text.trim().toUpperCase(),
    quantity: canonicalQuantity(unitType),
    displayLabel: displayLabel(unitType),
    price: num.parse((parsePersianNumber(price.text)! * 10).toStringAsFixed(2)),
    availablePackages:
        original?.availablePackages ?? parsePersianInteger(stock.text)!,
    costPrice:
        original?.costPrice ??
        (canWriteCosts
            ? num.parse(
                ((parsePersianNumber(cost.text) ?? 0) * 10).toStringAsFixed(2),
              )
            : 0),
    packagingCost: original?.packagingCost ?? 0,
    additionalCost: original?.additionalCost ?? 0,
  );
  void dispose() {
    for (final c in [sku, quantity, label, price, cost, stock]) {
      c.dispose();
    }
  }
}

String generatedPackageSku(String slug, ProductPackageDraft draft, int index) {
  final prefix = slug
      .trim()
      .toUpperCase()
      .replaceAll(RegExp('[^A-Z0-9-]'), '-')
      .replaceAll(RegExp('-+'), '-');
  final entered = parsePersianNumber(draft.quantity.text);
  final canonical = entered == null
      ? null
      : draft.quantityUnit == 'kilogram' ? entered * 1000 : entered;
  final amount = canonical == null
      ? ''
      : normalizeNumberDigits(canonical.toString()).replaceAll(RegExp('[^0-9]'), '');
  return '${prefix.isEmpty ? 'PRODUCT' : prefix}-${amount.isEmpty ? 'PACK' : amount}-${index + 1}';
}

class ProductPackageEditor extends StatelessWidget {
  const ProductPackageEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.unitType,
    required this.canWriteCosts,
    required this.allDrafts,
    this.onRemove,
    this.onChanged,
    this.canChangePrice = true,
  });
  final ProductPackageDraft draft;
  final int index;
  final String unitType;
  final bool canWriteCosts, canChangePrice;
  final List<ProductPackageDraft> allDrafts;
  final VoidCallback? onRemove, onChanged;
  String? _money(String? value) {
    final n = parsePersianNumber(value);
    return n == null || !n.isFinite || n < 0
        ? 'مبلغ صفر یا بیشتر وارد کنید.'
        : null;
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AdminColors.canvas,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AdminColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'بستهٔ ${formatPersianInteger(index + 1)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AdminColors.heading,
                ),
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: 'حذف بستهٔ ${formatPersianInteger(index + 1)}',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth >= 600
                ? (box.maxWidth - 12) / 2
                : box.maxWidth;
            Widget field(
              String id,
              TextEditingController c,
              String title, {
              String? helper,
              String? Function(String?)? validator,
              bool enabled = true,
              bool money = false,
              bool numeric = false,
            }) => SizedBox(
              width: width,
              child: TextFormField(
                key: ValueKey('package-$index-$id'),
                controller: c,
                enabled: enabled,
                onChanged: (_) => onChanged?.call(),
                keyboardType: numeric || money
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : TextInputType.text,
                inputFormatters: money
                    ? const [PersianGroupedIntegerInputFormatter()]
                    : numeric
                    ? const [PersianDigitsInputFormatter()]
                    : null,
                textDirection: id == 'sku' ? TextDirection.ltr : null,
                decoration: InputDecoration(
                  labelText: title,
                  helperText: helper,
                  helperMaxLines: 3,
                  suffixIcon: id == 'cost'
                      ? const Tooltip(
                          message: 'مجموع هزینهٔ خرید و تولید هر بسته را به تومان وارد کنید؛ این مقدار مبنای محاسبهٔ سود گزارش‌هاست.',
                          child: Icon(Icons.info_outline_rounded),
                        )
                      : id == 'price'
                      ? const Tooltip(
                          message: 'قیمت فروش هر بسته به تومان است. API و گزارش‌های مالی مبلغ را به ریال نگه می‌دارند.',
                          child: Icon(Icons.info_outline_rounded),
                        )
                      : null,
                ),
                validator: validator,
              ),
            );
            return Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                field(
                  'quantity',
                  draft.quantity,
                  unitType == 'Weight' ? 'وزن هر بسته' : 'تعداد هر بسته',
                  helper: unitType == 'Weight'
                      ? 'مقدار در انبار به گرم تبدیل می‌شود.'
                      : null,
                  enabled: draft.original == null,
                  numeric: true,
                  validator: (v) {
                    final n = parsePersianNumber(v);
                    return n == null ||
                            !n.isFinite ||
                            n <= 0 ||
                            unitType == 'Count' && n % 1 != 0
                        ? 'مقدار مثبت${unitType == 'Count' ? ' و صحیح' : ''} وارد کنید.'
                        : null;
                  },
                ),
                if (unitType == 'Weight')
                  SizedBox(
                    width: width,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'package-$index-unit-${draft.quantityUnit}',
                      ),
                      initialValue: draft.quantityUnit,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'واحد'),
                      items: const [
                        DropdownMenuItem(value: 'gram', child: Text('گرم')),
                        DropdownMenuItem(
                          value: 'kilogram',
                          child: Text('کیلوگرم'),
                        ),
                      ],
                      onChanged: draft.original != null
                          ? null
                          : (value) {
                              if (value == null) return;
                              draft.changeWeightUnit(value);
                              onChanged?.call();
                            },
                    ),
                  ),
                field(
                  'label',
                  draft.label,
                  'عنوان بسته (اختیاری)',
                  helper:
                      'مثلاً ۲۵۰ گرم یا جعبهٔ ۶ عددی؛ در صورت خالی بودن از مقدار بسته ساخته می‌شود.',
                  enabled: draft.original == null,
                ),
                field(
                  'price',
                  draft.price,
                  'قیمت فروش (تومان)',
                  money: true,
                  enabled: canChangePrice,
                  validator: _money,
                ),
                field(
                  'stock',
                  draft.stock,
                  'تعداد بستهٔ موجود',
                  numeric: true,
                  enabled: draft.original == null,
                  helper: draft.original == null
                      ? 'موجودی این اندازه، مستقل از بسته‌های دیگر است.'
                      : 'موجودی بستهٔ قبلی از بخش انبار اصلاح می‌شود.',
                  validator: (v) =>
                      parsePersianInteger(v, min: 0, max: maxApiInteger) == null
                      ? 'تعداد صحیح صفر یا بیشتر وارد کنید.'
                      : null,
                ),
                if (canWriteCosts && draft.original == null)
                  field(
                    'cost',
                    draft.cost,
                    'قیمت تمام‌شده (تومان)',
                    money: true,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? null : _money(v),
                  ),
                field(
                  'sku',
                  draft.sku,
                  'کد انبار (SKU؛ اختیاری)',
                  enabled: draft.original == null,
                  helper: draft.original == null
                      ? 'خالی بگذارید تا خودکار ساخته شود. هر بسته کد مستقل دارد.'
                      : 'کد بستهٔ قبلی برای حفظ سوابق ثابت است.',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return allDrafts
                                .where(
                                  (d) =>
                                      d.sku.text.trim().toUpperCase() ==
                                      v.trim().toUpperCase(),
                                )
                                .length >
                            1
                        ? 'کد انبار این بسته تکراری است.'
                        : null;
                  },
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

