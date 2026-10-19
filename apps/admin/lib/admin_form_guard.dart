import 'package:flutter/material.dart';

Future<bool> confirmDiscardAdminChanges(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغییرات ذخیره نشده‌اند'),
        content: const Text('اگر خارج شوید، تغییرات این فرم دور ریخته می‌شوند.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ماندن در فرم'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('دورریختن تغییرات'),
          ),
        ],
      ),
    ) ??
    false;

