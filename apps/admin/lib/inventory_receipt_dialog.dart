import 'package:flutter/material.dart';
import 'catalog_api.dart';
import 'formatters.dart';
import 'localized_calendar.dart';
import 'order_api.dart';

class InventoryReceiptCommand {
  const InventoryReceiptCommand({required this.sku, required this.batchCode, required this.receivedPackages,
    required this.producedAt, required this.expiresAt, required this.purchasedAt, required this.supplier,
    required this.supplierContactName, required this.supplierPhone, required this.supplierEmail,
    required this.supplierAddress, required this.supplierNotes, required this.costPrice, required this.packagingCost, required this.additionalCost});
  final String sku, batchCode, supplier, supplierContactName, supplierPhone, supplierEmail, supplierAddress, supplierNotes;
  final int receivedPackages;
  final DateTime producedAt, expiresAt, purchasedAt;
  final num costPrice, packagingCost, additionalCost;
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
  String? error;
  bool _purchaseDateInitialized = false;
  @override
  void initState() {
    super.initState();
    sku = widget.products.expand((p) => p.variants).first.sku;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_purchaseDateInitialized) return;
    _purchaseDateInitialized = true;
    fields['purchased']!.text = formatCalendarDate(DateTime.now(), Localizations.localeOf(context));
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
            final now = DateTime.now();
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
        if (key == 'purchased' && parsed.isAfter(DateTime.now())) {
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
        additionalCost: parsePersianNumber(fields['additional']!.text)! * 10));
      if (mounted) Navigator.pop(context, batch);
    } catch (exception) {
      if (mounted) setState(() => error = 'خرید ثبت نشد: $exception. اطلاعات فرم حفظ شده؛ پس از بررسی دوباره تلاش کنید.');
    } finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) => PopScope(canPop: !saving, child: AlertDialog(
    title: const Text('ثبت خرید و دریافت کالا'),
    content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(key: form,
      child: AbsorbPointer(absorbing: saving, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('مقدار بر حسب بستهٔ انتخاب‌شده است؛ هزینه‌ها برای یک بسته ثبت می‌شوند. قیمت فروش با این ثبت تغییر نمی‌کند.'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(initialValue: sku, isExpanded: true, decoration: const InputDecoration(labelText: 'کالا و اندازهٔ بسته'),
          items: widget.products.expand((p) => p.variants.map((v) => DropdownMenuItem(value: v.sku,
            child: Text('${p.title} · ${v.displayLabel}', overflow: TextOverflow.ellipsis)))).toList(),
          onChanged: (value) => setState(() => sku = value ?? sku)),
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
        TextFormField(controller: fields['quantity'], keyboardType: TextInputType.number, inputFormatters: const [PersianGroupedIntegerInputFormatter()], decoration: const InputDecoration(labelText: 'تعداد بستهٔ خریداری‌شده'),
          validator: (v) => parsePersianInteger(v, min: 1, max: maxInventoryAdjustment) == null
              ? 'تعداد صحیح بین ۱ و ۱ میلیون وارد کنید.'
              : null),
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
