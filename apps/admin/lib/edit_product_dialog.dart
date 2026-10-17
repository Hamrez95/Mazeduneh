import 'package:flutter/material.dart';

import 'admin_theme.dart';
import 'catalog_api.dart';
import 'formatters.dart';

class ProductEditDialog extends StatefulWidget {
  const ProductEditDialog({
    super.key,
    required this.product,
    required this.categories,
  });

  final Product product;
  final List<Category> categories;

  @override
  State<ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _origin = TextEditingController();
  final _shortDescription = TextEditingController();
  final _description = TextEditingController();
  final _seoTitle = TextEditingController();
  final _seoDescription = TextEditingController();
  final _seoKeywords = TextEditingController();
  final _specifications = TextEditingController();
  final _primaryImage = TextEditingController();
  final _galleryImages = TextEditingController();
  late String _category;
  late final List<_VariantDraft> _variants;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _title.text = product.title;
    _origin.text = product.origin;
    _shortDescription.text = product.shortDescription;
    _description.text = product.description;
    _seoTitle.text = product.seoTitle;
    _seoDescription.text = product.seoDescription;
    _seoKeywords.text = product.seoKeywords;
    _specifications.text = product.specifications.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('\n');
    _primaryImage.text = product.primaryImage;
    _galleryImages.text = product.galleryImages.join('\n');
    _category = product.category;
    _variants = product.variants.map(_VariantDraft.new).toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _origin.dispose();
    _shortDescription.dispose();
    _description.dispose();
    _seoTitle.dispose();
    _seoDescription.dispose();
    _seoKeywords.dispose();
    _specifications.dispose();
    _primaryImage.dispose();
    _galleryImages.dispose();
    for (final variant in _variants) {
      variant.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ویرایش محصول'),
    content: SizedBox(
      width: MediaQuery.sizeOf(context).width < 920
          ? MediaQuery.sizeOf(context).width - 48
          : 820,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.product.isPublished
                      ? 'این محصول منتشر شده است؛ ویرایش، وضعیت انتشار را تغییر نمی‌دهد.'
                      : 'پیش‌نویس را ویرایش کنید و بعداً جداگانه منتشر کنید.',
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const ValueKey('edit-product-title'),
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'نام محصول'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: widget.product.slug,
                  enabled: false,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'شناسهٔ آدرس (ثابت)',
                    helperText:
                        'برای حفظ پیوندهای فروشگاه، شناسهٔ آدرس تغییر نمی‌کند.',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                  items: _availableCategories
                      .map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _origin,
                  decoration: const InputDecoration(labelText: 'مبدأ یا برند'),
                  validator: _required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _shortDescription,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'توضیح کوتاه'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'توضیحات کامل'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _primaryImage,
                  keyboardType: TextInputType.url,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'پیوند تصویر اصلی',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _galleryImages,
                  minLines: 2,
                  maxLines: 4,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'پیوند تصاویر گالری',
                    helperText: 'هر پیوند را در یک خط وارد کنید.',
                  ),
                ),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('اطلاعات SEO و مشخصات'),
                  children: [
                    TextFormField(
                      controller: _seoTitle,
                      decoration: const InputDecoration(labelText: 'عنوان SEO'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _seoDescription,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'توضیح SEO'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _seoKeywords,
                      decoration: const InputDecoration(
                        labelText: 'کلمات کلیدی',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _specifications,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'مشخصات ساختاریافته',
                        helperText: 'هر خط را به شکل «کلید=مقدار» بنویسید.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'موجودی و مشخصات بسته‌ها در این فرم تغییر نمی‌کند؛ برای اصلاح موجودی از بخش انبار استفاده کنید.',
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                for (final variant in _variants) _variantFields(variant),
              ],
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(onPressed: _save, child: const Text('ذخیره تغییرات')),
    ],
  );

  List<String> get _availableCategories => {
    ...widget.categories.map((category) => category.name),
    widget.product.category,
  }.toList();

  Widget _variantFields(_VariantDraft variant) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('بسته و قیمت', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              SizedBox(width: 200, child: TextFormField(controller: variant.sku, enabled: false, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'کد انبار (SKU)', helperText: 'برای حفظ سوابق انبار ثابت می‌ماند.'))),
              SizedBox(width: 180, child: TextFormField(controller: variant.label, decoration: const InputDecoration(labelText: 'عنوان بسته'), validator: _required)),
              SizedBox(width: 150, child: TextFormField(controller: variant.quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: const [PersianDigitsInputFormatter()], decoration: InputDecoration(labelText: widget.product.unitType == 'Weight' ? 'وزن (گرم)' : 'تعداد'), validator: (value) { final number = parsePersianNumber(value); return number == null || !number.isFinite || number <= 0 || widget.product.unitType == 'Count' && number != number.roundToDouble() ? 'مقدار معتبر وارد کنید.' : null; })),
              SizedBox(width: 190, child: TextFormField(controller: variant.price, keyboardType: TextInputType.number, inputFormatters: const [PersianGroupedIntegerInputFormatter()], decoration: const InputDecoration(labelText: 'قیمت فروش (ریال)'), validator: (value) => parsePersianInteger(value, min: 0) == null ? 'قیمت معتبر وارد کنید.' : null)),
              SizedBox(width: 150, child: TextFormField(controller: variant.stock, keyboardType: TextInputType.number, inputFormatters: const [PersianGroupedIntegerInputFormatter()], decoration: const InputDecoration(labelText: 'موجودی (بسته)'), validator: (value) => parsePersianInteger(value, min: 0, max: maxApiInteger) == null ? 'موجودی معتبر وارد کنید.' : null)),
            ]),
          ],
        ),
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'این فیلد الزامی است.' : null;

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(
      context,
      UpdateProductCommand(
        title: _title.text.trim(),
        category: _category,
        origin: _origin.text.trim(),
        currency: 'IRR',
        unitType: widget.product.unitType,
        shortDescription: _shortDescription.text.trim(),
        description: _description.text.trim(),
        seoTitle: _seoTitle.text.trim(),
        seoDescription: _seoDescription.text.trim(),
        seoKeywords: _seoKeywords.text.trim(),
        primaryImage: _primaryImage.text.trim(),
        galleryImages: _galleryImages.text
            .split('\n')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        specifications: _parseSpecifications(_specifications.text),
        ingredients: widget.product.ingredients,
        allergens: widget.product.allergens,
        nutritionFacts: widget.product.nutritionFacts,
        storageInstructions: widget.product.storageInstructions,
        shelfLifeDays: widget.product.shelfLifeDays,
        netWeight: widget.product.netWeight,
        netWeightUnit: widget.product.netWeightUnit,
        expiryLabel: widget.product.expiryLabel,
        variants: [
          for (final variant in _variants)
            CreateVariantCommand(
              sku: variant.sku.text.trim(),
              quantity: parsePersianNumber(variant.quantity.text)!,
              displayLabel: variant.label.text.trim(),
              price: parsePersianInteger(variant.price.text, min: 0)!,
              availablePackages: parsePersianInteger(variant.stock.text, min: 0, max: maxApiInteger)!,
              costPrice: variant.original.costPrice,
              packagingCost: variant.original.packagingCost,
              additionalCost: variant.original.additionalCost,
            ),
        ],
      ),
    );
  }

  Map<String, String> _parseSpecifications(String value) => {
    for (final line in value.split('\n'))
      if (line.contains('='))
        line.substring(0, line.indexOf('=')).trim(): line
            .substring(line.indexOf('=') + 1)
            .trim(),
  };
}

class _VariantDraft {
  _VariantDraft(this.original)
    : sku = TextEditingController(text: original.sku),
      label = TextEditingController(text: original.displayLabel),
      quantity = TextEditingController(text: toPersianDigits(original.quantity)),
      price = TextEditingController(text: formatPersianInteger(original.price)),
      stock = TextEditingController(text: formatPersianInteger(original.availablePackages));

  final ProductVariant original;
  final TextEditingController sku;
  final TextEditingController label;
  final TextEditingController quantity;
  final TextEditingController price;
  final TextEditingController stock;

  void dispose() {
    sku.dispose();
    label.dispose();
    quantity.dispose();
    price.dispose();
    stock.dispose();
  }
}
