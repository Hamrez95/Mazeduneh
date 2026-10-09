import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_state.dart';
import 'admin_permissions.dart';
import 'admin_users_api.dart';
import 'auth_session.dart';
import 'formatters.dart';
import 'admin_theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, this.api});

  final AdminUsersApiClient? api;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late final AdminUsersApiClient api = widget.api ?? AdminUsersApiClient();
  List<AdminUser> users = const [];
  List<AdminRole> roles = const [];
  Object? error;
  bool loading = true;
  String? changingUserId;
  DateTime? lastLoadedAt;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([api.fetchUsers(), api.fetchRoles()]);
      if (!mounted) return;
      setState(() {
        users = results[0] as List<AdminUser>;
        roles = results[1] as List<AdminRole>;
        lastLoadedAt = DateTime.now();
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && users.isEmpty) return const Center(child: CircularProgressIndicator());
    if (error != null && users.isEmpty) return AdminErrorState(error: error!, onRetry: load);

    return RefreshIndicator(
      onRefresh: load,
      child: LayoutBuilder(
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _UsersHeader(lastLoadedAt: lastLoadedAt, loading: loading, onRefresh: load, onCreate: roles.where((role) => role.role != 'Owner').isEmpty ? null : _openCreateDialog),
            if (error != null) ...[
              const SizedBox(height: 14),
              AdminStaleBanner(detail: 'فهرست نمایش‌داده‌شده ممکن است تازه نباشد. ${requestErrorMessage(error!)}', onRetry: load),
            ],
            const SizedBox(height: 20),
            if (users.isEmpty)
              Card(
                child: AdminEmptyState(
                  icon: Icons.manage_accounts_outlined,
                  title: 'هنوز کاربر دیگری برای این فروشگاه ثبت نشده است',
                  detail: 'یک همکار اضافه کنید و فقط دسترسی‌های لازم برای کار روزانه‌اش را به او بدهید.',
                  actionLabel: roles.where((role) => role.role != 'Owner').isEmpty ? null : 'افزودن کاربر',
                  onAction: roles.where((role) => role.role != 'Owner').isEmpty ? null : _openCreateDialog,
                ),
              )
            else
              _UsersList(users: users, changingUserId: changingUserId, onToggle: _toggleStatus, onEditPermissions: _editPermissions),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final draft = await showDialog<AdminUserDraft>(
      context: context,
      builder: (_) => _CreateUserDialog(roles: roles.where((role) => role.role != 'Owner').toList()),
    );
    if (draft == null || !mounted) return;
    try {
      final invitation = await api.createUser(email: draft.email, displayName: draft.displayName, role: draft.role, permissions: draft.permissions);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('دعوت آماده است'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('پیوند فعال‌سازی برای ${invitation.user.email} فقط یک بار قابل استفاده است و تا ${formatPersianDateTime(invitation.expiresAt)} اعتبار دارد.'),
              const SizedBox(height: 14),
              SelectableText(invitation.shareUrl, textDirection: TextDirection.ltr),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('بستن')),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invitation.shareUrl));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پیوند دعوت کپی شد.')));
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('کپی پیوند'),
            ),
          ],
        ),
      );
      await load();
    } on AdminUsersApiException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }

  Future<void> _editPermissions(AdminUser user) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _PermissionsDialog(
        initialPermissions: user.permissions,
        onSave: (permissions) async {
          try {
            await api.setPermissions(user.id, permissions);
            await load();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دسترسی‌های کاربر به‌روزرسانی شد.')));
            return null;
          } on AdminUsersApiException catch (exception) {
            return exception.message;
          } catch (_) {
            return 'ارتباط با سرور برقرار نشد؛ انتخاب‌ها را بررسی و دوباره تلاش کنید.';
          }
        },
      ),
    );
  }

  Future<void> _toggleStatus(AdminUser user) async {
    if (user.email == OwnerSession.instance.email) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برای جلوگیری از قطع دسترسی، مدیر اصلی از این صفحه غیرفعال نمی‌شود.')));
      return;
    }
    final nextStatus = !user.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nextStatus ? 'فعال‌سازی دسترسی؟' : 'غیرفعال‌سازی دسترسی؟'),
        content: Text(nextStatus ? 'دسترسی ${user.displayName} دوباره فعال می‌شود.' : 'این کاربر دیگر نمی‌تواند عملیات مدیریتی انجام دهد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(nextStatus ? 'فعال‌سازی' : 'غیرفعال‌سازی')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => changingUserId = user.id);
    try {
      await api.setStatus(user.id, nextStatus);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(nextStatus ? 'دسترسی کاربر فعال شد.' : 'دسترسی کاربر غیرفعال شد.')));
      await load();
    } on AdminUsersApiException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    } finally {
      if (mounted) setState(() => changingUserId = null);
    }
  }
}

class _UsersHeader extends StatelessWidget {
  const _UsersHeader({required this.lastLoadedAt, required this.loading, required this.onRefresh, required this.onCreate});

  final DateTime? lastLoadedAt;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final actions = Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('افزودن کاربر')),
            IconButton(onPressed: loading ? null : onRefresh, tooltip: 'بارگذاری مجدد', icon: const Icon(Icons.refresh_rounded)),
          ]);
          final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('کاربران و دسترسی‌ها', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AdminColors.inkDeep))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AdminColors.mintSoft, borderRadius: BorderRadius.circular(20)), child: const Text('فقط Owner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.ink))),
            ]),
            const SizedBox(height: 6),
            const Text('همکاران را اضافه کنید، نقش مناسب بدهید و دسترسی‌های فعال را در یک نگاه ببینید.', style: TextStyle(color: AdminColors.muted, height: 1.5)),
            if (lastLoadedAt != null) ...[
              const SizedBox(height: 5),
              Text('آخرین به‌روزرسانی: ${formatPersianDateTime(lastLoadedAt!)}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
            ],
          ]);
          return constraints.maxWidth < 620 ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [actions, const SizedBox(height: 12), title]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: title), actions]);
        },
      );
}

class _UsersList extends StatelessWidget {
  const _UsersList({required this.users, required this.changingUserId, required this.onToggle, required this.onEditPermissions});

  final List<AdminUser> users;
  final String? changingUserId;
  final ValueChanged<AdminUser> onToggle;
  final ValueChanged<AdminUser> onEditPermissions;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final user in users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 1024;
                      final identity = Row(children: [
                        CircleAvatar(backgroundColor: user.isActive ? AdminColors.mintSoft : const Color(0xFFF0ECE8), foregroundColor: AdminColors.inkDeep, child: Text(user.displayName.isEmpty ? '؟' : user.displayName.substring(0, 1))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)), const SizedBox(height: 4), Text(user.email, textDirection: TextDirection.ltr, style: const TextStyle(color: AdminColors.muted))])),
                      ]);
                      final details = Wrap(spacing: 8, runSpacing: 8, children: [
                        _Chip(label: user.roleLabel, color: AdminColors.mintSoft),
                        _Chip(label: user.isActive ? 'فعال' : 'غیرفعال', color: user.isActive ? const Color(0xFFE6F5E8) : const Color(0xFFF0ECE8)),
                        if (user.role != 'Owner' && !user.hasPassword)
                          const _Chip(label: 'در انتظار فعال‌سازی', color: Color(0xFFFFF2D9)),
                        _Chip(label: '${formatPersianInteger(user.permissions.length)} دسترسی', color: const Color(0xFFF6F3EC)),
                      ]);
                      final isOwner = user.role == 'Owner' || user.email == OwnerSession.instance.email;
                      final action = changingUserId == user.id
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : Wrap(spacing: 4, children: [
                              if (!isOwner) TextButton.icon(onPressed: () => onEditPermissions(user), icon: const Icon(Icons.tune_rounded), label: const Text('دسترسی‌ها')),
                              if (isOwner) const Tooltip(message: 'مدیر اصلی قابل ویرایش نیست', child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.lock_outline_rounded, color: AdminColors.muted)))
                              else TextButton.icon(onPressed: () => onToggle(user), icon: Icon(user.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded), label: Text(user.isActive ? 'غیرفعال‌سازی' : 'فعال‌سازی')),
                            ]);
                      return compact ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 14), details, const SizedBox(height: 10), Align(alignment: AlignmentDirectional.centerEnd, child: action)]) : Row(children: [Expanded(child: identity), const SizedBox(width: 18), details, const SizedBox(width: 18), action]);
                    },
                  ),
                ),
              ),
            ),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)), child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.inkDeep)));
}

class AdminUserDraft {
  const AdminUserDraft({required this.email, required this.displayName, required this.role, required this.permissions});
  final String email;
  final String displayName;
  final String role;
  final List<String> permissions;
}

class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog({required this.roles});
  final List<AdminRole> roles;

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final displayName = TextEditingController();
  String? role;
  Set<String> permissions = {};

  @override
  void initState() {
    super.initState();
    role = widget.roles.isEmpty ? null : widget.roles.first.role;
    if (widget.roles.isNotEmpty) permissions = widget.roles.first.permissions.toSet();
  }

  @override
  void dispose() {
    email.dispose();
    displayName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('افزودن کاربر'),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width < 560 ? MediaQuery.sizeOf(context).width - 40 : 500,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .72),
            child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('برای شروع فقط اطلاعات ضروری را وارد کنید؛ رمز عبور و token در این صفحه ذخیره نمی‌شود.', style: TextStyle(fontSize: 12, color: AdminColors.muted, height: 1.6)),
                const SizedBox(height: 16),
                TextFormField(controller: displayName, autofocus: true, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'نام نمایشی', hintText: 'مثلاً سارا احمدی'), validator: (value) => value == null || value.trim().isEmpty ? 'نام نمایشی را وارد کنید.' : null),
                const SizedBox(height: 12),
                TextFormField(controller: email, textDirection: TextDirection.ltr, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'ایمیل کاری', hintText: 'name@example.com'), validator: (value) => value == null || !value.contains('@') ? 'ایمیل معتبر وارد کنید.' : null),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(value: role, menuMaxHeight: 300, decoration: const InputDecoration(labelText: 'نقش پیشنهادی'), items: [for (final item in widget.roles) DropdownMenuItem(value: item.role, child: Text(item.titleFa))], onChanged: (value) { if (value == null) return; setState(() { role = value; permissions = widget.roles.firstWhere((item) => item.role == value).permissions.toSet(); }); }, validator: (value) => value == null ? 'یک نقش انتخاب کنید.' : null),
                if (role != null) ...[
                  const SizedBox(height: 10),
                  Text('دسترسی‌های نقش پیشنهادی را می‌توانید برای همین همکار تغییر دهید.', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                  const SizedBox(height: 8),
                  _PermissionChecklist(selected: permissions, onChanged: (value) => setState(() => permissions = value)),
                ],
              ]),
            ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(onPressed: () { if (formKey.currentState?.validate() != true || role == null) return; Navigator.pop(context, AdminUserDraft(email: email.text, displayName: displayName.text, role: role!, permissions: permissions.toList())); }, child: const Text('افزودن کاربر')),
        ],
      );
}

class _PermissionsDialog extends StatefulWidget {
  const _PermissionsDialog({required this.initialPermissions, required this.onSave});
  final List<String> initialPermissions;
  final Future<String?> Function(List<String> permissions) onSave;
  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  late Set<String> permissions = widget.initialPermissions.toSet();
  bool saving = false;
  String? error;

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    final message = await widget.onSave(permissions.toList());
    if (!mounted) return;
    if (message == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      saving = false;
      error = message;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('دسترسی‌های همکار'),
        content: SizedBox(width: MediaQuery.sizeOf(context).width < 560 ? MediaQuery.sizeOf(context).width - 40 : 500, child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .72), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PermissionChecklist(selected: permissions, onChanged: (value) => setState(() { permissions = value; error = null; })),
          if (error != null) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: Text(error!, style: const TextStyle(color: AdminColors.coral, fontSize: 12))),
          ],
        ])))),
        actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('ذخیره دسترسی‌ها'))],
      );
}

class _PermissionChecklist extends StatelessWidget {
  const _PermissionChecklist({required this.selected, required this.onChanged});
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final group in AdminPermissions.groups.entries) ...[
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(group.key, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.inkDeep))),
          for (final permission in group.value)
            CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: Text(permission.label), subtitle: Text(permission.description, style: const TextStyle(fontSize: 11)), value: selected.contains(permission.key), onChanged: (checked) { final next = {...selected}; checked == true ? next.add(permission.key) : next.remove(permission.key); onChanged(next); }),
        ],
      ]);
}
