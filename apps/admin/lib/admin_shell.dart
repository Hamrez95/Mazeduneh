import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_theme.dart';
import 'admin_users_page.dart';
import 'audit_log_page.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'catalog_page.dart';
import 'catalog_api.dart';
import 'admin_navigation.dart';
import 'admin_mfa_settings_dialog.dart';
import 'commerce_settings_page.dart';
import 'corporate_requests_page.dart';
import 'customer_management_page.dart';
import 'dashboard_page.dart';
import 'inventory_page.dart';
import 'notifications_page.dart';
import 'order_api.dart';
import 'orders_page.dart';
import 'reports_page.dart';
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.dashboardApi, this.ordersApi, this.catalogApi});
  final OrderApiClient? dashboardApi;
  final OrderApiClient? ordersApi;
  final CatalogApiClient? catalogApi;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  var index = 0;
  var navigation = const AdminNavigationIntent(module: AdminModule.dashboard);
  final navigationHistory = <AdminNavigationIntent>[];
  final catalogKey = GlobalKey<CatalogPageState>();

  @override
  void initState() {
    super.initState();
    if (OwnerSession.instance.isAuthenticated) {
      final firstAllowed = AdminModule.values.indexWhere(
        (module) => OwnerSession.instance.can(module.permission),
      );
      if (firstAllowed >= 0) index = firstAllowed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final visibleModules = [
      for (final module in AdminModule.values)
        if (!OwnerSession.instance.isAuthenticated || OwnerSession.instance.can(module.permission)) module,
    ];
    final primaryModules = visibleModules.take(4).toList();
    final secondaryModules = visibleModules.skip(4).toList();
    final selectedPrimary = primaryModules.indexWhere((module) => AdminModule.values.indexOf(module) == index);
    final pages = [for (final module in AdminModule.values) _modulePage(module)];
    return PopScope<Object?>(
      canPop: navigationHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
      child: Scaffold(
      appBar: desktop ? null : AppBar(
        leading: navigationHistory.isEmpty ? null : IconButton(tooltip: 'بازگشت به ${_moduleLabel(navigationHistory.last.module)}', onPressed: _goBack, icon: const Icon(Icons.arrow_back_rounded)),
        title: const Brand(compact: true),
        actions: [IconButton(
          tooltip: 'تنظیم تأیید دومرحله‌ای',
          onPressed: () => showAdminMfaSettingsDialog(context),
          icon: const Icon(Icons.security_rounded),
        )],
      ),
      bottomNavigationBar: desktop || visibleModules.isEmpty
          ? null
          : visibleModules.length == 1
          ? BottomAppBar(
              child: SafeArea(
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Semantics(
                      label: 'بخش فعال: ${visibleModules.single.label}',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            visibleModules.single.icon,
                            color: AdminColors.ink,
                          ),
                          const SizedBox(width: 8),
                          Text(visibleModules.single.label),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : NavigationBar(
              selectedIndex: secondaryModules.isNotEmpty ? (selectedPrimary < 0 ? primaryModules.length : selectedPrimary) : (selectedPrimary < 0 ? 0 : selectedPrimary),
              onDestinationSelected: (value) => secondaryModules.isNotEmpty && value == primaryModules.length
                  ? _openMoreMenu(secondaryModules)
                  : _selectModule(AdminModule.values.indexOf(primaryModules[value])),
              destinations: [
                for (final module in primaryModules)
                  NavigationDestination(icon: Icon(module.icon), label: module.label),
                if (secondaryModules.isNotEmpty)
                  const NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'بیشتر'),
              ],
            ),
      body: Row(children: [
        if (desktop)
          Container(
            width: 245,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AdminColors.inkDeep, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x1424463A), blurRadius: 24, offset: Offset(0, 10))]),
            child: Column(children: [
              const Padding(padding: EdgeInsets.all(12), child: Brand(dark: true)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final module in visibleModules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      selected: index == AdminModule.values.indexOf(module),
                      selectedTileColor: AdminColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(
                        module.icon,
                        color: index == AdminModule.values.indexOf(module)
                            ? Colors.white
                            : const Color(0xFFBFD0C5),
                      ),
                      title: Text(
                        module.label,
                        style: TextStyle(
                          color: index == AdminModule.values.indexOf(module)
                              ? Colors.white
                              : const Color(0xFFD5DFD6),
                        ),
                      ),
                      onTap: () => _selectModule(AdminModule.values.indexOf(module)),
                    ),
                  ),
                ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF7C58B),
                    child: Text(
                      (OwnerSession.instance.email ?? 'م')
                          .substring(0, 1)
                          .toUpperCase(),
                    ),
                  ),
                  title: Text(
                    OwnerSession.instance.email ?? 'کاربر فروشگاه',
                    style: const TextStyle(color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    OwnerSession.instance.role == 'Owner'
                        ? 'مدیر اصلی'
                        : 'عضو فروشگاه · ${OwnerSession.instance.role ?? ''}',
                    style: const TextStyle(color: Color(0xFF9EACA1)),
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'تنظیم تأیید دومرحله‌ای',
                      onPressed: () => showAdminMfaSettingsDialog(context),
                      icon: const Icon(Icons.security_rounded, color: Color(0xFFD5DFD6)),
                    ),
                    IconButton(
                      tooltip: 'خروج از حساب',
                      onPressed: () async {
                        try {
                          await AuthApiClient().logout();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('از این دستگاه خارج شدید؛ ارتباط با سرور قطع بود.')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, color: Color(0xFFD5DFD6)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        Expanded(child: SafeArea(child: IndexedStack(index: index, children: pages))),
      ]),
      floatingActionButton: index == AdminModule.products.index
          ? FloatingActionButton.extended(
              onPressed: () => catalogKey.currentState?.openCreateDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('محصول جدید'),
            )
      : null,
      ),
    );
  }

  void _navigate(AdminNavigationIntent intent) {
    final session = OwnerSession.instance;
    if (session.isAuthenticated && !session.can(intent.module.permission)) return;
    final destination = AdminModule.values.indexOf(intent.module);
    if (destination < 0 || intent == navigation) return;
    setState(() { navigationHistory.add(navigation); navigation = intent; index = destination; });
  }

  void _selectModule(int destination) {
    if (destination < 0 || destination >= AdminModule.values.length) return;
    setState(() {
      navigationHistory.clear();
      index = destination;
      navigation = AdminNavigationIntent(module: AdminModule.values[destination]);
    });
  }

  void _goBack() {
    if (navigationHistory.isEmpty) return;
    final previous = navigationHistory.removeLast();
    setState(() { navigation = previous; index = AdminModule.values.indexOf(previous.module); });
  }

  String _moduleLabel(AdminModule module) => module.label;

  Future<void> _openMoreMenu(List<AdminModule> secondaryModules) async {
    final selected = await showModalBottomSheet<AdminModule>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text('بخش‌های بیشتر', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ),
            for (final module in secondaryModules)
              ListTile(
                selected: index == AdminModule.values.indexOf(module),
                selectedTileColor: AdminColors.mintSoft,
                leading: Icon(module.icon, color: AdminColors.ink),
                title: Text(module.label),
                trailing: const Icon(Icons.arrow_back_rounded, size: 18),
                onTap: () => Navigator.pop(context, module),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) _selectModule(AdminModule.values.indexOf(selected));
  }

  Widget _modulePage(AdminModule module) => switch (module) {
        AdminModule.dashboard => AdminPermissionGate(permission: module.permission, child: DashboardPage(api: widget.dashboardApi, onNavigate: _navigate)),
        AdminModule.orders => AdminPermissionGate(permission: module.permission, child: OrdersPage(
          key: ValueKey(navigation), api: widget.ordersApi, initialFilter: navigation.orderFilter,
          initialQuery: navigation.query ?? '', initialCreatedFromUtc: navigation.createdFromUtc,
          initialCreatedToUtcExclusive: navigation.createdToUtcExclusive,
        )),
        AdminModule.products => AdminPermissionGate(permission: module.permission, child: CatalogPage(key: catalogKey, onNavigate: _navigate)),
        AdminModule.inventory => AdminPermissionGate(permission: module.permission, child: InventoryPage(key: ValueKey(navigation), catalog: widget.catalogApi, orders: widget.ordersApi, initialSku: navigation.sku, initialBatchCode: navigation.batchCode)),
        AdminModule.reports => AdminPermissionGate(permission: module.permission, child: ReportsPage(
          key: ValueKey(navigation), initialFromUtc: navigation.createdFromUtc,
          initialToUtcExclusive: navigation.createdToUtcExclusive, onNavigate: _navigate,
        )),
        AdminModule.notifications => AdminPermissionGate(permission: module.permission, child: NotificationsPage(onNavigate: _navigate)),
        AdminModule.customers => AdminPermissionGate(permission: module.permission, child: const CustomerManagementPage()),
        AdminModule.pricing => AdminPermissionGate(permission: module.permission, child: const CommerceSettingsPage()),
        AdminModule.corporate => AdminPermissionGate(permission: module.permission, child: const CorporateRequestsPage()),
        AdminModule.audit => AdminPermissionGate(permission: module.permission, child: const AuditLogPage()),
        AdminModule.users => AdminPermissionGate(permission: module.permission, child: const AdminUsersPage()),
      };
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.dark = false, this.compact = false});
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 11 : 15),
        child: Image.asset(
          'assets/mazedooneh-mark.png',
          width: compact ? 34 : 45,
          height: compact ? 34 : 45,
          fit: BoxFit.cover,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: compact
            ? Text(
                'مدیریت مزه‌دونه',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : null,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مدیریت مزه‌دونه',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : null,
                    ),
                  ),
                  Text(
                    'کاتالوگ زنده فروشگاه',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: dark ? const Color(0xFFB9C8BC) : Colors.grey,
                    ),
                  ),
                ],
              ),
      ),
    ],
  );
}

