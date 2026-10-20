import 'package:flutter/material.dart';
import 'catalog_api.dart';
import 'formatters.dart';
import 'localized_calendar.dart';
import 'order_api.dart';
import 'store_timezone.dart';

class InventoryReceiptCommand {
  const InventoryReceiptCommand({required this.sku, required this.batchCode, required this.receivedPackages,
    required this.producedAt, required this.expiresAt, required this.purchasedAt, required this.supplier,
    required this.supplierContactName, required this.supplierPhone, required this.supplierEmail,
    required this.supplierAddress, required this.supplierNotes, required this.costPrice, required this.packagingCost, required this.additionalCost,
    this.openingStock = false});
  final String sku, batchCode, supplier, supplierContactName, supplierPhone, supplierEmail, supplierAddress, supplierNotes;
  final int receivedPackages;
  final DateTime producedAt, expiresAt, purchasedAt;
  final num costPrice, packagingCost, additionalCost;
  final bool openingStock;
}

class BatchDialog extends StatefulWidget {
  const BatchDialog({super.key, required this.products, required this.onSave});
  final List<Product> products;
  final Future<InventoryBatch> Function(InventoryReceiptCommand) onSave;
  @override
  State<BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<BatchDialog> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in ['batch', 'quantity', 'supplier', 'supplierContactName', 'supplierPhone', 'supplierEmail', 'supplierAddress', 'supplierNotes', 'produced', 'expires', 'purchased', 'cost', 'packaging', 'additional'])
      key: TextEditingController(text: ['cost', 'packaging', 'additional'].contains(key) ? '۰' : ''),
  };
  late String sku;
  bool saving = false;
  bool openingStock = false;
  String? error;
  bool _purchaseDateInitialized = false;
  @override
  void initState() {
    super.initState();
    final firstVariant = widget.products.expand((p) => p.variants).first;
    sku = firstVariant.sku;
    _setVariantCostDefaults(firstVariant);
  }

  void _setVariantCostDefaults(ProductVariant variant) {
    fields['cost']!.text = formatToman(variant.costPrice);
    fields['packaging']!.text = formatToman(variant.packagingCost);
    fields['additional']!.text = formatToman(variant.additionalCost);
  }

  ProductVariant get selectedVariant => widget.products
      .expand((product) => product.variants)
      .firstWhere((variant) => variant.sku == sku);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_purchaseDateInitialized) return;
    _purchaseDateInitialized = true;
    fields['purchased']!.text = formatCalendarDate(storeWallTimeNow(), Localizations.localeOf(context));
  }

  DateTime? date(String? value) => parseCalendarDate(value, Localizations.localeOf(context));

  String dateLabel(String key, bool english) => switch ((key, english)) {
    ('purchased', true) => 'Purchase date',
    ('produced', true) => 'Production date',
    ('expires', true) => 'Expiration date',
    ('purchased', false) => 'تاریخ خرید',
    ('produced', false) => 'تاریخ تولید',
    _ => 'تاریخ انقضا',
  };

  Widget dateField(String key) {
    final locale = Localizations.localeOf(context);
    final english = locale.languageCode == 'en';
    final label = dateLabel(key, english);
    return TextFormField(
      controller: fields[key],
      keyboardType: TextInputType.datetime,
      inputFormatters: usesJalaliCalendar(locale) ? const [PersianDigitsInputFormatter()] : const [],
      decoration: InputDecoration(
        labelText: label,
        helperText: english ? 'Gregorian calendar · Month DD, YYYY' : 'تقویم شمسی · سال/ماه/روز',
        suffixIcon: IconButton(
          tooltip: english ? 'Choose $label' : 'انتخاب $label',
          onPressed: saving ? null : () async {
            final now = storeWallTimeNow();
            final selected = await showLocalizedDatePicker(
              context: context,
              initialDate: date(fields[key]!.text) ?? now,
              firstDate: DateTime(2000),
              lastDate: key == 'purchased' ? now : DateTime(2100),
              helpText: label,
            );
            if (selected != null && mounted) fields[key]!.text = formatCalendarDate(selected, locale);
          },
          icon: const Icon(Icons.calendar_month_outlined),
        ),
      ),
      validator: (value) {
        final parsed = date(value);
        if (parsed == null) return english ? 'Enter a valid date.' : 'تاریخ معتبر وارد کنید.';
        if (key == 'purchased' && parsed.isAfter(DateUtils.dateOnly(storeWallTimeNow()))) {
          return english ? 'Purchase date cannot be in the future.' : 'تاریخ خرید در آینده نباشد.';
        }
        if (key == 'expires' && date(fields['produced']!.text) != null && !parsed.isAfter(date(fields['produced']!.text)!)) {
          return english ? 'Expiration must be after production.' : 'انقضا بعد از تولید باشد.';
        }
        return null;
      },
    );
  }
  Widget money(String key, String label) => TextFormField(controller: fields[key],
    keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: const [PersianDigitsInputFormatter()], decoration: InputDecoration(labelText: '$label هر بسته (تومان)'),
    validator: (value) { final n = parsePersianNumber(value); return n == null || !n.isFinite || n < 0 || n > 100000000000 ? 'مبلغ معتبر بین صفر و ۱۰۰ میلیارد تومان وارد کنید.' : null; });
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() { saving = true; error = null; });
    try {
      final batch = await widget.onSave(InventoryReceiptCommand(sku: sku, batchCode: fields['batch']!.text.trim(),
        receivedPackages: parsePersianInteger(fields['quantity']!.text, min: 1, max: maxInventoryAdjustment)!, supplier: fields['supplier']!.text.trim(),
        supplierContactName: fields['supplierContactName']!.text.trim(), supplierPhone: fields['supplierPhone']!.text.trim(),
        supplierEmail: fields['supplierEmail']!.text.trim(), supplierAddress: fields['supplierAddress']!.text.trim(),
        supplierNotes: fields['supplierNotes']!.text.trim(),
        producedAt: date(fields['produced']!.text)!, expiresAt: date(fields['expires']!.text)!, purchasedAt: date(fields['purchased']!.text)!,
        costPrice: parsePersianNumber(fields['cost']!.text)! * 10, packagingCost: parsePersianNumber(fields['packaging']!.text)! * 10,
        additionalCost: parsePersianNumber(fields['additional']!.text)! * 10, openingStock: openingStock));
      if (mounted) Navigator.pop(context, batch);
    } catch (exception) {
      if (mounted) setState(() => error = 'خرید ثبت نشد: $exception. اطلاعات فرم حفظ شده؛ پس از بررسی دوباره تلاش کنید.');
    } finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !saving, child: AlertDialog(
    title: const Text('ثبت خرید، بچ و تاریخ انقضا'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: form,
      child: AbsorbPointer(absorbing: saving, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(openingStock
          ? 'این گزینه موجودی فعلی را به یک بچ وصل می‌کند و تعداد قابل‌فروش را زیاد نمی‌کند. اگر کالا چند تاریخ انقضا دارد، فعلاً تاریخ نزدیک‌تر را برای کل موجودی انتخاب کنید. سفارش‌های در انتظار پرداخت باید تعیین تکلیف شده باشند.'
          : 'هر بار خرید یک بچ جداست. تعداد و تاریخ تولید و انقضای همین سری را ثبت کنید تا هشدار انقضا و گردش موجودی درست باشد. هزینه‌ها برای یک بسته ثبت می‌شوند و قیمت فروش تغییر نمی‌کند.'),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: openingStock,
          title: const Text('ثبت موجودی فعلی و تعیین تاریخ انقضا'),
          subtitle: const Text('برای کالاهایی که از قبل در انبار هستند و هنوز بچ ندارند'),
          onChanged: saving ? null : (value) => setState(() {
            openingStock = value;
            fields['quantity']!.text = value
                ? formatPersianInteger(selectedVariant.availablePackages)
                : '';
          }),
        ),
        DropdownButtonFormField<String>(initialValue: sku, isExpanded: true, decoration: const InputDecoration(labelText: 'کالا و اندازهٔ بسته'),
          items: widget.products.expand((p) => p.variants.map((v) => DropdownMenuItem(value: v.sku,
            child: Text('${p.title} · ${v.displayLabel}', overflow: TextOverflow.ellipsis)))).toList(),
          onChanged: (value) {
            if (value == null) return;
            final variant = widget.products.expand((p) => p.variants)
                .firstWhere((item) => item.sku == value);
            setState(() {
              sku = value;
              _setVariantCostDefaults(variant);
              if (openingStock) fields['quantity']!.text = formatPersianInteger(variant.availablePackages);
            });
          }),
        TextFormField(controller: fields['batch'], maxLength: 80, decoration: const InputDecoration(labelText: 'کد خرید / بچ'),
          validator: (v) => v == null || v.trim().isEmpty ? 'کد خرید الزامی است.' : null),
        TextFormField(controller: fields['supplier'], maxLength: 200, decoration: const InputDecoration(labelText: 'نام تأمین‌کننده'),
          validator: (v) => v == null || v.trim().isEmpty ? 'نام تأمین‌کننده را وارد کنید.' : null),
        TextFormField(controller: fields['supplierContactName'], maxLength: 200, decoration: const InputDecoration(labelText: 'نام شخص تماس (اختیاری)')),
        TextFormField(controller: fields['supplierPhone'], maxLength: 40, keyboardType: TextInputType.phone, inputFormatters: const [PersianDigitsInputFormatter()], decoration: const InputDecoration(labelText: 'شماره تماس تأمین‌کننده (اختیاری)')),
        TextFormField(controller: fields['supplierEmail'], maxLength: 254, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'ایمیل تأمین‌کننده (اختیاری)'),
          validator: (v) { final email = v?.trim() ?? ''; return email.isEmpty || RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ? null : 'ایمیل معتبر وارد کنید.'; }),
        TextFormField(controller: fields['supplierAddress'], maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'نشانی تأمین‌کننده (اختیاری)')),
        TextFormField(controller: fields['supplierNotes'], maxLength: 1000, maxLines: 2, decoration: const InputDecoration(labelText: 'یادداشت دربارهٔ تأمین‌کننده (اختیاری)')),
        TextFormField(controller: fields['quantity'], keyboardType: TextInputType.number, inputFormatters: const [PersianGroupedIntegerInputFormatter()], decoration: InputDecoration(labelText: openingStock ? 'تعداد بستهٔ موجود فعلی' : 'تعداد بستهٔ خریداری‌شده', helperText: openingStock ? 'باید برابر موجودی فعلی باشد: ${formatPersianInteger(selectedVariant.availablePackages)} بسته' : null),
          validator: (v) => parsePersianInteger(v, min: 1, max: maxInventoryAdjustment) == null
              ? 'تعداد صحیح بین ۱ و ۱ میلیون وارد کنید.'
              : null),
        const SizedBox(height: 8),
        const Align(alignment: AlignmentDirectional.centerStart, child: Text('تاریخ‌های همین بچ', style: TextStyle(fontWeight: FontWeight.w800))),
        dateField('purchased'), dateField('produced'), dateField('expires'),
        money('cost', 'قیمت خرید / مواد'), money('packaging', 'بسته‌بندی'), money('additional', 'هزینهٔ جانبی'),
        if (saving) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ]))))),
    actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'در حال ثبت…' : 'ثبت خرید'))],
  ));
  @override
  void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
}
