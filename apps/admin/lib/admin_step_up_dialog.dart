import 'package:flutter/material.dart';

import 'auth_api.dart';

Future<String?> showAdminStepUpDialog(
  BuildContext context, {
  AuthApiClient? auth,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _AdminStepUpDialog(auth: auth ?? AuthApiClient()),
    );

class _AdminStepUpDialog extends StatefulWidget {
  const _AdminStepUpDialog({required this.auth});
  final AuthApiClient auth;

  @override
  State<_AdminStepUpDialog> createState() => _AdminStepUpDialogState();
}

class _AdminStepUpDialogState extends State<_AdminStepUpDialog> {
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> confirm() async {
    if (busy || password.text.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final token = await widget.auth.stepUp(password: password.text);
      if (mounted) Navigator.pop(context, token);
    } on AuthApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'تأیید هویت انجام نشد؛ اتصال را بررسی و دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('تأیید دوبارهٔ هویت'),
      scrollable: true,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('برای اعمال تغییر حساس، رمز عبور حساب فعلی را دوباره وارد کنید.'),
            const SizedBox(height: 14),
            TextField(
              controller: password,
              autofocus: true,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => confirm(),
              decoration: const InputDecoration(
                labelText: 'رمز عبور فعلی',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Semantics(liveRegion: true, child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('انصراف'),
        ),
        FilledButton.icon(
          onPressed: busy || password.text.isEmpty ? null : confirm,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('تأیید هویت'),
        ),
      ],
    ),
  );
}
