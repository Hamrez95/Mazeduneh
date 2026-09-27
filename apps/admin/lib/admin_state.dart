import 'package:flutter/material.dart';

import 'catalog_api.dart';
import 'media_api.dart';
import 'order_api.dart';

int? requestStatusCode(Object error) {
  if (error is CatalogApiException) return error.statusCode;
  if (error is OrderApiException) return error.statusCode;
  if (error is MediaApiException) return error.statusCode;
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
  return 'ارتباط با سرویس برقرار نشد؛ اتصال و نشانی API را بررسی کنید.';
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
    );
  }
}
