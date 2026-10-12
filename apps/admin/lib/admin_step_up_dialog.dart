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
  final totpCode = TextEditingController();
  final totpFocus = FocusNode();
  bool busy = false;
  String? error;

  bool get requiresTotp =>
      OwnerSession.instance.role == null ||
      OwnerSession.instance.role!.toLowerCase() == 'owner';

  @override
  void dispose() {
    password.dispose();
    totpCode.dispose();
    totpFocus.dispose();
    super.dispose();
  }

  Future<void> confirm() async {
    if (busy ||
        password.text.isEmpty ||
        (requiresTotp && !_isSixAsciiDigits(totpCode.text)))
      return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final token = await widget.auth.stepUp(
        password: password.text,
        totpCode: requiresTotp ? totpCode.text : null,
      );
      if (mounted) Navigator.pop(context, token);
    } on AuthApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted)
        setState(
          () => error =
              'تأیید هویت انجام نشد؛ اتصال را بررسی و دوباره تلاش کنید.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void updateTotpCode(String value) {
    final normalized = _normalizeDigits(value);
    if (normalized != value) {
      totpCode.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    setState(() {});
  }

  bool _isSixAsciiDigits(String value) =>
      value.length == 6 &&
      value.codeUnits.every((digit) => digit >= 48 && digit <= 57);

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
            const Text(
              'برای اعمال تغییر حساس، رمز عبور حساب فعلی را دوباره وارد کنید.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: password,
              autofocus: true,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) =>
                  requiresTotp ? totpFocus.requestFocus() : confirm(),
              decoration: const InputDecoration(
                labelText: 'رمز عبور فعلی',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            if (requiresTotp) ...[
              const SizedBox(height: 12),
              TextField(
                controller: totpCode,
                focusNode: totpFocus,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                maxLength: 6,
                onChanged: updateTotpCode,
                onSubmitted: (_) => confirm(),
                decoration: const InputDecoration(
                  labelText: 'کد شش‌رقمی برنامهٔ تأیید',
                  helperText: 'فقط برای این اقدام حساس لازم است.',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
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
          onPressed:
              busy ||
                  password.text.isEmpty ||
                  (requiresTotp && !_isSixAsciiDigits(totpCode.text))
              ? null
              : confirm,
          icon: const Icon(Icons.verified_user_outlined),
          label: const Text('تأیید هویت'),
        ),
      ],
    ),
  );
}
