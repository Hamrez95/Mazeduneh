import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_theme.dart';
import 'notification_tile.dart';
import 'order_api.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.api, this.onNavigate});
  final OrderApiClient? api;
  final ValueChanged<int>? onNavigate;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final OrderApiClient api = widget.api ?? OrderApiClient();
  AdminNotifications? data;
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await api.fetchNotifications();
      if (mounted) setState(() => data = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مرکز اعلان‌ها', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
          const SizedBox(height: 6),
          const Text('هشدارهای سفارش، موجودی و کارهای مهم را در یک صف واضح دنبال کنید.', style: TextStyle(color: AdminColors.muted)),
        ])),
        IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
      ]),
      const SizedBox(height: 20),
      if (loading && data != null) const LinearProgressIndicator(),
      if (error != null && data != null && requestStatusCode(error!) != 401 && requestStatusCode(error!) != 403)
        AdminStaleBanner(detail: 'اعلان‌های قبلی نمایش داده می‌شوند. ${requestErrorMessage(error!)}', onRetry: load),
      Expanded(child: _body()),
    ]),
  );

  Widget _body() {
    if (loading && data == null) return const Center(child: CircularProgressIndicator());
    if (error != null && (data == null || requestStatusCode(error!) == 401 || requestStatusCode(error!) == 403)) {
      return AdminErrorState(error: error!, onRetry: load);
    }
    final items = data?.items ?? const <AdminNotification>[];
    if (items.isEmpty) return const Center(child: AdminEmptyState(icon: Icons.notifications_none_rounded, title: 'فعلاً اعلان مهمی ندارید', detail: 'اعلان سفارش، موجودی یا پیگیری بعدی اینجا نمایش داده می‌شود.'));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => Card(child: AdminNotificationTile(item: items[index], onNavigate: widget.onNavigate)),
    );
  }
}
