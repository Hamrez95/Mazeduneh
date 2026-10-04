import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_session.dart';

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key, required this.child, this.api});

  final Widget child;
  final AuthApiClient? api;

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  late final AuthApiClient api = widget.api ?? AuthApiClient();
  StreamSubscription<bool>? subscription;
  String? invitationToken;

  @override
  void initState() {
    super.initState();
    subscription = OwnerSession.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
    invitationToken = _readInvitationToken(Uri.base.fragment);
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (OwnerSession.instance.isAuthenticated) return widget.child;
    final token = invitationToken;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: token == null
          ? _AdminLoginPage(api: api)
          : _InvitationPage(
              api: api,
              onAccepted: () => setState(() => invitationToken = null),
            ),
    );
  }

  String? _readInvitationToken(String fragment) {
    if (fragment.isEmpty) return null;
    try {
      final token = Uri.splitQueryString(fragment)['invite']?.trim();
      return token == null || token.isEmpty ? null : token;
    } on FormatException {
      return null;
    }
  }
}

class _AdminLoginPage extends StatefulWidget {
  const _AdminLoginPage({required this.api});
  final AuthApiClient api;

  @override
  State<_AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<_AdminLoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (formKey.currentState?.validate() != true || submitting) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.api.login(email: email.text, password: password.text);
      await widget.api.validateSession();
    } on AuthApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'ارتباط با سرور برقرار نشد. دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        eyebrow: 'پنل مدیریت مزه‌دونه',
        title: 'خوش آمدید',
        detail: 'برای ادامه، با حساب کاربری فروشگاه وارد شوید.',
        child: Form(
          key: formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: email,
              autofocus: true,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              decoration: const InputDecoration(labelText: 'ایمیل کاری'),
              validator: (value) => value == null || !value.contains('@') ? 'ایمیل معتبر وارد کنید.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => submit(),
              decoration: const InputDecoration(labelText: 'رمز عبور'),
              validator: (value) => value == null || value.isEmpty ? 'رمز عبور را وارد کنید.' : null,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              _AuthMessage(text: error!, isError: true),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: submitting ? null : submit,
              child: submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('ورود به پنل'),
            ),
          ]),
        ),
      );
}

class _InvitationPage extends StatefulWidget {
  const _InvitationPage({required this.api, required this.onAccepted});
  final AuthApiClient api;
  final VoidCallback onAccepted;

  @override
  State<_InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<_InvitationPage> {
  final formKey = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool submitting = false;
  bool accepted = false;
  String? error;

  String get token => _readToken(Uri.base.fragment);

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (formKey.currentState?.validate() != true || submitting) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.api.acceptInvitation(token: token, password: password.text);
      if (mounted) setState(() => accepted = true);
    } on AuthApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } catch (_) {
      if (mounted) setState(() => error = 'ارتباط با سرور برقرار نشد. دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        eyebrow: 'دعوت همکار',
        title: accepted ? 'حساب شما فعال شد' : 'ساخت رمز عبور',
        detail: accepted
            ? 'اکنون می‌توانید با ایمیل دعوت‌شده وارد پنل شوید.'
            : 'یک رمز عبور قوی انتخاب کنید تا دعوت شما فعال شود.',
        child: accepted
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const _AuthMessage(text: 'دعوت با موفقیت پذیرفته شد.', isError: false),
                const SizedBox(height: 18),
                FilledButton(onPressed: widget.onAccepted, child: const Text('رفتن به صفحه ورود')),
              ])
            : Form(
                key: formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(
                    controller: password,
                    autofocus: true,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(labelText: 'رمز عبور جدید'),
                    validator: (value) => value == null || value.length < 12
                        ? 'رمز عبور باید دست‌کم ۱۲ نویسه باشد.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmation,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submit(),
                    decoration: const InputDecoration(labelText: 'تکرار رمز عبور'),
                    validator: (value) => value != password.text ? 'تکرار رمز عبور یکسان نیست.' : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    _AuthMessage(text: error!, isError: true),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: submitting ? null : submit,
                    child: submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('فعال‌سازی حساب'),
                  ),
                ]),
              ),
      );
}

String _readToken(String fragment) {
  try {
    return Uri.splitQueryString(fragment)['invite'] ?? '';
  } on FormatException {
    return '';
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.eyebrow, required this.title, required this.detail, required this.child});

  final String eyebrow;
  final String title;
  final String detail;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F8F4),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFE3E8E1)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Color(0xFFDDEFE5),
                      child: Icon(Icons.spa_rounded, color: Color(0xFF19352C)),
                    ),
                    const SizedBox(height: 22),
                    Text(eyebrow, style: const TextStyle(color: Color(0xFF718078), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF19352C))),
                    const SizedBox(height: 8),
                    Text(detail, style: const TextStyle(color: Color(0xFF718078), height: 1.6)),
                    const SizedBox(height: 24),
                    child,
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? const Color(0xFFFFEAE5) : const Color(0xFFE6F5E8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: TextStyle(color: isError ? const Color(0xFF8F3023) : const Color(0xFF24463A))),
      );
}
