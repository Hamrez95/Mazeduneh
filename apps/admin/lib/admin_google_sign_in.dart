import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_theme.dart';
import 'auth_api.dart';
import 'google_identity_button.dart';

class AdminGoogleSignIn extends StatefulWidget {
  const AdminGoogleSignIn({
    super.key,
    required this.api,
    required this.onAuthenticated,
    this.invitationToken,
  });

  final AuthApiClient api;
  final VoidCallback onAuthenticated;
  final String? invitationToken;

  @override
  State<AdminGoogleSignIn> createState() => _AdminGoogleSignInState();
}

class _AdminGoogleSignInState extends State<AdminGoogleSignIn> {
  final password = TextEditingController();
  final mfaCode = TextEditingController();
  AdminGoogleAuthConfig? config;
  AdminGoogleAuthChallenge? challenge;
  String? credential;
  String? linkEmail;
  String? error;
  bool loading = true;
  bool submitting = false;
  bool mfaRequired = false;

  bool get invitationFlow => widget.invitationToken != null;
  bool get linkRequired => linkEmail != null;
  bool get hasPendingCredential => credential != null && challenge != null;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    password.dispose();
    mfaCode.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (loading && config != null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final nextConfig = await widget.api.googleAuthConfig();
      if (!mounted) return;
      if (!nextConfig.enabled || nextConfig.clientId == null || !kIsWeb) {
        setState(() {
          config = nextConfig;
          challenge = null;
          credential = null;
          loading = false;
        });
        return;
      }
      final nextChallenge = await widget.api.createGoogleAuthChallenge();
      if (!mounted) return;
      setState(() {
        config = nextConfig;
        challenge = nextChallenge;
        credential = null;
        linkEmail = null;
        mfaRequired = false;
        password.clear();
        mfaCode.clear();
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        config = const AdminGoogleAuthConfig(enabled: false);
        challenge = null;
        loading = false;
        error = exception is AuthApiException
            ? exception.message
            : 'آماده‌سازی ورود با گوگل انجام نشد.';
      });
    }
  }

  Future<void> _onCredential(String value) async {
    if (submitting || challenge == null) return;
    setState(() {
      credential = value;
      error = null;
    });
    await _continue();
  }

  Future<void> _continue() async {
    final currentCredential = credential;
    final currentChallenge = challenge;
    if (currentCredential == null || currentChallenge == null || submitting)
      return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      if (invitationFlow) {
        await widget.api.acceptInvitationWithGoogle(
          credential: currentCredential,
          challengeId: currentChallenge.id,
          invitationToken: widget.invitationToken!,
          mfaCode: mfaRequired ? mfaCode.text : null,
        );
        if (!mounted) return;
        widget.onAuthenticated();
        return;
      }

      final result = await widget.api.loginWithGoogle(
        credential: currentCredential,
        challengeId: currentChallenge.id,
        password: linkRequired ? password.text : null,
        mfaCode: mfaRequired ? mfaCode.text : null,
      );
      if (!mounted) return;
      if (result.status == 'link_required') {
        setState(() => linkEmail = result.email ?? '');
      } else {
        widget.onAuthenticated();
      }
    } on AuthApiException catch (exception) {
      if (!mounted) return;
      setState(() {
        if (exception.statusCode == 428) mfaRequired = true;
        error = exception.message;
      });
    } catch (_) {
      if (mounted)
        setState(() => error = 'ارتباط با سرور برقرار نشد؛ دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientId = config?.clientId;
    final canRenderButton =
        !loading &&
        config?.enabled == true &&
        clientId != null &&
        challenge != null &&
        credential == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canRenderButton)
          buildGoogleIdentityButton(
            key: ValueKey(challenge!.nonce),
            clientId: clientId,
            nonce: challenge!.nonce,
            onCredential: _onCredential,
            onError: (message) {
              if (mounted) setState(() => error = message);
            },
          )
        else if (loading || (config?.enabled == true && submitting))
          _GoogleButtonPlaceholder(
            label: submitting
                ? 'در حال تأیید حساب گوگل…'
                : 'در حال آماده‌سازی گوگل…',
            loading: true,
          )
        else if (config?.enabled != true)
          const _GoogleButtonPlaceholder(
            label: 'ادامه با گوگل',
            loading: false,
          ),
        if (!loading && config?.enabled != true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'ورود با گوگل هنوز تنظیم نشده است؛ می‌توانید با ایمیل وارد شوید.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AdminColors.muted, fontSize: 12),
            ),
          ),
        if (hasPendingCredential && linkRequired) ...[
          const SizedBox(height: 14),
          _GoogleIdentityMessage(
            text:
                'این ایمیل حساب فعال دارد. برای اتصال امن گوگل، رمز همان حساب را وارد کنید.',
            success: false,
          ),
          if (linkEmail!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(linkEmail!, textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: password,
            obscureText: true,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'رمز حساب فعلی'),
          ),
        ],
        if (hasPendingCredential && mfaRequired) ...[
          const SizedBox(height: 14),
          TextField(
            controller: mfaCode,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'کد تأیید دومرحله‌ای',
              helperText: 'کد ۶ رقمی برنامهٔ احراز هویت را وارد کنید.',
              counterText: '',
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          _GoogleIdentityMessage(text: error!, success: false),
        ],
        if (hasPendingCredential && (linkRequired || mfaRequired)) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: submitting ? null : _continue,
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(linkRequired ? 'اتصال گوگل و ادامه' : 'تأیید و ورود'),
          ),
        ],
        if (error != null && !loading && !hasPendingCredential) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _prepare,
            child: const Text('تلاش دوباره با گوگل'),
          ),
        ],
        const SizedBox(height: 18),
        _GoogleMethodDivider(
          label: invitationFlow ? 'یا با رمز عبور' : 'یا با ایمیل',
        ),
      ],
    );
  }
}

class _GoogleButtonPlaceholder extends StatelessWidget {
  const _GoogleButtonPlaceholder({required this.label, required this.loading});
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: null,
    icon: loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.g_mobiledata_rounded, size: 24),
    label: Text(label),
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
  );
}

class _GoogleMethodDivider extends StatelessWidget {
  const _GoogleMethodDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: TextStyle(color: AdminColors.muted, fontSize: 12),
        ),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

class _GoogleIdentityMessage extends StatelessWidget {
  const _GoogleIdentityMessage({required this.text, required this.success});
  final String text;
  final bool success;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: success ? AdminColors.successSoft : AdminColors.dangerSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(color: success ? AdminColors.ink : AdminColors.coral),
    ),
  );
}
