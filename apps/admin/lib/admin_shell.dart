import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_state.dart';
import 'admin_theme.dart';
import 'admin_permissions.dart';
import 'admin_users_page.dart';
import 'audit_log_page.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'catalog_page.dart';
import 'catalog_api.dart';
import 'admin_navigation.dart';
import 'admin_browser_location.dart';
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
import 'promotions_page.dart';
import 'formatters.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    this.dashboardApi,
    this.ordersApi,
    this.catalogApi,
  });
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
  final navigationBadgeCounts = <AdminModule, int>{};
  bool collapsed = false;
  int dashboardRefreshRevision = 0;
  Timer? _navigationBadgeTimer;
  bool _refreshingNavigationBadges = false;

  @override
  void initState() {
    super.initState();
    if (OwnerSession.instance.isAuthenticated) {
      final requested = AdminNavigationIntent.fromUri(currentAdminUri());
      if (OwnerSession.instance.can(requested.module.permission)) {
        navigation = requested;
        index = AdminModule.values.indexOf(requested.module);
      }
      final firstAllowed = AdminModule.values.indexWhere(
        (module) => OwnerSession.instance.can(module.permission),
      );
      if (firstAllowed >= 0 &&
          !OwnerSession.instance.can(navigation.module.permission)) {
        index = firstAllowed;
        navigation = AdminNavigationIntent(
          module: AdminModule.values[firstAllowed],
        );
      }
      final location = currentAdminUri();
      if (location != null) replaceAdminUri(navigation.toUri(location));
    }
    if (OwnerSession.instance.isAuthenticated &&
        OwnerSession.instance.can(AdminPermissions.dashboardRead)) {
      unawaited(_refreshNavigationBadges());
      _navigationBadgeTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_refreshNavigationBadges()),
      );
    }
  }

  @override
  void dispose() {
    _navigationBadgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshNavigationBadges() async {
    if (_refreshingNavigationBadges ||
        !OwnerSession.instance.isAuthenticated ||
        !OwnerSession.instance.can(AdminPermissions.dashboardRead)) {
      return;
    }
    _refreshingNavigationBadges = true;
    try {
      final api = widget.dashboardApi ?? widget.ordersApi ?? OrderApiClient();
      final results = await Future.wait([
        api.fetchDashboard(),
        api.fetchNotifications(),
      ]);
      if (!mounted) return;
      final dashboard = results[0] as AdminDashboard;
      final notifications = results[1] as AdminNotifications;
      final counts = <AdminModule, int>{
        AdminModule.orders: dashboard.awaitingPayment + dashboard.processing,
        AdminModule.inventory:
            notifications.lowStockItems + dashboard.expiringSoon.length,
        AdminModule.corporate:
            dashboard.corporateNewRequests +
            notifications.corporateOverdueFollowUps,
        AdminModule.notifications: notifications.count,
      };
      setState(() {
        navigationBadgeCounts
          ..clear()
          ..addEntries(counts.entries.where((entry) => entry.value > 0));
      });
    } catch (_) {
      // Keep the last known counts if the API is temporarily unavailable.
    } finally {
      _refreshingNavigationBadges = false;
    }
  }

  List<AdminModule> get visibleModules => [
    for (final module in AdminModule.values)
      if (!OwnerSession.instance.isAuthenticated ||
          OwnerSession.instance.can(module.permission))
        module,
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final modules = visibleModules;
    final primary = modules.take(4).toList();
    final secondary = modules.skip(4).toList();
    final selectedPrimary = primary.indexWhere(
      (module) => module.index == index,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openSearch,
      },
      child: PopScope<Object?>(
        canPop: navigationHistory.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goBack();
        },
        child: Scaffold(
          appBar: desktop
              ? null
              : AppBar(
                  leading: navigationHistory.isEmpty
                      ? null
                      : IconButton(
                          tooltip:
                              'بازگشت به ${_moduleLabel(navigationHistory.last.module)}',
                          onPressed: _goBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                  title: const Brand(compact: true),
                  actions: [
                    IconButton(
                      tooltip: 'جست‌وجوی بخش‌ها',
                      onPressed: _openSearch,
                      icon: const Icon(Icons.search_rounded),
                    ),
                    _accountMenu(),
                  ],
                ),
          bottomNavigationBar: desktop || modules.isEmpty
              ? null
              : modules.length == 1
              ? BottomAppBar(
                  child: SafeArea(
                    child: SizedBox(
                      height: 56,
                      child: Center(
                        child: Semantics(
                          label: 'بخش فعال: ${modules.single.label}',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                modules.single.icon,
                                color: AdminColors.primaryLight,
                              ),
                              const SizedBox(width: 8),
                              Text(modules.single.label),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : NavigationBar(
                  selectedIndex: secondary.isNotEmpty
                      ? (selectedPrimary < 0 ? primary.length : selectedPrimary)
                      : (selectedPrimary < 0 ? 0 : selectedPrimary),
                  onDestinationSelected: (value) =>
                      secondary.isNotEmpty && value == primary.length
                      ? _openMoreMenu(secondary)
                      : _selectModule(primary[value].index),
                  destinations: [
                    for (final module in primary)
                      NavigationDestination(
                        icon: _moduleIcon(module),
                        label: module.label,
                      ),
                    if (secondary.isNotEmpty)
                      const NavigationDestination(
                        icon: Icon(Icons.more_horiz_rounded),
                        label: 'بیشتر',
                      ),
                  ],
                ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop) _sidebar(modules),
              Expanded(
                child: SafeArea(
                  child: Column(
                    children: [
                      if (desktop) _topbar(),
                      Expanded(
                        child: IndexedStack(
                          index: index,
                          children: [
                            for (final module in AdminModule.values)
                              _modulePage(module),
                          ],
                        ),
                      ),
                      if (desktop)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 6, 24, 12),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 24,
                            runSpacing: 6,
                            children: [
                              Text(
                                'مزه‌دونه · مدیریت فروشگاه',
                                style: TextStyle(
                                  color: AdminColors.subtle,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'با طعم یک مدیریت بهتر',
                                style: TextStyle(
                                  color: AdminColors.subtle,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: !desktop && index == AdminModule.products.index
              ? FloatingActionButton.extended(
                  onPressed: () => catalogKey.currentState?.openCreateDialog(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('محصول جدید'),
                )
              : null,
        ),
      ),
    );
  }

  Widget _sidebar(List<AdminModule> modules) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: collapsed ? 76 : 260,
    decoration: const BoxDecoration(
      color: AdminColors.surface,
      border: BorderDirectional(
        end: BorderSide(color: AdminColors.border, width: 0.5),
      ),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 86,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 20),
            child: Row(
              children: [
                if (!collapsed) const Expanded(child: Brand(dark: true)),
                IconButton(
                  tooltip: collapsed ? 'بازکردن منو' : 'جمع‌کردن منو',
                  onPressed: () => setState(() => collapsed = !collapsed),
                  icon: Icon(
                    collapsed
                        ? Icons.menu_open_rounded
                        : Icons.radio_button_checked_rounded,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _navGroup('پیشخوان', [AdminModule.dashboard], modules),
              _navGroup('فروشگاه', [
                AdminModule.products,
                AdminModule.orders,
                AdminModule.customers,
                AdminModule.promotions,
                AdminModule.corporate,
              ], modules),
              _navGroup('عملیات و گزارش‌ها', [
                AdminModule.inventory,
                AdminModule.reports,
                AdminModule.notifications,
              ], modules),
              _navGroup('مدیریت و امنیت', [
                AdminModule.pricing,
                AdminModule.users,
                AdminModule.audit,
              ], modules),
            ],
          ),
        ),
        if (!collapsed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AdminColors.primaryLight,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      OwnerSession.instance.role == 'Owner'
                          ? 'حساب مالک فروشگاه'
                          : 'دسترسی مطابق نقش شما',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _navGroup(
    String title,
    List<AdminModule> group,
    List<AdminModule> modules,
  ) {
    final allowed = group.where(modules.contains).toList();
    if (allowed.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (collapsed)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 11, color: AdminColors.subtle),
            ),
          ),
        for (final module in allowed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Tooltip(
              message: collapsed ? module.label : '',
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: index == module.index
                      ? const LinearGradient(
                          colors: [AdminColors.primary, Color(0xFF9388F5)],
                        )
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    minLeadingWidth: 18,
                    horizontalTitleGap: 12,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 14 : 12,
                    ),
                    leading: _moduleIcon(
                      module,
                      color: index == module.index
                          ? Colors.white
                          : AdminColors.text,
                      showBadge: collapsed,
                    ),
                    title: collapsed
                        ? null
                        : Text(
                            module.label,
                            style: TextStyle(
                              color: index == module.index
                                  ? Colors.white
                                  : AdminColors.heading,
                              fontSize: 13,
                            ),
                          ),
                    trailing: !collapsed && _badgeCount(module) > 0
                        ? _countPill(_badgeCount(module))
                        : null,
                    onTap: () => _selectModule(module.index),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _badgeCount(AdminModule module) => navigationBadgeCounts[module] ?? 0;

  Widget _moduleIcon(
    AdminModule module, {
    Color? color,
    bool showBadge = true,
  }) {
    final count = _badgeCount(module);
    return Semantics(
      label: count > 0
          ? '${module.label}، ${formatPersianInteger(count)} مورد نیازمند پیگیری'
          : module.label,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(module.icon, color: color, size: 21),
          if (showBadge && count > 0)
            PositionedDirectional(
              top: -7,
              end: -9,
              child: _countPill(count, compact: true),
            ),
        ],
      ),
    );
  }

  Widget _countPill(int count, {bool compact = false}) => Container(
    constraints: BoxConstraints(
      minWidth: compact ? 17 : 22,
      minHeight: compact ? 17 : 20,
    ),
    padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 1),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AdminColors.coral,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AdminColors.surface, width: compact ? 1.5 : 0),
    ),
    child: Text(
      count > 99 ? '${formatPersianInteger(99)}+' : formatPersianInteger(count),
      style: TextStyle(
        color: Colors.white,
        fontSize: compact ? 9 : 10,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
  );

  Widget _topbar() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
    child: Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          if (navigationHistory.isNotEmpty)
            IconButton(
              tooltip:
                  'بازگشت به ${_moduleLabel(navigationHistory.last.module)}',
              onPressed: _goBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          Expanded(
            child: InkWell(
              onTap: _openSearch,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'جست‌وجوی بخش‌ها…',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AdminColors.subtle),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Ctrl + K',
                      style: TextStyle(color: AdminColors.subtle, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<AdminModule>(
            tooltip: 'میان‌برها',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onSelected: (module) => _selectModule(module.index),
            itemBuilder: (_) => [
              for (final module in visibleModules)
                PopupMenuItem(
                  value: module,
                  child: Row(
                    children: [
                      Icon(module.icon, size: 18),
                      const SizedBox(width: 12),
                      Text(module.label),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'اعلان‌ها',
            onPressed: visibleModules.contains(AdminModule.notifications)
                ? () => _selectModule(AdminModule.notifications.index)
                : null,
            icon: const Icon(Icons.notifications_outlined),
          ),
          _accountMenu(),
        ],
      ),
    ),
  );

  Widget _accountMenu() => PopupMenuButton<String>(
    tooltip: 'تنظیمات حساب',
    onSelected: (action) async {
      if (action == 'mfa') {
        showAdminMfaSettingsDialog(context);
      } else if (action == 'logout') {
        try {
          await AuthApiClient().logout();
        } catch (_) {
          if (mounted)
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
    itemBuilder: (_) => [
      PopupMenuItem<String>(
        enabled: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              OwnerSession.instance.email ?? 'کاربر فروشگاه',
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: AdminColors.heading, fontSize: 12),
            ),
            Text(
              OwnerSession.instance.role == 'Owner'
                  ? 'مدیر اصلی'
                  : 'عضو فروشگاه',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'mfa',
        child: ListTile(
          leading: Icon(Icons.security_rounded),
          title: Text('تنظیم تأیید دومرحله‌ای'),
        ),
      ),
      const PopupMenuItem(
        value: 'logout',
        child: ListTile(
          leading: Icon(Icons.logout_rounded),
          title: Text('خروج از حساب'),
        ),
      ),
    ],
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Badge(
        isLabelVisible: OwnerSession.instance.isAuthenticated,
        backgroundColor: AdminColors.success,
        smallSize: 8,
        alignment: Alignment.bottomLeft,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AdminColors.primarySoft,
          child: Text(
            (OwnerSession.instance.email ?? 'م').substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: AdminColors.primaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> _openSearch() async {
    final controller = TextEditingController();
    final selected = await showDialog<AdminModule>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('جست‌وجوی بخش‌های پنل'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => update(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'نام بخش را بنویسید',
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final module in visibleModules.where(
                        (item) => item.label.contains(controller.text.trim()),
                      ))
                        ListTile(
                          leading: Icon(module.icon),
                          title: Text(module.label),
                          onTap: () => Navigator.pop(dialogContext, module),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
    // The dialog's removal animation may still read its text controller.
    if (selected != null && mounted) _selectModule(selected.index);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
  }

  void _navigate(AdminNavigationIntent intent) {
    final session = OwnerSession.instance;
    if (session.isAuthenticated && !session.can(intent.module.permission))
      return;
    final destination = AdminModule.values.indexOf(intent.module);
    if (destination < 0 || intent == navigation) return;
    setState(() {
      navigationHistory.add(navigation);
      navigation = intent;
      index = destination;
      if (intent.module == AdminModule.dashboard) dashboardRefreshRevision++;
    });
    final location = currentAdminUri();
    if (location != null) replaceAdminUri(intent.toUri(location));
  }

  void _selectModule(int destination) {
    if (destination < 0 || destination >= AdminModule.values.length) return;
    setState(() {
      navigationHistory.clear();
      index = destination;
      navigation = AdminNavigationIntent(
        module: AdminModule.values[destination],
      );
      if (AdminModule.values[destination] == AdminModule.dashboard) {
        dashboardRefreshRevision++;
      }
    });
    final location = currentAdminUri();
    if (location != null) replaceAdminUri(navigation.toUri(location));
  }

  void _goBack() {
    if (navigationHistory.isEmpty) return;
    final previous = navigationHistory.removeLast();
    setState(() {
      navigation = previous;
      index = AdminModule.values.indexOf(previous.module);
      if (previous.module == AdminModule.dashboard) dashboardRefreshRevision++;
    });
    final location = currentAdminUri();
    if (location != null) replaceAdminUri(previous.toUri(location));
  }

  void _persistNavigationUrl(AdminNavigationIntent intent) {
    final location = currentAdminUri();
    if (location != null) replaceAdminUri(intent.toUri(location));
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
              child: Text(
                'بخش‌های بیشتر',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              ),
            ),
            for (final module in secondaryModules)
              ListTile(
                selected: index == AdminModule.values.indexOf(module),
                selectedTileColor: AdminColors.mintSoft,
                leading: _moduleIcon(
                  module,
                  color: AdminColors.ink,
                  showBadge: false,
                ),
                title: Text(module.label),
                trailing: _badgeCount(module) > 0
                    ? _countPill(_badgeCount(module))
                    : const Icon(Icons.arrow_back_rounded, size: 18),
                onTap: () => Navigator.pop(context, module),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted)
      _selectModule(AdminModule.values.indexOf(selected));
  }

  Widget _modulePage(AdminModule module) => switch (module) {
    AdminModule.dashboard => AdminPermissionGate(
      permission: module.permission,
      child: DashboardPage(
        api: widget.dashboardApi,
        onNavigate: _navigate,
        refreshRevision: dashboardRefreshRevision,
      ),
    ),
    AdminModule.orders => AdminPermissionGate(
      permission: module.permission,
      child: OrdersPage(
        key: ValueKey(navigation),
        api: widget.ordersApi,
        onNavigationChanged: _persistNavigationUrl,
        initialFilter: navigation.orderFilter,
        initialQuery: navigation.query ?? '',
        initialOrderId: navigation.orderId,
        initialCreatedFromUtc: navigation.createdFromUtc,
        initialCreatedToUtcExclusive: navigation.createdToUtcExclusive,
      ),
    ),
    AdminModule.products => AdminPermissionGate(
      permission: module.permission,
      child: CatalogPage(
        key: catalogKey,
        onNavigate: _navigate,
        initialProductSlug: navigation.productSlug,
      ),
    ),
    AdminModule.inventory => AdminPermissionGate(
      permission: module.permission,
      child: InventoryPage(
        key: ValueKey(navigation),
        catalog: widget.catalogApi,
        orders: widget.ordersApi,
        initialSku: navigation.sku,
        initialBatchCode: navigation.batchCode,
      ),
    ),
    AdminModule.reports => AdminPermissionGate(
      permission: module.permission,
      child: ReportsPage(
        key: ValueKey(navigation),
        initialFromUtc: navigation.createdFromUtc,
        initialToUtcExclusive: navigation.createdToUtcExclusive,
        onNavigate: _navigate,
      ),
    ),
    AdminModule.notifications => AdminPermissionGate(
      permission: module.permission,
      child: NotificationsPage(
        key: ValueKey(navigation.notificationId),
        onNavigate: _navigate,
        initialNotificationId: navigation.notificationId,
      ),
    ),
    AdminModule.customers => AdminPermissionGate(
      permission: module.permission,
      child: const CustomerManagementPage(),
    ),
    AdminModule.pricing => AdminPermissionGate(
      permission: module.permission,
      child: const CommerceSettingsPage(),
    ),
    AdminModule.corporate => AdminPermissionGate(
      permission: module.permission,
      child: const CorporateRequestsPage(),
    ),
    AdminModule.audit => AdminPermissionGate(
      permission: module.permission,
      child: const AuditLogPage(),
    ),
    AdminModule.promotions => AdminPermissionGate(
      permission: module.permission,
      child: const PromotionsPage(),
    ),
    AdminModule.users => AdminPermissionGate(
      permission: module.permission,
      child: const AdminUsersPage(),
    ),
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
                    'پنل مدیریت فروشگاه',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: dark ? AdminColors.muted : AdminColors.muted,
                    ),
                  ),
                ],
              ),
      ),
    ],
  );
}

