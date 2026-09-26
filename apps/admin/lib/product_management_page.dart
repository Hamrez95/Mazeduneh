import 'package:flutter/material.dart';

import 'catalog_api.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({
    super.key,
    required this.products,
    required this.api,
    required this.onReload,
  });

  final List<Product> products;
  final CatalogApiClient api;
  final Future<void> Function() onReload;

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  String? changingSlug;

  Future<void> _togglePublication(Product product) async {
    final publish = !product.isPublished;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(publish ? 'انتشار محصول؟' : 'خروج محصول از فروش؟'),
        content: Text(
          publish
              ? '«${product.title}» در سایت عمومی قابل سفارش خواهد شد.'
              : 'محصول حذف نمی‌شود و فقط از فروشگاه عمومی خارج خواهد شد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(publish ? 'انتشار' : 'خروج از فروش'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => changingSlug = product.slug);
    try {
      await widget.api.setPublication(product.slug, publish);
      await widget.onReload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publish ? 'محصول منتشر شد.' : 'محصول از فروشگاه خارج شد.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => changingSlug = null);
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateProductDialog(api: widget.api),
    );
    if (created != true) return;
    await widget.onReload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('محصول به‌صورت پیش‌نویس ثبت شد.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'کاتالوگ و موجودی',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'محصول وزنی یا عددی بساز، بسته‌ها را تعریف کن و بعد از بازبینی منتشر کن.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('محصول جدید'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: widget.products.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('ثبت اولین محصول'),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1100
                        ? 3
                        : constraints.maxWidth >= 680
                            ? 2
                            : 1;
                    return GridView.builder(
                      itemCount: widget.products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 286,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (_, index) {
                        final product = widget.products[index];
                        final changing = changingSlug == product.slug;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.title,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(product.isPublished ? 'منتشرشده' : 'پیش‌نویس'),
                                      backgroundColor: product.isPublished
                                          ? const Color(0xFFE7F1E2)
                                          : const Color(0xFFFFE8C8),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${product.category} · ${product.origin}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      product.isWeight ? Icons.scale_rounded : Icons.cookie_rounded,
                                      size: 18,
                                      color: const Color(0xFF3F6B45),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(product.isWeight ? 'واحد پایه: گرم' : 'واحد پایه: عدد'),
                                    const Spacer(),
                                    Text(
                                      '${product.totalStock} بسته',
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final variant in product.variants)
                                          Tooltip(
                                            message: '${variant.sku} · ${_formatToman(variant.price)} تومان',
                                            child: Chip(
                                              label: Text(
                                                '${variant.displayLabel} · ${variant.availablePackages}',
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.isPublished
                                            ? 'قابل نمایش و سفارش در سایت'
                                            : 'فقط در پنل مدیریت دیده می‌شود',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                    if (changing)
                                      const SizedBox.square(
                                        dimension: 24,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else
                                      OutlinedButton(
                                        onPressed: () => _togglePublication(product),
                                        child: Text(product.isPublished ? 'خروج از فروش' : 'انتشار'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CreateProductDialog extends StatefulWidget {
  const _CreateProductDialog({required this.api});

  final CatalogApiClient api;

  @override
  State<_CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<_CreateProductDialog> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final slug = TextEditingController();
  final category = TextEditingController(text: 'پسته و مغزیجات');
  final origin = TextEditingController();

  String unitType = 'Weight';
  bool submitting = false;
  String? errorMessage;
  late List<_VariantDraft> variants = _weightVariants();

  @override
  void dispose() {
    title.dispose();
    slug.dispose();
    category.dispose();
    origin.dispose();
    for (final variant in variants) {
      variant.dispose();
    }
    super.dispose();
  }

  void _changeUnit(String value) {
    for (final variant in variants) {
      variant.dispose();
    }
    setState(() {
      unitType = value;
      variants = value == 'Weight' ? _weightVariants() : _countVariants();
    });
  }

  void _addVariant() {
    setState(() {
      variants.add(
        _VariantDraft(
          quantity: unitType == 'Weight' ? '' : '1',
          label: unitType == 'Weight' ? '' : '۱ عدد',
        ),
      );
    });
  }

  void _removeVariant(int index) {
    if (variants.length <= 1) return;
    final removed = variants.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      submitting = true;
      errorMessage = null;
    });

    try {
      final command = CreateProductCommand(
        title: title.text.trim(),
        slug: slug.text.trim().toLowerCase(),
        category: category.text.trim(),
        origin: origin.text.trim(),
        unitType: unitType,
        isPublished: false,
        variants: variants
            .map(
              (variant) => CreateVariantCommand(
                sku: variant.sku.text.trim().toUpperCase(),
                quantity: num.parse(variant.quantity.text.trim()),
                displayLabel: variant.label.text.trim(),
                price: int.parse(variant.priceToman.text.trim()) * 10,
                availablePackages: int.parse(variant.stock.text.trim()),
              ),
            )
            .toList(),
      );
      await widget.api.createProduct(command);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('محصول جدید'),
          leading: IconButton(
            onPressed: submitting ? null : () => Navigator.pop(context, false),
            icon: const Icon(Icons.close_rounded),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: FilledButton.icon(
                onPressed: submitting ? null : _submit,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('ذخیره پیش‌نویس'),
              ),
            ),
          ],
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SectionTitle(
                        title: 'مشخصات پایه',
                        subtitle: 'محصول بعد از ثبت پیش‌نویس می‌ماند تا پیش از انتشار بازبینی شود.',
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Input(width: 430, controller: title, label: 'نام محصول', validator: _required),
                          _Input(
                            width: 430,
                            controller: slug,
                            label: 'شناسه انگلیسی URL',
                            hint: 'pistachio-akbari',
                            validator: _slugValidator,
                            textDirection: TextDirection.ltr,
                          ),
                          _Input(width: 430, controller: category, label: 'دسته‌بندی', validator: _required),
                          _Input(width: 430, controller: origin, label: 'مبدأ یا برند', validator: _required),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const _SectionTitle(
                        title: 'نوع واحد فروش',
                        subtitle: 'مغزیجات معمولاً وزنی‌اند؛ کوکی و کیک می‌توانند عددی باشند.',
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Weight',
                            icon: Icon(Icons.scale_rounded),
                            label: Text('وزنی / گرم'),
                          ),
                          ButtonSegment(
                            value: 'Count',
                            icon: Icon(Icons.cookie_rounded),
                            label: Text('عددی / عدد'),
                          ),
                        ],
                        selected: {unitType},
                        onSelectionChanged: submitting
                            ? null
                            : (selection) => _changeUnit(selection.first),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                            child: _SectionTitle(
                              title: 'بسته‌های قابل فروش',
                              subtitle: 'هر بسته SKU، قیمت و موجودی مستقل دارد.',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: submitting ? null : _addVariant,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('بسته دیگر'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (final entry in variants.asMap().entries)
                        _VariantEditor(
                          index: entry.key,
                          draft: entry.value,
                          unitType: unitType,
                          canRemove: variants.length > 1,
                          onRemove: () => _removeVariant(entry.key),
                        ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFECE8),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Color(0xFF9A3E36)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VariantEditor extends StatelessWidget {
  const _VariantEditor({
    required this.index,
    required this.draft,
    required this.unitType,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final _VariantDraft draft;
  final String unitType;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'بسته ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: canRemove ? onRemove : null,
                  tooltip: 'حذف بسته',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Input(
                  width: 170,
                  controller: draft.sku,
                  label: 'SKU',
                  hint: 'PI-AKB-250',
                  validator: _skuValidator,
                  textDirection: TextDirection.ltr,
                ),
                _Input(
                  width: 170,
                  controller: draft.label,
                  label: 'عنوان نمایشی',
                  hint: unitType == 'Weight' ? '۲۵۰ گرم' : 'پک ۴ عددی',
                  validator: _required,
                ),
                _Input(
                  width: 130,
                  controller: draft.quantity,
                  label: unitType == 'Weight' ? 'مقدار گرم' : 'تعداد داخل پک',
                  validator: _positiveNumber,
                  keyboardType: TextInputType.number,
                ),
                _Input(
                  width: 170,
                  controller: draft.priceToman,
                  label: 'قیمت فروش (تومان)',
                  validator: _nonNegativeInt,
                  keyboardType: TextInputType.number,
                ),
                _Input(
                  width: 145,
                  controller: draft.stock,
                  label: 'تعداد بسته موجود',
                  validator: _nonNegativeInt,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.width,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.textDirection,
  });

  final double width;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textDirection: textDirection,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _VariantDraft {
  _VariantDraft({
    String sku = '',
    String quantity = '',
    String label = '',
    String priceToman = '0',
    String stock = '0',
  })  : sku = TextEditingController(text: sku),
        quantity = TextEditingController(text: quantity),
        label = TextEditingController(text: label),
        priceToman = TextEditingController(text: priceToman),
        stock = TextEditingController(text: stock);

  final TextEditingController sku;
  final TextEditingController quantity;
  final TextEditingController label;
  final TextEditingController priceToman;
  final TextEditingController stock;

  void dispose() {
    sku.dispose();
    quantity.dispose();
    label.dispose();
    priceToman.dispose();
    stock.dispose();
  }
}

List<_VariantDraft> _weightVariants() => [
      _VariantDraft(quantity: '250', label: '۲۵۰ گرم'),
      _VariantDraft(quantity: '500', label: '۵۰۰ گرم'),
      _VariantDraft(quantity: '1000', label: '۱۰۰۰ گرم'),
    ];

List<_VariantDraft> _countVariants() => [
      _VariantDraft(quantity: '1', label: '۱ عدد'),
      _VariantDraft(quantity: '4', label: 'پک ۴ عددی'),
    ];

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) return 'این فیلد الزامی است.';
  return null;
}

String? _positiveNumber(String? value) {
  final number = num.tryParse(value ?? '');
  if (number == null || number <= 0) return 'عدد مثبت وارد کنید.';
  return null;
}

String? _nonNegativeInt(String? value) {
  final number = int.tryParse(value ?? '');
  if (number == null || number < 0) return 'عدد صحیح صفر یا بیشتر وارد کنید.';
  return null;
}

String? _slugValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'شناسه URL الزامی است.';
  if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value.trim())) {
    return 'فقط حروف انگلیسی کوچک، عدد و خط تیره.';
  }
  return null;
}

String? _skuValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'SKU الزامی است.';
  if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(value.trim())) {
    return 'فقط حروف انگلیسی، عدد و خط تیره.';
  }
  return null;
}

String _formatToman(num irr) {
  return '${(irr / 10).round()}'.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '٬',
  );
}
