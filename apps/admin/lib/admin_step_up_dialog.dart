import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_session.dart';

Future<String?> showAdminStepUpDialog(
  BuildContext context, {
  AuthApiClient? auth,
}) async {
  final cachedToken = OwnerSession.instance.validStepUpToken;
  if (cachedToken != null) return cachedToken;
  return showDialog<String>(
    context: context,
    builder: (_) => _AdminStepUpDialog(auth: auth ?? AuthApiClient()),
  );
}

class _AdminStepUpDialog extends StatefulWidget {
  const _AdminStepUpDialog({required this.auth});
  final AuthApiClient auth;

  @override
  State<_AdminStepUpDialog> createState() => _AdminStepUpDialogState();
}

class _AdminStepUpDialogState extends State<_AdminStepUpDialog> {
  final password = TextEditingController();
  final mfaCode = TextEditingController();
  final mfaFocus = FocusNode();
  bool busy = false;
  bool mfaRequired = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    mfaCode.dispose();
    mfaFocus.dispose();
    super.dispose();
  }

  Future<void> confirm() async {
    if (busy || password.text.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final token = await widget.auth.stepUp(
        password: password.text,
        mfaCode: mfaRequired ? mfaCode.text : null,
      );
      if (mounted) Navigator.pop(context, token);
    } on AuthApiException catch (exception) {
      if (mounted) {
        setState(() {
          if (exception.statusCode == 428) mfaRequired = true;
          error = exception.message;
        });
        if (exception.statusCode == 428) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) mfaFocus.requestFocus();
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => error = 'تأیید هویت انجام نشد؛ اتصال را بررسی و دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void updateMfaCode(String value) {
    final normalized = _normalizeDigits(value);
    if (normalized != value) {
      mfaCode.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    setState(() {});
  }

  String _normalizeDigits(String value) => String.fromCharCodes(
    value.runes.map((rune) {
      if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
      if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
      return rune;
    }),
  );

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
              onSubmitted: (_) => mfaRequired ? mfaFocus.requestFocus() : confirm(),
              decoration: const InputDecoration(
                labelText: 'رمز عبور فعلی',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            if (mfaRequired) ...[
              const SizedBox(height: 14),
              TextField(
                controller: mfaCode,
                focusNode: mfaFocus,
                autofocus: true,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                onChanged: updateMfaCode,
                onSubmitted: (_) => confirm(),
                decoration: const InputDecoration(
                  labelText: 'کد شش‌رقمی برنامهٔ تأیید',
                  helperText: 'کد برنامهٔ احراز هویت را وارد کنید.',
                  counterText: '',
                  prefixIcon: Icon(Icons.security_rounded),
                ),
              ),
            ],
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
          onPressed: busy || password.text.isEmpty || (mfaRequired && mfaCode.text.trim().length != 6) ? null : confirm,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('تأیید هویت'),
        ),
      ],
    ),
  );
}
