import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'corporate_api.dart';
import 'formatters.dart';
import 'main.dart' show AdminColors;

class CorporateRequestsPage extends StatefulWidget {
  const CorporateRequestsPage({super.key, this.api});
  final CorporateApiClient? api;
  @override
  State<CorporateRequestsPage> createState() => _CorporateRequestsPageState();
}

class _CorporateRequestsPageState extends State<CorporateRequestsPage> {
  late final CorporateApiClient api = widget.api ?? CorporateApiClient();
  final search = TextEditingController();
  final statuses = const {'': 'همه وضعیت‌ها', 'New': 'جدید', 'Reviewing': 'در حال بررسی', 'Contacted': 'تماس گرفته شد', 'NeedsInformation': 'نیازمند اطلاعات بیشتر', 'ProformaSent': 'پیش‌فاکتور ارسال شد', 'Negotiating': 'در حال مذاکره', 'Approved': 'تأیید شد', 'Preparing': 'در حال آماده‌سازی', 'Shipped': 'ارسال شد', 'Finalized': 'نهایی شد', 'Cancelled': 'لغو شد'};
  List<CorporateRequestSummary> items = [];
  CorporateRequestDetail? selected;
  CorporateSummary? summary;
  String status = '';
  Object? error;
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final values = await Future.wait([api.fetchRequests(status: status, query: search.text), api.fetchSummary()]);
      if (mounted) setState(() { items = values[0] as List<CorporateRequestSummary>; summary = values[1] as CorporateSummary; });
    } catch (exception) { if (mounted) setState(() => error = exception); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> open(CorporateRequestSummary item) async {
    try {
      final detail = await api.fetchDetail(item.id);
      if (!mounted) return;
      if (MediaQuery.sizeOf(context).width < 900) {
        await showDialog<void>(context: context, builder: (_) => Dialog(child: SizedBox(width: 430, height: MediaQuery.sizeOf(context).height * .82, child: _DetailPanel(item: detail, api: api, onChanged: () { Navigator.of(context).pop(); load(); }))));
      } else { setState(() => selected = detail); }
    } catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString()))); }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    return LayoutBuilder(builder: (context, constraints) => Row(children: [
      Expanded(child: _listView()),
      if (constraints.maxWidth > 900) SizedBox(width: 370, child: selected == null ? const Center(child: Text('برای مدیریت جزئیات، یک درخواست را انتخاب کنید.')) : _DetailPanel(item: selected!, api: api, onChanged: () { load(); setState(() => selected = null); })),
    ]));
  }

  Widget _listView() => ListView(padding: const EdgeInsets.all(28), children: [
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('فروش سازمانی', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)), const SizedBox(height: 6), Text('${formatPersianInteger(items.length)} درخواست قابل پیگیری', style: const TextStyle(color: AdminColors.muted))])),
      if ((summary?.newCount ?? 0) > 0) Chip(avatar: const Icon(Icons.notifications_active_rounded, size: 17), label: Text('${formatPersianInteger(summary!.newCount)} جدید')),
      IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
    ]),
    const SizedBox(height: 18),
    Row(children: [Expanded(child: TextField(controller: search, onSubmitted: (_) => load(), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'جست‌وجو با نام، شرکت یا شماره'))), const SizedBox(width: 10), DropdownButton<String>(value: status, items: statuses.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) { setState(() => status = value ?? ''); load(); })]),
    const SizedBox(height: 18),
    if (items.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Column(children: [Icon(Icons.business_center_outlined, size: 48, color: AdminColors.muted), SizedBox(height: 12), Text('درخواستی ثبت نشده است'), Text('درخواست‌های جدید اینجا نمایش داده می‌شوند.', style: TextStyle(color: AdminColors.muted))]))
    else ...items.map((item) => Card(child: ListTile(onTap: () => open(item), leading: const CircleAvatar(backgroundColor: AdminColors.mintSoft, child: Icon(Icons.business_center_rounded, color: AdminColors.ink)), title: Text('${item.companyName} · ${item.customerName}', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${item.city} · ${formatPersianInteger(item.orderQuantity)} سفارش · ${statuses[item.status] ?? item.status}'), trailing: const Icon(Icons.chevron_left_rounded)))),
  ]);
}

class _DetailPanel extends StatefulWidget {
  const _DetailPanel({required this.item, required this.api, required this.onChanged});
  final CorporateRequestDetail item;
  final CorporateApiClient api;
  final VoidCallback onChanged;
  @override
  State<_DetailPanel> createState() => _DetailPanelState();
}

class _DetailPanelState extends State<_DetailPanel> {
  late String status = widget.item.status;
  final note = TextEditingController();
  final statuses = const {'New': 'جدید', 'Reviewing': 'در حال بررسی', 'Contacted': 'تماس گرفته شد', 'NeedsInformation': 'نیازمند اطلاعات بیشتر', 'ProformaSent': 'پیش‌فاکتور ارسال شد', 'Negotiating': 'در حال مذاکره', 'Approved': 'تأیید شد', 'Preparing': 'در حال آماده‌سازی', 'Shipped': 'ارسال شد', 'Finalized': 'نهایی شد', 'Cancelled': 'لغو شد'};
  @override
  void dispose() { note.dispose(); super.dispose(); }
  Future<void> save() async {
    try { await widget.api.changeStatus(widget.item.id, status, note: note.text); if (note.text.isNotEmpty) await widget.api.addNote(widget.item.id, note.text); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('درخواست به‌روزرسانی شد.'))); widget.onChanged(); } }
    catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString()))); }
  }
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.fromLTRB(0, 28, 28, 28), child: ListView(padding: const EdgeInsets.all(22), children: [
    Text(widget.item.companyName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text(widget.item.customerName, style: const TextStyle(color: AdminColors.muted)), const Divider(height: 28),
    _line('تماس', widget.item.mobile), _line('شهر و مناسبت', '${widget.item.city} · ${widget.item.occasion}'), _line('تعداد و بسته', '${formatPersianInteger(widget.item.orderQuantity)} · ${widget.item.packageType}'),
    if (widget.item.email != null) _line('ایمیل', widget.item.email!), if (widget.item.description != null) _line('توضیحات', widget.item.description!), const SizedBox(height: 18),
    DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'وضعیت درخواست'), items: statuses.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setState(() => status = value ?? status)), const SizedBox(height: 12),
    TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت داخلی')), const SizedBox(height: 12), FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_rounded), label: const Text('ذخیره تغییرات')),
  ]));
  Widget _line(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 76, child: Text(label, style: const TextStyle(color: AdminColors.muted, fontSize: 11))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)))]));
}
