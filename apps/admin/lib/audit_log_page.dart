import 'dart:convert';

import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'audit_log_api.dart';
import 'formatters.dart';
import 'main.dart' show AdminColors;

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key, this.api});

  final AuditLogApiClient? api;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  late final AuditLogApiClient api = widget.api ?? AuditLogApiClient();
  final entityIdController = TextEditingController();
  List<AdminAuditLogEntry> entries = const [];
  String entityType = '';
  Object? error;
  bool loading = true;
  DateTime? lastLoadedAt;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    entityIdController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.fetchLogs(entityType: entityType, entityId: entityIdController.text, limit: 100);
      if (mounted) setState(() {
        entries = result;
        lastLoadedAt = DateTime.now();
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = loading && entries.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : error != null && entries.isEmpty
            ? AdminErrorState(error: error!, onRetry: load)
            : ListView(
                padding: const EdgeInsets.all(28),
                children: [
                  if (error != null) AdminStaleBanner(detail: 'گزارش‌های نمایش‌داده‌شده ممکن است تازه نباشند. ${requestErrorMessage(error!)}', onRetry: load),
                  _AuditHeader(lastLoadedAt: lastLoadedAt, loading: loading, onRefresh: load),
                  const SizedBox(height: 18),
                  _AuditFilters(
                    entityType: entityType,
                    entityIdController: entityIdController,
                    onTypeChanged: (value) => setState(() => entityType = value ?? ''),
                    onSearch: load,
                  ),
                  const SizedBox(height: 18),
                  if (entries.isEmpty)
                    const Card(child: AdminEmptyState(
                      icon: Icons.fact_check_outlined,
                      title: 'هنوز فعالیت حساسی ثبت نشده است',
                      detail: 'وقتی انتشار محصول یا اصلاح موجودی انجام شود، خلاصه تغییرات اینجا دیده می‌شود.',
                    ))
                  else
                    _AuditResults(entries: entries),
                ],
              );
    return content;
  }
}

class _AuditHeader extends StatelessWidget {
  const _AuditHeader({required this.lastLoadedAt, required this.loading, required this.onRefresh});

  final DateTime? lastLoadedAt;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final refresh = IconButton(onPressed: loading ? null : onRefresh, tooltip: 'بارگذاری مجدد', icon: const Icon(Icons.refresh_rounded));
        final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('گزارش فعالیت‌های حساس', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdminColors.inkDeep))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AdminColors.mintSoft, borderRadius: BorderRadius.circular(20)),
              child: const Text('فقط Owner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.ink)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('برای پیگیری تغییرات انتشار محصول و موجودی، دلیل و تصویر قبل و بعد را بررسی کنید.', style: TextStyle(color: AdminColors.muted, height: 1.5)),
          if (lastLoadedAt != null) ...[
            const SizedBox(height: 5),
            Text('آخرین به‌روزرسانی: ${formatPersianDateTime(lastLoadedAt!)}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
          ],
        ]);
        return constraints.maxWidth < 560 ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Align(alignment: AlignmentDirectional.centerEnd, child: refresh), title]) : Row(children: [Expanded(child: title), refresh]);
      });
}

class _AuditFilters extends StatelessWidget {
  const _AuditFilters({required this.entityType, required this.entityIdController, required this.onTypeChanged, required this.onSearch});

  final String entityType;
  final TextEditingController entityIdController;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('پیدا کردن یک تغییر', style: TextStyle(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
            const SizedBox(height: 4),
            const Text('برای بررسی یک محصول یا SKU، فیلتر مربوط را انتخاب کنید.', style: TextStyle(fontSize: 12, color: AdminColors.muted)),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 620;
              final type = DropdownButtonFormField<String>(
                value: entityType,
                decoration: const InputDecoration(labelText: 'نوع مورد'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('همه فعالیت‌ها')),
                  DropdownMenuItem(value: 'Product', child: Text('محصول')),
                  DropdownMenuItem(value: 'ProductVariant', child: Text('SKU محصول')),
                ],
                onChanged: onTypeChanged,
              );
              final id = TextField(controller: entityIdController, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'شناسه یا SKU', hintText: 'مثلاً PI-AKB-250'));
              final button = FilledButton.icon(onPressed: onSearch, icon: const Icon(Icons.search_rounded), label: const Text('نمایش گزارش'));
              return stacked ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [type, const SizedBox(height: 10), id, const SizedBox(height: 10), button]) : Row(children: [Expanded(child: type), const SizedBox(width: 10), Expanded(child: id), const SizedBox(width: 10), button]);
            }),
          ]),
        ),
      );
}

class _AuditResults extends StatelessWidget {
  const _AuditResults({required this.entries});

  final List<AdminAuditLogEntry> entries;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('${formatPersianInteger(entries.length)} فعالیت اخیر', style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
            ),
            const SizedBox(height: 10),
            for (final entry in entries) _AuditEntryTile(entry: entry),
          ]),
        ),
      );
}

class _AuditEntryTile extends StatelessWidget {
  const _AuditEntryTile({required this.entry});

  final AdminAuditLogEntry entry;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
        leading: CircleAvatar(backgroundColor: AdminColors.mintSoft, foregroundColor: AdminColors.ink, child: Icon(entry.action == 'inventory.adjustment' ? Icons.inventory_2_rounded : Icons.publish_rounded, size: 19)),
        title: Text(entry.actionLabel, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${entry.entityLabel}: ${entry.entityId}  ·  ${formatPersianDateTime(entry.occurredAt)}', style: const TextStyle(fontSize: 11, color: AdminColors.muted))),
        children: [
          _AuditMetaGrid(entry: entry),
          const SizedBox(height: 10),
          _SnapshotPanel(title: 'قبل از تغییر', value: entry.beforeJson),
          const SizedBox(height: 8),
          _SnapshotPanel(title: 'بعد از تغییر', value: entry.afterJson),
        ],
      );
}

class _AuditMetaGrid extends StatelessWidget {
  const _AuditMetaGrid({required this.entry});
  final AdminAuditLogEntry entry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF7F8F4), borderRadius: BorderRadius.circular(14)),
        child: Wrap(runSpacing: 10, spacing: 28, children: [
          _Meta(label: 'انجام‌دهنده', value: entry.actor),
          _Meta(label: 'دلیل ثبت‌شده', value: entry.reason),
          if (entry.requestId.isNotEmpty) _Meta(label: 'شناسه پیگیری', value: entry.requestId),
        ]),
      );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(width: 220, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AdminColors.muted)), const SizedBox(height: 3), Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: AdminColors.inkDeep))]));
}

class _SnapshotPanel extends StatelessWidget {
  const _SnapshotPanel({required this.title, required this.value});
  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? 'اطلاعاتی ثبت نشده است.' : _prettyJson(value!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AdminColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.muted)),
        const SizedBox(height: 6),
        SelectableText(text, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.5, color: AdminColors.inkDeep)),
      ]),
    );
  }

  String _prettyJson(String raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }
}
