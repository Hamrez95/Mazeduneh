import 'package:flutter/material.dart';
import 'admin_permissions.dart';
import 'auth_session.dart';
import 'catalog_api.dart';
import 'formatters.dart';
import 'order_api.dart';

class InventoryPricingDialog extends StatefulWidget {
  const InventoryPricingDialog({super.key, required this.products, required this.orders});
  final List<Product> products;
  final OrderApiClient orders;
  @override
  State<InventoryPricingDialog> createState() => _InventoryPricingDialogState();
}
class _InventoryPricingDialogState extends State<InventoryPricingDialog> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in ['packagingCost','packagingMultiplier','packagingPercent','additionalCost','additionalPercent','markupPercent','roundingStep']) key: TextEditingController(),
  };
  late String sku;
  String? batchId, error;
  Map<String, dynamic>? state, quote;
  bool loading = true, busy = false;
  List<Map<String, dynamic>> get batches => (state?['batches'] as List? ?? []).cast<Map<String, dynamic>>();
  bool get canApply => OwnerSession.instance.can(AdminPermissions.pricingWrite) && OwnerSession.instance.can(AdminPermissions.productsWrite);
  @override
  void initState() { super.initState(); sku = widget.products.expand((p) => p.variants).first.sku; load(); }
  Future<void> load() async {
    final requested = sku;
    setState(() { loading = true; error = null; quote = null; state = null; });
    try {
      final result = await widget.orders.inventoryPricing(requested);
      if (!mounted || requested != sku) return;
      setState(() {
        state = result;
        final saved = result['recipe'] as Map<String, dynamic>?;
        batchId = saved?['batchId'] as String?;
        if (!batches.any((b) => b['id'].toString() == batchId)) batchId = batches.isEmpty ? null : batches.first['id'].toString();
        final batch = batches.where((b) => b['id'].toString() == batchId).firstOrNull;
        for (final entry in fields.entries) {
          num value = saved?[entry.key] as num? ?? (entry.key == 'packagingMultiplier' ? 1 : entry.key == 'roundingStep' ? 10 : 0);
          if (saved == null && ['packagingCost','additionalCost'].contains(entry.key)) value = batch?[entry.key] as num? ?? 0;
          if (['packagingCost','additionalCost','roundingStep'].contains(entry.key)) value /= 10;
          entry.value.text = toPersianDigits(value);
        }
      });
    } catch (exception) { if (mounted && requested == sku) setState(() => error = 'اطلاعات قیمت دریافت نشد: $exception. دوباره تازه‌سازی کنید.'); }
    finally { if (mounted && requested == sku) setState(() => loading = false); }
  }
  Map<String, dynamic> recipe() => {'batchId': batchId, for (final entry in fields.entries)
    entry.key: parsePersianNumber(entry.value.text)! * (['packagingCost','additionalCost','roundingStep'].contains(entry.key) ? 10 : 1)};
  Future<void> preview() async {
    if (!form.currentState!.validate()) return;
    setState(() { busy = true; error = null; quote = null; });
    try { final result = await widget.orders.inventoryPricing(sku, action: 'preview', input: recipe()); if (mounted) setState(() => quote = result); }
    catch (exception) { if (mounted) setState(() => error = 'محاسبه انجام نشد: $exception. ورودی‌ها را بررسی و دوباره تلاش کنید.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> apply() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('تأیید قیمت فروش'),
      content: Text('قیمت این بسته به ${formatToman(quote!['sellingPrice'] as num)} تومان تغییر می‌کند. قیمت سفارش‌های قبلی تغییر نمی‌کند.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأیید اعمال قیمت'))],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { busy = true; error = null; });
    try {
      await widget.orders.inventoryPricing(sku, action: 'apply', input: {'recipe': recipe(), 'expectedPrice': state!['currentPrice']});
      if (mounted) Navigator.pop(context, true);
    } catch (exception) { if (mounted) setState(() { quote = null; error = 'اعمال قیمت تأیید نشد: $exception. تازه‌سازی کنید و پیش‌نمایش جدید بگیرید؛ ممکن است درخواست قبلی ثبت شده باشد.'; }); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Widget input(String key, String label, num max, {num min = 0}) => Padding(padding: const EdgeInsets.only(top: 10), child: TextFormField(
    controller: fields[key], decoration: InputDecoration(labelText: label), keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() => quote = null),
    validator: (value) { final n = parsePersianNumber(value); return n == null || !n.isFinite || n < min || n > max ? 'عدد بین ${toPersianDigits(min)} و ${toPersianDigits(max)} وارد کنید.' : null; }));
  @override
  Widget build(BuildContext context) => PopScope(canPop: !busy, child: AlertDialog(
    title: const Text('محاسبه قیمت فروش'),
    content: SizedBox(width: 540, child: SingleChildScrollView(child: AbsorbPointer(absorbing: busy, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: sku, isExpanded: true, decoration: const InputDecoration(labelText: 'کالا و اندازهٔ بسته'),
          items: widget.products.expand((p) => p.variants.map((v) => DropdownMenuItem(value: v.sku,
            child: Text('${p.title} · ${v.displayLabel}', overflow: TextOverflow.ellipsis)))).toList(),
          onChanged: (value) { if (value != null) { sku = value; load(); } }),
        if (loading) const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (!loading && state != null && batches.isEmpty) const Padding(padding: EdgeInsets.all(12),
          child: Text('هنوز خریدی برای این بسته ثبت نشده است. به انبار برگردید و «ثبت خرید» را انتخاب کنید.')),
        if (!loading && batches.isNotEmpty) Form(key: form, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Text('قیمت فعلی: ${formatToman(state!['currentPrice'] as num)} تومان'),
          DropdownButtonFormField<String>(key: ValueKey('$sku-$batchId'), initialValue: batchId, isExpanded: true,
            decoration: const InputDecoration(labelText: 'خرید مبنای محاسبه'),
            items: batches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(
              '${b['batchCode']} · ${formatToman(b['costPrice'] as num)} تومان هر بسته', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() { batchId = v; quote = null; }), validator: (v) => v == null ? 'خرید را انتخاب کنید.' : null),
          const SizedBox(height: 8),
          const Text('سود روی بهای تمام‌شده اضافه می‌شود. درصد بسته‌بندی و جانبی نسبت به هزینهٔ خرید است. تغییر ورودی‌ها پیش‌نمایش قبلی را باطل می‌کند.'),
          input('packagingCost','مبلغ پایه بسته‌بندی (تومان)',100000000000),
          input('packagingMultiplier','ضریب بسته‌بندی',100), input('packagingPercent','درصد بسته‌بندی از خرید',1000),
          input('additionalCost','مبلغ جانبی (تومان)',100000000000), input('additionalPercent','درصد جانبی از خرید',1000),
          input('markupPercent','درصد سود روی بهای تمام‌شده',1000), input('roundingStep','گام گردکردن رو به بالا (تومان)',100000000,min: 0.1),
        ])),
        if (quote != null) Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final entry in {'purchaseCost':'خرید','packagingCost':'بسته‌بندی','additionalCost':'جانبی','totalCost':'بهای تمام‌شده','sellingPrice':'قیمت پیشنهادی','profit':'سود هر بسته'}.entries)
            Text('${entry.value}: ${formatToman(quote![entry.key] as num)} تومان'),
          Text('حاشیه سود از قیمت فروش: ${formatPersianNumber(quote!['marginPercent'] as num, fractionDigits: 2)}٪'),
          const Text('قیمت پایهٔ کالا؛ مالیات و ارسال در تسویه طبق تنظیمات فروشگاه محاسبه می‌شوند.'),
        ])),
        if (!canApply) const Padding(padding: EdgeInsets.only(top: 12), child: Text('برای اعمال قیمت، دسترسی تغییر قیمت و ویرایش محصول لازم است. پیش‌نمایش برای شما مجاز است.')),
        if (busy) const LinearProgressIndicator(),
        if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ])))),
    actions: [TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('بستن')),
      TextButton(onPressed: busy || loading ? null : load, child: const Text('تازه‌سازی')),
      OutlinedButton(onPressed: busy || loading || batches.isEmpty ? null : preview, child: const Text('پیش‌نمایش قیمت')),
      FilledButton(onPressed: busy || quote == null || !canApply ? null : apply, child: const Text('اعمال قیمت فروش'))],
  ));
  @override
  void dispose() { for (final c in fields.values) { c.dispose(); } super.dispose(); }
}
