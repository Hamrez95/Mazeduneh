import 'package:flutter/material.dart';

import 'admin_permissions.dart';
import 'admin_state.dart';
import 'admin_theme.dart';
import 'admin_users_page.dart';
import 'audit_log_page.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'catalog_page.dart';
import 'catalog_api.dart';
import 'admin_navigation.dart';
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
  static const items = [
    ('داشبورد', Icons.space_dashboard_rounded, AdminPermissions.dashboardRead),
    ('سفارش‌ها', Icons.receipt_long_rounded, AdminPermissions.ordersRead),
    ('محصولات', Icons.inventory_2_rounded, AdminPermissions.productsRead),
    ('انبار', Icons.warehouse_rounded, AdminPermissions.inventoryRead),
    ('گزارش‌ها', Icons.query_stats_rounded, AdminPermissions.reportsRead),
    ('اعلان‌ها', Icons.notifications_active_rounded, AdminPermissions.dashboardRead),
    ('مشتری‌ها', Icons.people_alt_rounded, AdminPermissions.customersRead),
    ('قیمت و ارسال', Icons.percent_rounded, AdminPermissions.pricingRead),
    ('فروش سازمانی', Icons.business_center_rounded, AdminPermissions.corporateRead),
    ('امنیت', Icons.shield_outlined, AdminPermissions.auditRead),
    ('کاربران', Icons.manage_accounts_outlined, AdminPermissions.usersRead),
  ];

  @override
  void initState() {
    super.initState();
    if (OwnerSession.instance.isAuthenticated) {
      final firstAllowed = items.indexWhere(
        (item) => OwnerSession.instance.can(item.$3),
      );
      if (firstAllowed >= 0) index = firstAllowed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final visibleIndexes = [for (var i = 0; i < items.length; i++) if (!OwnerSession.instance.isAuthenticated || OwnerSession.instance.can(items[i].$3)) i];
    final primaryIndexes = visibleIndexes.take(4).toList();
    final secondaryIndexes = visibleIndexes.skip(4).toList();
    final selectedPrimary = primaryIndexes.indexOf(index);
    final pages = [
      AdminPermissionGate(permission: AdminPermissions.dashboardRead, child: DashboardPage(api: widget.dashboardApi, onNavigate: _navigate)),
      AdminPermissionGate(permission: AdminPermissions.ordersRead, child: OrdersPage(key: ValueKey(navigation), api: widget.ordersApi, initialFilter: navigation.orderFilter)),
      AdminPermissionGate(permission: AdminPermissions.productsRead, child: CatalogPage(key: catalogKey)),
      AdminPermissionGate(permission: AdminPermissions.inventoryRead, child: InventoryPage(key: ValueKey(navigation), catalog: widget.catalogApi, orders: widget.ordersApi, initialSku: navigation.sku, initialBatchCode: navigation.batchCode)),
      const AdminPermissionGate(permission: AdminPermissions.reportsRead, child: ReportsPage()),
      AdminPermissionGate(permission: AdminPermissions.dashboardRead, child: NotificationsPage(onNavigate: _navigate)),
      const AdminPermissionGate(permission: AdminPermissions.customersRead, child: CustomerManagementPage()),
      const AdminPermissionGate(permission: AdminPermissions.pricingRead, child: CommerceSettingsPage()),
      const AdminPermissionGate(permission: AdminPermissions.corporateRead, child: CorporateRequestsPage()),
      const AdminPermissionGate(permission: AdminPermissions.auditRead, child: AuditLogPage()),
      const AdminPermissionGate(permission: AdminPermissions.usersRead, child: AdminUsersPage()),
    ];
    return PopScope<Object?>(
      canPop: navigationHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _goBack(); },
      child: Scaffold(
      appBar: desktop ? null : AppBar(
        leading: navigationHistory.isEmpty ? null : IconButton(tooltip: 'بازگشت به ${_moduleLabel(navigationHistory.last.module)}', onPressed: _goBack, icon: const Icon(Icons.arrow_back_rounded)),
        title: const Brand(compact: true),
      ),
      bottomNavigationBar: desktop || visibleIndexes.isEmpty
          ? null
          : visibleIndexes.length == 1
          ? BottomAppBar(
              child: SafeArea(
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Semantics(
                      label: 'بخش فعال: ${items[visibleIndexes.single].$1}',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            items[visibleIndexes.single].$2,
                            color: AdminColors.ink,
                          ),
                          const SizedBox(width: 8),
                          Text(items[visibleIndexes.single].$1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          : NavigationBar(
              selectedIndex: secondaryIndexes.isNotEmpty ? (selectedPrimary < 0 ? primaryIndexes.length : selectedPrimary) : (selectedPrimary < 0 ? 0 : selectedPrimary),
              onDestinationSelected: (value) => secondaryIndexes.isNotEmpty && value == primaryIndexes.length ? _openMoreMenu(secondaryIndexes) : _selectModule(primaryIndexes[value]),
              destinations: [for (final item in [for (final i in primaryIndexes) items[i], if (secondaryIndexes.isNotEmpty) ('بیشتر', Icons.more_horiz_rounded, '')]) NavigationDestination(icon: Icon(item.$2), label: item.$1)],
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
                    for (final i in visibleIndexes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      selected: index == i,
                      selectedTileColor: AdminColors.ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Icon(
                        items[i].$2,
                        color: index == i
                            ? Colors.white
                            : const Color(0xFFBFD0C5),
                      ),
                      title: Text(
                        items[i].$1,
                        style: TextStyle(
                          color: index == i
                              ? Colors.white
                              : const Color(0xFFD5DFD6),
                        ),
                      ),
                      onTap: () => _selectModule(i),
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
                  trailing: IconButton(
                    tooltip: 'خروج از حساب',
                    onPressed: () async {
                      try {
                        await AuthApiClient().logout();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'از این دستگاه خارج شدید؛ ارتباط با سرور قطع بود.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFD5DFD6),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        Expanded(child: SafeArea(child: IndexedStack(index: index, children: pages))),
      ]),
      floatingActionButton: index == 2
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
    if (destination < 0 || destination >= items.length || intent == navigation) return;
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

  String _moduleLabel(AdminModule module) => switch (module) {
    AdminModule.dashboard => 'داشبورد', AdminModule.orders => 'سفارش‌ها',
    AdminModule.products => 'محصولات', AdminModule.inventory => 'انبار',
    AdminModule.reports => 'گزارش‌ها', AdminModule.notifications => 'اعلان‌ها',
    AdminModule.customers => 'مشتری‌ها', AdminModule.pricing => 'قیمت و ارسال',
    AdminModule.corporate => 'فروش سازمانی', AdminModule.audit => 'امنیت',
    AdminModule.users => 'کاربران',
  };

  Future<void> _openMoreMenu(List<int> secondaryIndexes) async {
    final selected = await showModalBottomSheet<int>(
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
            for (final i in secondaryIndexes)
              ListTile(
                selected: index == i,
                selectedTileColor: AdminColors.mintSoft,
                leading: Icon(items[i].$2, color: AdminColors.ink),
                title: Text(items[i].$1),
                trailing: const Icon(Icons.arrow_back_rounded, size: 18),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) _selectModule(selected);
  }
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
