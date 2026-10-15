import 'package:flutter/material.dart';

import 'admin_users_api.dart';
import 'admin_theme.dart';
import 'formatters.dart';

enum AdminUserStatusFilter { all, active, invited, inactive }

class AdminUsersFilterBar extends StatelessWidget {
  const AdminUsersFilterBar({
    super.key,
    required this.users,
    required this.searchController,
    required this.status,
    required this.role,
    required this.onStatusChanged,
    required this.onRoleChanged,
    required this.onSearchChanged,
  });

  final List<AdminUser> users;
  final TextEditingController searchController;
  final AdminUserStatusFilter status;
  final String? role;
  final ValueChanged<AdminUserStatusFilter> onStatusChanged;
  final ValueChanged<String?> onRoleChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'پیدا کردن همکار',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AdminColors.inkDeep,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in AdminUserStatusFilter.values)
            ChoiceChip(
              label: Text(
                '${_statusLabel(filter)} (${formatPersianInteger(_count(filter))})',
              ),
              selected: status == filter,
              onSelected: (_) => onStatusChanged(filter),
              selectedColor: AdminColors.mintSoft,
              side: BorderSide(
                color: status == filter ? AdminColors.ink : AdminColors.border,
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 620;
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: isNarrow ? constraints.maxWidth : 340,
                child: TextField(
                  key: const ValueKey('admin-users-search'),
                  controller: searchController,
                  onChanged: onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'نام یا ایمیل',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'پاک‌کردن جست‌وجو',
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              SizedBox(
                width: isNarrow ? constraints.maxWidth : 240,
                child: DropdownButtonFormField<String>(
                  value: role ?? 'all',
                  decoration: const InputDecoration(labelText: 'نقش'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('همهٔ نقش‌ها'),
                    ),
                    for (final roleName in _roles)
                      DropdownMenuItem(
                        value: roleName,
                        child: Text(AdminUsersRoleLabels.of(roleName)),
                      ),
                  ],
                  onChanged: (value) =>
                      onRoleChanged(value == 'all' ? null : value),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );

  List<String> get _roles => users.map((user) => user.role).toSet().toList()
    ..sort(
      (left, right) => AdminUsersRoleLabels.of(
        left,
      ).compareTo(AdminUsersRoleLabels.of(right)),
    );

  int _count(AdminUserStatusFilter filter) =>
      users.where((user) => _matchesStatus(user, filter)).length;

  bool _matchesStatus(AdminUser user, AdminUserStatusFilter filter) =>
      switch (filter) {
        AdminUserStatusFilter.all => true,
        AdminUserStatusFilter.active => user.isActive && user.hasPassword,
        AdminUserStatusFilter.invited => user.isActive && !user.hasPassword,
        AdminUserStatusFilter.inactive => !user.isActive,
      };

  String _statusLabel(AdminUserStatusFilter filter) => switch (filter) {
    AdminUserStatusFilter.all => 'همه',
    AdminUserStatusFilter.active => 'فعال',
    AdminUserStatusFilter.invited => 'دعوت‌شده',
    AdminUserStatusFilter.inactive => 'غیرفعال',
  };
}
