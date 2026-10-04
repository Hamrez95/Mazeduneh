// The async file/message callbacks guard mounted before using the panel context.
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
  final city = TextEditingController();
  final statuses = const {'': 'همه وضعیت‌ها', 'New': 'جدید', 'Reviewing': 'در حال بررسی', 'Contacted': 'تماس گرفته شد', 'NeedsInformation': 'نیازمند اطلاعات بیشتر', 'ProformaSent': 'پیش‌فاکتور ارسال شد', 'Negotiating': 'در حال مذاکره', 'Approved': 'تأیید شد', 'Preparing': 'در حال آماده‌سازی', 'Shipped': 'ارسال شد', 'Finalized': 'نهایی شد', 'Cancelled': 'لغو شد'};
  List<CorporateRequestSummary> items = [];
  CorporateRequestDetail? selected;
  CorporateSummary? summary;
  String status = '';
  Object? error;
  bool loading = true;
  bool overdueOnly = false;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); city.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final values = await Future.wait([api.fetchRequests(status: status, query: search.text, city: city.text.trim(), overdueOnly: overdueOnly), api.fetchSummary()]);
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

  Widget _filterFields() => LayoutBuilder(builder: (context, constraints) {
    final searchField = TextField(
      controller: search, onSubmitted: (_) => load(),
      decoration: const InputDecoration(labelText: 'جست‌وجو', prefixIcon: Icon(Icons.search_rounded), hintText: 'نام، شرکت یا شماره'),
    );
    final cityField = TextField(
      controller: city, onSubmitted: (_) => load(),
      decoration: const InputDecoration(labelText: 'شهر'),
    );
    final statusField = InputDecorator(
      decoration: const InputDecoration(labelText: 'وضعیت درخواست'),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: status, isExpanded: true, isDense: true,
        items: statuses.entries.map((entry) => DropdownMenuItem(value: entry.key,
          child: Text(entry.value, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (value) { setState(() => status = value ?? ''); load(); },
      )),
    );
    if (constraints.maxWidth < 500) {
      return Column(children: [searchField, const SizedBox(height: 12), cityField, const SizedBox(height: 12), statusField]);
    }
    if (constraints.maxWidth < 900) {
      return Column(children: [searchField, const SizedBox(height: 12),
        Row(children: [Expanded(child: cityField), const SizedBox(width: 12), Expanded(child: statusField)]),
      ]);
    }
    return Row(children: [Expanded(child: searchField), const SizedBox(width: 12),
      SizedBox(width: 160, child: cityField), const SizedBox(width: 12), SizedBox(width: 220, child: statusField),
    ]);
  });

  Widget _listView() => ListView(padding: const EdgeInsets.all(28), children: [
    LayoutBuilder(builder: (context, constraints) {
      final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('فروش سازمانی', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
        const SizedBox(height: 6),
        Text('${formatPersianInteger(items.length)} درخواست قابل پیگیری', style: const TextStyle(color: AdminColors.muted)),
      ]);
      final controls = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if ((summary?.newCount ?? 0) > 0)
          Chip(avatar: const Icon(Icons.notifications_active_rounded, size: 17), label: Text('${formatPersianInteger(summary!.newCount)} جدید')),
        FilterChip(
          label: const Text('پیگیری‌های عقب‌افتاده'),
          selected: overdueOnly,
          onSelected: (value) { setState(() => overdueOnly = value); load(); },
        ),
        IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد درخواست‌ها'),
      ]);
      return constraints.maxWidth < 720
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, const SizedBox(height: 12), controls])
          : Row(children: [Expanded(child: heading), const SizedBox(width: 16), controls]);
    }),
    const SizedBox(height: 18),
    _filterFields(),
    const SizedBox(height: 18),
    if (items.isEmpty) Padding(
      padding: const EdgeInsets.all(40),
      child: Column(children: [
        const Icon(Icons.business_center_outlined, size: 48, color: AdminColors.muted),
        const SizedBox(height: 12),
        Text(overdueOnly ? 'پیگیری عقب‌افتاده‌ای پیدا نشد' : 'درخواستی ثبت نشده است'),
        Text(
          overdueOnly ? 'درخواست‌های فعال با زمان پیگیری گذشته در این فهرست دیده می‌شوند.' : 'درخواست‌های جدید اینجا نمایش داده می‌شوند.',
          style: const TextStyle(color: AdminColors.muted),
          textAlign: TextAlign.center,
        ),
      ]),
    )
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
  late final assignee = TextEditingController(text: widget.item.assignedTo ?? '');
  final message = TextEditingController();
  final statuses = const {'New': 'جدید', 'Reviewing': 'در حال بررسی', 'Contacted': 'تماس گرفته شد', 'NeedsInformation': 'نیازمند اطلاعات بیشتر', 'ProformaSent': 'پیش‌فاکتور ارسال شد', 'Negotiating': 'در حال مذاکره', 'Approved': 'تأیید شد', 'Preparing': 'در حال آماده‌سازی', 'Shipped': 'ارسال شد', 'Finalized': 'نهایی شد', 'Cancelled': 'لغو شد'};
  @override
  void dispose() { note.dispose(); assignee.dispose(); message.dispose(); super.dispose(); }
  Future<void> save() async {
    try { await widget.api.changeStatus(widget.item.id, status, note: note.text); await widget.api.assign(widget.item.id, assignee.text.trim().isEmpty ? null : assignee.text.trim()); if (note.text.isNotEmpty) await widget.api.addNote(widget.item.id, note.text); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('درخواست به‌روزرسانی شد.'))); widget.onChanged(); } }
    catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString()))); }
  }
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.fromLTRB(0, 28, 28, 28), child: ListView(padding: const EdgeInsets.all(22), children: [
    Text(widget.item.companyName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), Text(widget.item.customerName, style: const TextStyle(color: AdminColors.muted)), const Divider(height: 28),
    _line('تماس', widget.item.mobile), _line('شهر و مناسبت', '${widget.item.city} · ${widget.item.occasion}'), _line('تعداد و بسته', '${formatPersianInteger(widget.item.orderQuantity)} · ${widget.item.packageType}'),
    if (widget.item.email != null) _line('ایمیل', widget.item.email!), if (widget.item.description != null) _line('توضیحات', widget.item.description!), const SizedBox(height: 18),
    DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'وضعیت درخواست'), items: statuses.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(), onChanged: (value) => setState(() => status = value ?? status)), const SizedBox(height: 12),
    TextField(controller: assignee, decoration: const InputDecoration(labelText: 'مسئول پیگیری / ایمیل ادمین')), const SizedBox(height: 12),
    TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'یادداشت داخلی')), const SizedBox(height: 12),
    Row(children: [Expanded(child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save_rounded), label: const Text('ذخیره تغییرات'))), const SizedBox(width: 8), OutlinedButton.icon(onPressed: () async { final picked = await FilePicker.platform.pickFiles(withData: true); final file = picked?.files.single; if (file?.bytes == null) return; try { await widget.api.uploadProforma(widget.item.id, file!.name, file.bytes!); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پیش‌فاکتور بارگذاری شد.'))); } catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString()))); } }, icon: const Icon(Icons.attach_file_rounded), label: const Text('پیش‌فاکتور'))]), const SizedBox(height: 12),
    TextField(controller: message, maxLines: 2, decoration: const InputDecoration(labelText: 'پیام/پاسخ مشتری')), const SizedBox(height: 8), OutlinedButton.icon(onPressed: () async { if (message.text.trim().isEmpty) return; try { await widget.api.addMessage(widget.item.id, message.text.trim()); message.clear(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پیام در تاریخچه ثبت شد.'))); } catch (exception) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString()))); } }, icon: const Icon(Icons.send_rounded), label: const Text('ثبت پیام')),
  ]));
  Widget _line(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 76, child: Text(label, style: const TextStyle(color: AdminColors.muted, fontSize: 11))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)))]));
}
