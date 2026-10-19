import 'product_package_editor.dart';
import 'auth_session.dart';
import 'admin_permissions.dart';
import 'admin_form_guard.dart';
import 'admin_form_drafts.dart';
import 'package:flutter/material.dart';

import 'admin_theme.dart';
import 'catalog_api.dart';

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
  late final List<ProductPackageDraft> _variants;
  final _removed = <ProductPackageDraft>[];
  bool _dirty = false;
  bool _closing = false;
  bool _restoredDraft = false;
  bool get _canPrice =>
      OwnerSession.instance.can(AdminPermissions.pricingWrite);

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
    _variants = product.variants
        .map((v) => ProductPackageDraft(original: v))
        .toList();
    final draft = readAdminFormDraft('product-edit', product.slug);
    if (draft != null) {
      _restoredDraft = true;
      _dirty = true;
      for (final entry in <String, TextEditingController>{
        'title': _title,
        'origin': _origin,
        'shortDescription': _shortDescription,
        'description': _description,
        'seoTitle': _seoTitle,
        'seoDescription': _seoDescription,
        'seoKeywords': _seoKeywords,
        'specifications': _specifications,
      }.entries) {
        if (draft[entry.key] is String) entry.value.text = draft[entry.key] as String;
      }
      if (draft['category'] is String) _category = draft['category'] as String;
      final savedVariants = draft['variants'];
      if (savedVariants is List) {
        for (var i = 0; i < _variants.length && i < savedVariants.length; i++) {
          final value = savedVariants[i];
          if (value is! Map) continue;
          final variant = _variants[i];
          for (final entry in <String, TextEditingController>{
            'sku': variant.sku,
            'quantity': variant.quantity,
            'label': variant.label,
            'price': variant.price,
            'cost': variant.cost,
            'stock': variant.stock,
          }.entries) {
            if (value[entry.key] is String) entry.value.text = value[entry.key] as String;
          }
          if (value['quantityUnit'] == 'kilogram' || value['quantityUnit'] == 'gram') {
            variant.quantityUnit = value['quantityUnit'] as String;
          }
        }
      }
    }
    for (final controller in [_title, _origin, _shortDescription, _description, _seoTitle, _seoDescription, _seoKeywords, _specifications, _primaryImage, _galleryImages]) {
      controller.addListener(_markDirty);
    }
  }

  void _persistDraft() => writeAdminFormDraft('product-edit', widget.product.slug, {
    'title': _title.text,
    'origin': _origin.text,
    'shortDescription': _shortDescription.text,
    'description': _description.text,
    'seoTitle': _seoTitle.text,
    'seoDescription': _seoDescription.text,
    'seoKeywords': _seoKeywords.text,
    'specifications': _specifications.text,
    'category': _category,
    'variants': [for (final item in _variants) {
      'sku': item.sku.text,
      'quantity': item.quantity.text,
      'label': item.label.text,
      'price': item.price.text,
      'cost': item.cost.text,
      'stock': item.stock.text,
      'quantityUnit': item.quantityUnit,
    }],
  });

  void _markDirty() {
    if (!mounted || _closing) return;
    if (!_dirty) setState(() => _dirty = true);
    _persistDraft();
  }

  Future<void> _requestClose() async {
    if (_dirty && !await confirmDiscardAdminChanges(context)) return;
    if (!mounted) return;
    clearAdminFormDraft('product-edit', widget.product.slug);
    setState(() => _closing = true);
    Navigator.pop(context);
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
    for (final variant in [..._variants, ..._removed]) {
      variant.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_dirty || _closing,
    onPopInvokedWithResult: (didPop, _) { if (!didPop) _requestClose(); },
    child: AlertDialog(
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
                if (_restoredDraft)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.restore_rounded),
                      title: Text('پیش‌نویس قبلی بازیابی شد.'),
                      subtitle: Text('متن و مقادیر فرم تا ۷ روز روی همین مرورگر نگه‌داری می‌شوند؛ اطلاعات مشتری و پیوند تصاویر ذخیره نمی‌شود.'),
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
                  isExpanded: true,
                  value: _category,
                  decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                  items: _availableCategories
                      .map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) { setState(() => _category = value); _markDirty(); }
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
                  'وزن، کد و موجودی بسته‌های قبلی برای حفظ سوابق ثابت‌اند. می‌توانید قیمت را اصلاح کنید یا بستهٔ جدید اضافه کنید؛ همه در همان صفحهٔ محصول نمایش داده می‌شوند.',
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _variants.length; i++)
                  ProductPackageEditor(
                    key: ObjectKey(_variants[i]),
                    draft: _variants[i],
                    index: i,
                    unitType: widget.product.unitType,
                    canWriteCosts: _canPrice,
                    canChangePrice: _canPrice,
                    allDrafts: _variants,
                    onChanged: _markDirty,
                    onRemove: _variants[i].original != null
                        ? null
                        : () => setState(() { _removed.add(_variants.removeAt(i)); _dirty = true; _persistDraft(); }),
                  ),
                if (_canPrice)
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() { _variants.add(ProductPackageDraft()); _dirty = true; _persistDraft(); }),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('افزودن وزن یا تعداد دیگر'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _requestClose,
        child: const Text('انصراف'),
      ),
      FilledButton(onPressed: _save, child: const Text('ذخیره تغییرات')),
    ],
  ));

  List<String> get _availableCategories => {
    ...widget.categories.map((category) => category.name),
    widget.product.category,
  }.toList();

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'این فیلد الزامی است.' : null;

  void _save() {
    if (_formKey.currentState?.validate() != true) return;
    final codes = [
      for (var i = 0; i < _variants.length; i++)
        _variants[i].sku.text.trim().isEmpty
            ? generatedPackageSku(widget.product.slug, _variants[i], i)
            : _variants[i].sku.text.trim().toUpperCase(),
    ];
    if (codes.toSet().length != codes.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد انبار بسته‌ها نباید تکراری باشد.')),
      );
      return;
    }
    _closing = true;
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
          for (var i = 0; i < _variants.length; i++)
            _variants[i].command(
              widget.product.unitType,
              generatedSku: generatedPackageSku(
                widget.product.slug,
                _variants[i],
                i,
              ),
              canWriteCosts: _canPrice,
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

