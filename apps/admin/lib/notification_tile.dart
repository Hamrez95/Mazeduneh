import 'package:flutter/material.dart';

import 'admin_navigation.dart';
import 'auth_session.dart';
import 'formatters.dart';
import 'order_api.dart';

/// The API's current notices describe queues, not individual order records.
/// Unknown types deliberately have no guessed destination.
class AdminNotificationTile extends StatelessWidget {
  const AdminNotificationTile({super.key, required this.item, this.onNavigate});

  final AdminNotification item;
  final ValueChanged<AdminNavigationIntent>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final route = item.target?.toIntent();
    final session = OwnerSession.instance;
    final canNavigate = route != null && onNavigate != null &&
        (!session.isAuthenticated || session.can(route.module.permission));
    final routeLabel = switch (route?.module) {
      AdminModule.orders => 'مشاهده سفارش‌ها',
      AdminModule.inventory => 'مشاهده موجودی',
      AdminModule.products => 'مشاهده محصولات',
      AdminModule.customers => 'مشاهده مشتری‌ها',
      AdminModule.corporate => 'مشاهده فروش سازمانی',
      AdminModule.reports => 'مشاهده گزارش‌ها',
      _ => 'مشاهده بخش مرتبط',
    };
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        child: Icon(item.type == 'critical' ? Icons.priority_high_rounded : Icons.info_outline_rounded,
            color: colors.onPrimaryContainer),
      ),
      title: Text(toPersianDigits(item.title), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 5),
        Text(toPersianDigits(item.detail), style: TextStyle(color: colors.onSurface)),
        if (item.type == 'critical')
          const Padding(padding: EdgeInsets.only(top: 5), child: Text('فوری')),
        if (canNavigate)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => onNavigate!(route),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(routeLabel),
            ),
          ),
      ]),
    );
  }
}
