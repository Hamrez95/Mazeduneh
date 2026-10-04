import 'package:flutter/material.dart';

import 'admin_permissions.dart';
import 'auth_session.dart';
import 'formatters.dart';
import 'order_api.dart';

/// The API's current notices describe queues, not individual order records.
/// Unknown types deliberately have no guessed destination.
class AdminNotificationTile extends StatelessWidget {
  const AdminNotificationTile({super.key, required this.item, this.onNavigate});

  final AdminNotification item;
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final route = switch (item.type) {
      'awaiting-payment' || 'new-orders' =>
        (destination: 1, permission: AdminPermissions.ordersRead, label: 'مشاهده سفارش‌ها'),
      'low-stock' =>
        (destination: 3, permission: AdminPermissions.inventoryRead, label: 'مشاهده موجودی'),
      _ => null,
    };
    final session = OwnerSession.instance;
    final canNavigate = route != null && onNavigate != null &&
        (!session.isAuthenticated || session.can(route.permission));
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
              onPressed: () => onNavigate!(route.destination),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(route.label),
            ),
          ),
      ]),
    );
  }
}
