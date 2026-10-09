import 'package:flutter/material.dart';
import 'admin_state.dart';
import 'commerce_api.dart';
import 'formatters.dart';
import 'admin_theme.dart';
import 'admin_step_up_dialog.dart';
import 'auth_api.dart';

class CommerceSettingsPage extends StatefulWidget {
  const CommerceSettingsPage({super.key, this.api, this.auth});
  final CommerceApiClient? api;
  final AuthApiClient? auth;
  @override
  State<CommerceSettingsPage> createState() => _CommerceSettingsPageState();
}

class _CommerceSettingsPageState extends State<CommerceSettingsPage> {
  late final CommerceApiClient api = widget.api ?? CommerceApiClient();
  final formKey = GlobalKey<FormState>();
  final tax = TextEditingController();
  CommerceSettings? settings;
  bool loading = true;
  bool saving = false;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final value = await api.fetchSettings();
      if (mounted) setState(() {
        settings = value;
        tax.text = toPersianDigits(value.taxRatePercent);
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate() || settings == null) return;
    setState(() { saving = true; error = null; });
    try {
      final stepUpToken = await showAdminStepUpDialog(context, auth: widget.auth);
      if (stepUpToken == null || !mounted) return;
      final draft = settings!;
      draft.taxRatePercent = parsePersianNumber(tax.text)!;
      final value = await api.updateSettings(draft, stepUpToken: stepUpToken);
      if (mounted) setState(() => settings = value);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تنظیمات قیمت‌گذاری ذخیره شد.')));
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() { tax.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null && settings == null) return AdminErrorState(error: error!, onRetry: load);
    final data = settings!;
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('قیمت‌گذاری و ارسال', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
              const SizedBox(height: 6),
              const Text('نرخ مالیات و هزینه‌های ارسال از این بخش روی سفارش‌های جدید snapshot می‌شوند.', style: TextStyle(color: AdminColors.muted)),
            ])),
            FilledButton.icon(onPressed: saving ? null : save, icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded), label: const Text('ذخیره')),
          ]),
          const SizedBox(height: 20),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error.toString(), style: const TextStyle(color: AdminColors.coral))),
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مالیات فاکتور', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('این درصد فقط در مبلغ سفارش جدید اعمال می‌شود؛ سفارش‌های قبلی نرخ ثبت‌شدهٔ خودشان را حفظ می‌کنند.', style: TextStyle(color: AdminColors.muted)),
            const SizedBox(height: 14),
            SizedBox(width: 260, child: TextFormField(
              controller: tax,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'نرخ مالیات (%)', suffixText: '٪'),
              validator: (value) {
                final amount = parsePersianNumber(value);
                return amount == null || amount < 0 || amount > 100 ? 'بین صفر تا ۱۰۰ وارد کنید.' : null;
              },
            )),
          ]))),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Text('روش‌های ارسال', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            OutlinedButton.icon(onPressed: saving ? null : () => setState(() => data.shippingMethods.add(ShippingMethod(code: 'new-method', title: 'روش جدید', price: 0, freeAbove: 0, isActive: true, internalCost: 0))), icon: const Icon(Icons.add_rounded), label: const Text('روش جدید')),
          ]),
          const SizedBox(height: 10),
          _ShippingEditorList(
            methods: data.shippingMethods,
            onRemove: (index) => setState(() => data.shippingMethods.removeAt(index)),
          ),
        ],
      ),
    );
  }
}

class _ShippingEditorList extends StatelessWidget {
  const _ShippingEditorList({required this.methods, required this.onRemove});
  final List<ShippingMethod> methods;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(methods.length, (index) => _ShippingEditor(
      method: methods[index],
      onRemove: methods.length > 1 ? () => onRemove(index) : null,
    )),
  );
}

class _ShippingEditor extends StatelessWidget {
  const _ShippingEditor({required this.method, required this.onRemove});
  final ShippingMethod method;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 170, child: TextFormField(initialValue: method.code, decoration: const InputDecoration(labelText: 'کد انگلیسی'), onChanged: (value) => method.code = value.trim())),
        SizedBox(width: 240, child: TextFormField(initialValue: method.title, decoration: const InputDecoration(labelText: 'عنوان'), onChanged: (value) => method.title = value.trim())),
        SizedBox(width: 180, child: TextFormField(initialValue: toPersianDigits(method.price), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ از مشتری (ریال)'), onChanged: (value) => method.price = parsePersianNumber(value) ?? method.price)),
        SizedBox(width: 180, child: TextFormField(initialValue: toPersianDigits(method.internalCost), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'هزینه واقعی ارسال (ریال)'), onChanged: (value) => method.internalCost = parsePersianNumber(value) ?? method.internalCost)),
        SizedBox(width: 180, child: TextFormField(initialValue: toPersianDigits(method.freeAbove), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رایگان از (ریال)'), onChanged: (value) => method.freeAbove = parsePersianNumber(value) ?? method.freeAbove)),
        FilterChip(label: Text(method.isActive ? 'فعال' : 'غیرفعال'), selected: method.isActive, onSelected: (value) => method.isActive = value),
        IconButton(onPressed: onRemove, tooltip: 'حذف روش', icon: const Icon(Icons.delete_outline_rounded)),
      ]),
    ),
  );
}
