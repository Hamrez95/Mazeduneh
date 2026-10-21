import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_theme.dart';
import 'admin_navigation.dart';
import 'notification_tile.dart';
import 'order_api.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.api, this.onNavigate, this.initialNotificationId});
  final OrderApiClient? api;
  final ValueChanged<AdminNavigationIntent>? onNavigate;
  final String? initialNotificationId;
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
          const Text('هشدارهای سفارش، موجودی و پیگیری‌های فروش سازمانی را در یک صف واضح دنبال کنید.', style: TextStyle(color: AdminColors.muted)),
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
    final items = [...?data?.items];
    if (items.isEmpty) {
      if (widget.initialNotificationId != null) {
        return const Center(child: AdminEmptyState(
          icon: Icons.notifications_off_outlined,
          title: 'این اعلان دیگر در صف فعال نیست.',
          detail: 'برای مشاهدهٔ هشدارهای تازه، فهرست اعلان‌ها را دوباره بارگذاری کنید.',
        ));
      }
      return const Center(child: AdminEmptyState(icon: Icons.notifications_none_rounded, title: 'فعلاً اعلان مهمی ندارید', detail: 'اعلان سفارش، موجودی یا پیگیری بعدی اینجا نمایش داده می‌شود.'));
    }
    final selectedIndex = items.indexWhere((item) => item.id == widget.initialNotificationId);
    if (selectedIndex > 0) items.insert(0, items.removeAt(selectedIndex));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (index == 0 && widget.initialNotificationId != null && selectedIndex < 0)
            const Card(child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('این اعلان دیگر در صف فعال نیست.'),
            )),
          if (index == 0 && widget.initialNotificationId != null && selectedIndex >= 0)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: 12, bottom: 6),
              child: Text('اعلان بازشده از پیوند', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          if (index < items.length) Card(
            shape: items[index].id == widget.initialNotificationId && widget.initialNotificationId != null
                ? RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  )
                : null,
            child: AdminNotificationTile(item: items[index], onNavigate: widget.onNavigate),
          ),
        ],
      ),
    );
  }
}
