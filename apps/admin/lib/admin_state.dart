import 'package:flutter/material.dart';

import 'auth_session.dart';
import 'catalog_api.dart';
import 'audit_log_api.dart';
import 'media_api.dart';
import 'order_api.dart';
import 'corporate_api.dart';

int? requestStatusCode(Object error) {
  if (error is AdminPermissionException) return 403;
  if (error is CatalogApiException) return error.statusCode;
  if (error is OrderApiException) return error.statusCode;
  if (error is MediaApiException) return error.statusCode;
  if (error is CorporateApiException) return error.statusCode;
  if (error is AuditLogApiException) return error.statusCode;
  return null;
}

String requestErrorMessage(Object error) {
  final statusCode = requestStatusCode(error);
  if (statusCode == 401) return 'نشست شما منقضی شده است؛ دوباره وارد شوید.';
  if (statusCode == 403) return 'حساب شما اجازهٔ دیدن یا تغییر این بخش را ندارد.';
  if (statusCode == 404) return 'اطلاعات درخواستی پیدا نشد.';
  if (statusCode != null && statusCode >= 500) return 'سرویس موقتاً در دسترس نیست؛ بعداً دوباره تلاش کنید.';
  if (error is CatalogApiException) return error.message;
  if (error is OrderApiException) return error.message;
  if (error is MediaApiException) return error.message;
  if (error is CorporateApiException) return error.message;
  if (error is AuditLogApiException) return error.message;
  return 'ارتباط با سرویس برقرار نشد؛ اتصال و نشانی API را بررسی کنید.';
}

class AdminPermissionException implements Exception {
  const AdminPermissionException(this.permission);

  final String permission;
}

class AdminPermissionGate extends StatelessWidget {
  const AdminPermissionGate({super.key, required this.permission, required this.child});

  final String permission;
  final Widget child;

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
        stream: OwnerSession.instance.changes,
        initialData: OwnerSession.instance.isAuthenticated,
        builder: (context, snapshot) => OwnerSession.instance.isAuthenticated && !OwnerSession.instance.can(permission)
            ? const AdminErrorState(error: AdminPermissionException('forbidden'), onRetry: _noop)
            : child,
      );

  static void _noop() {}
}

class AdminErrorState extends StatelessWidget {
  const AdminErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final forbidden = requestStatusCode(error) == 403;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Icon(
                forbidden ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
                size: 56,
                color: forbidden ? const Color(0xFFF2B866) : const Color(0xFF718078),
              ),
              const SizedBox(height: 14),
              Text(
                forbidden ? 'دسترسی به این بخش محدود است.' : 'بارگذاری اطلاعات انجام نشد.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF19352C)),
              ),
              const SizedBox(height: 8),
              Text(requestErrorMessage(error), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF718078), height: 1.6)),
              const SizedBox(height: 16),
              if (!forbidden)
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('تلاش دوباره')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: const Color(0xFF718078)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF19352C))),
            const SizedBox(height: 5),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF718078), fontSize: 12, height: 1.6)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onAction, icon: const Icon(Icons.arrow_back_rounded), label: Text(actionLabel!)),
            ],
          ],
        ),
      );
}

class AdminStaleBanner extends StatelessWidget {
  const AdminStaleBanner({super.key, required this.detail, required this.onRetry});

  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF4E3),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Icon(Icons.sync_problem_rounded, color: Color(0xFF8C5A15)),
            const SizedBox(width: 10),
            Expanded(child: Text(detail, style: const TextStyle(color: Color(0xFF704A17), fontSize: 12))),
            TextButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
          ]),
        ),
      );
}
