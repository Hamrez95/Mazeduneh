import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_api.dart';
import 'formatters.dart';

Future<void> showAdminMfaSettingsDialog(
  BuildContext context, {
  AuthApiClient? auth,
}) => showDialog<void>(
  context: context,
  builder: (_) => AdminMfaSettingsDialog(auth: auth ?? AuthApiClient()),
);

class AdminMfaSettingsDialog extends StatefulWidget {
  const AdminMfaSettingsDialog({super.key, required this.auth});
  final AuthApiClient auth;

  @override
  State<AdminMfaSettingsDialog> createState() => _AdminMfaSettingsDialogState();
}

class _AdminMfaSettingsDialogState extends State<AdminMfaSettingsDialog> {
  final password = TextEditingController();
  final code = TextEditingController();
  AdminMfaStatus? status;
  AdminMfaEnrollment? enrollment;
  String? error;
  var loading = true;
  var busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    password.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.auth.getMfaStatus();
      if (mounted)
        setState(() {
          status = result;
          loading = false;
        });
    } catch (exception) {
      if (mounted)
        setState(() {
          error = exception.toString();
          loading = false;
        });
    }
  }

  Future<void> _beginEnrollment() async {
    if (password.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.auth.beginMfaEnrollment(
        password: password.text,
      );
      if (mounted)
        setState(() {
          enrollment = result;
          code.clear();
          busy = false;
        });
    } catch (exception) {
      if (mounted)
        setState(() {
          error = exception.toString();
          busy = false;
        });
    }
  }

  Future<void> _confirmEnrollment() async {
    if (code.text.trim().length != 6) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.auth.confirmMfaEnrollment(code.text);
      if (mounted) {
        setState(() {
          status = const AdminMfaStatus(enabled: true);
          enrollment = null;
          password.clear();
          code.clear();
          busy = false;
        });
      }
    } catch (exception) {
      if (mounted)
        setState(() {
          error = exception.toString();
          busy = false;
        });
    }
  }

  Future<void> _disable() async {
    if (password.text.isEmpty || code.text.trim().length != 6) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.auth.disableMfa(password: password.text, mfaCode: code.text);
      if (mounted)
        setState(() {
          status = const AdminMfaStatus(enabled: false);
          password.clear();
          code.clear();
          busy = false;
        });
    } catch (exception) {
      if (mounted)
        setState(() {
          error = exception.toString();
          busy = false;
        });
    }
  }

  Future<void> _confirmDisable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأیید غیرفعال‌سازی'),
        content: const Text(
          'پس از این کار، ورود حساب با رمز عبور انجام می‌شود تا دوباره تأیید دومرحله‌ای را فعال کنید.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ادامه'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _disable();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تأیید دومرحله‌ای حساب'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'با برنامهٔ احراز هویت، ورود و تأیید عملیات حساس را به کد یک‌بارمصرف محافظت کنید.',
              ),
              const SizedBox(height: 16),
              if (loading)
                const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'در حال دریافت وضعیت',
                  ),
                ),
              if (error != null) ...[
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: busy ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('تلاش دوباره'),
                ),
              ],
              if (!loading && status?.enabled == true) ...[
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('تأیید دومرحله‌ای فعال است'),
                  subtitle: Text(
                    'برای غیرفعال‌کردن، رمز عبور و یک کد تازه از برنامهٔ احراز هویت را وارد کنید.',
                  ),
                ),
                _passwordField(),
                const SizedBox(height: 10),
                _codeField(),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed:
                      busy ||
                          password.text.isEmpty ||
                          code.text.trim().length != 6
                      ? null
                      : _confirmDisable,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_rounded),
                  label: const Text('غیرفعال‌کردن'),
                ),
              ],
              if (!loading &&
                  status != null &&
                  status?.enabled != true &&
                  enrollment == null) ...[
                _passwordField(),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy || password.text.isEmpty
                      ? null
                      : _beginEnrollment,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.shield_outlined),
                  label: const Text('شروع راه‌اندازی'),
                ),
              ],
              if (enrollment != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'این کلید را در برنامهٔ احراز هویت اضافه کنید. تا زمان تأیید، فقط همین یک‌بار نمایش داده می‌شود.',
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            enrollment!.secret,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'کپی کلید',
                          onPressed: () => Clipboard.setData(
                            ClipboardData(text: enrollment!.secret),
                          ),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اعتبار این کلید ده دقیقه است. اگر منقضی شد، راه‌اندازی را دوباره آغاز کنید.',
                ),
                const SizedBox(height: 14),
                _codeField(),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: busy || code.text.trim().length != 6
                      ? null
                      : _confirmEnrollment,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('تأیید و فعال‌سازی'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('بستن'),
        ),
      ],
    );
  }

  Widget _passwordField() => TextField(
    controller: password,
    obscureText: true,
    autofillHints: const [AutofillHints.password],
    decoration: const InputDecoration(
      labelText: 'رمز عبور فعلی',
      prefixIcon: Icon(Icons.key_rounded),
    ),
    onChanged: (_) => setState(() {}),
  );

  Widget _codeField() => TextField(
    controller: code,
    keyboardType: TextInputType.number,
    autofillHints: const [AutofillHints.oneTimeCode],
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩]')),
      const PersianDigitsInputFormatter(),
      LengthLimitingTextInputFormatter(6),
    ],
    textDirection: TextDirection.ltr,
    decoration: const InputDecoration(
      labelText: 'کد ۶ رقمی برنامه',
      prefixIcon: Icon(Icons.pin_outlined),
    ),
    onChanged: (_) => setState(() {}),
  );
}
