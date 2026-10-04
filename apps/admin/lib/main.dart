import 'dart:convert';

import 'admin_state.dart';
import 'admin_permissions.dart';
import 'auth_session.dart';
import 'formatters.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'catalog_api.dart';
import 'order_api.dart';
import 'media_api.dart';
import 'customer_management_page.dart';
import 'commerce_settings_page.dart';
import 'corporate_requests_page.dart';
import 'audit_log_page.dart';
import 'admin_users_page.dart';
import 'notification_tile.dart';
import 'package:file_picker/file_picker.dart';

class AdminColors {
  static const ink = Color(0xFF24463A);
  static const inkDeep = Color(0xFF19352C);
  static const mintSoft = Color(0xFFDDEFE5);
  static const canvas = Color(0xFFF7F8F4);
  static const border = Color(0xFFE3E8E1);
  static const amber = Color(0xFFF2B866);
  static const coral = Color(0xFFE8846B);
  static const muted = Color(0xFF718078);
}

void main() => runApp(const MazedunehAdminApp());

class MazedunehAdminApp extends StatelessWidget {
  const MazedunehAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مدیریت مزه‌دونه',
        locale: const Locale('fa'),
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Vazirmatn',
          colorScheme: ColorScheme.fromSeed(seedColor: AdminColors.ink),
          scaffoldBackgroundColor: AdminColors.canvas,
          appBarTheme: const AppBarTheme(backgroundColor: AdminColors.canvas, surfaceTintColor: Colors.transparent, elevation: 0),
          navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: AdminColors.mintSoft),
          cardTheme: const CardThemeData(
            elevation: 0, color: Colors.white, margin: EdgeInsets.zero, surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18)), side: BorderSide(color: AdminColors.border)),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AdminColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AdminColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AdminColors.ink, width: 1.5)),
          ),
        ),
        home: const Directionality(textDirection: TextDirection.rtl, child: AdminShell()),
      );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.dashboardApi});
  final OrderApiClient? dashboardApi;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  var index = 0;
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
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final visibleIndexes = [for (var i = 0; i < items.length; i++) if (!OwnerSession.instance.isAuthenticated || OwnerSession.instance.can(items[i].$3)) i];
    final primaryIndexes = visibleIndexes.take(4).toList();
    final secondaryIndexes = visibleIndexes.skip(4).toList();
    final selectedPrimary = primaryIndexes.indexOf(index);
    final pages = [
      AdminPermissionGate(permission: AdminPermissions.dashboardRead, child: DashboardPage(api: widget.dashboardApi, onNavigate: (destination) => setState(() => index = destination))),
      const AdminPermissionGate(permission: AdminPermissions.ordersRead, child: OrdersPage()),
      AdminPermissionGate(permission: AdminPermissions.productsRead, child: CatalogPage(key: catalogKey)),
      const AdminPermissionGate(permission: AdminPermissions.inventoryRead, child: InventoryPage()),
      const AdminPermissionGate(permission: AdminPermissions.reportsRead, child: ReportsPage()),
      AdminPermissionGate(permission: AdminPermissions.dashboardRead, child: NotificationsPage(onNavigate: (destination) => setState(() => index = destination))),
      const AdminPermissionGate(permission: AdminPermissions.customersRead, child: CustomerManagementPage()),
      const AdminPermissionGate(permission: AdminPermissions.pricingRead, child: CommerceSettingsPage()),
      const AdminPermissionGate(permission: AdminPermissions.corporateRead, child: CorporateRequestsPage()),
      const AdminPermissionGate(permission: AdminPermissions.auditRead, child: AuditLogPage()),
      const AdminPermissionGate(permission: AdminPermissions.usersRead, child: AdminUsersPage()),
    ];
    return Scaffold(
      appBar: desktop ? null : AppBar(title: const Brand(compact: true)),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: secondaryIndexes.isNotEmpty ? (selectedPrimary < 0 ? primaryIndexes.length : selectedPrimary) : (selectedPrimary < 0 ? 0 : selectedPrimary),
              onDestinationSelected: (value) => secondaryIndexes.isNotEmpty && value == primaryIndexes.length ? _openMoreMenu(secondaryIndexes) : setState(() => index = primaryIndexes[value]),
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
              const SizedBox(height: 20),
              for (final i in visibleIndexes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: index == i,
                    selectedTileColor: AdminColors.ink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: Icon(items[i].$2, color: index == i ? Colors.white : const Color(0xFFBFD0C5)),
                    title: Text(items[i].$1, style: TextStyle(color: index == i ? Colors.white : const Color(0xFFD5DFD6))),
                    onTap: () => setState(() => index = i),
                  ),
                ),
              const Spacer(),
              const ListTile(
                leading: CircleAvatar(backgroundColor: Color(0xFFF7C58B), child: Text('ح')),
                title: Text('حمیدرضا', style: TextStyle(color: Colors.white)),
                subtitle: Text('مدیر اصلی', style: TextStyle(color: Color(0xFF9EACA1))),
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
    );
  }

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
    if (selected != null && mounted) setState(() => index = selected);
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.dark = false, this.compact = false});
  final bool dark;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 11 : 15),
          child: Image.asset('assets/mazedooneh-mark.png', width: compact ? 34 : 45, height: compact ? 34 : 45, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        if (compact)
          Text('مدیریت مزه‌دونه', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? Colors.white : null))
        else
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مدیریت مزه‌دونه', style: TextStyle(fontWeight: FontWeight.w800, color: dark ? Colors.white : null)),
            Text('کاتالوگ زنده فروشگاه', style: TextStyle(fontSize: 10, color: dark ? const Color(0xFFB9C8BC) : Colors.grey)),
          ]),
      ]);
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.api, this.onNavigate});
  final OrderApiClient? api;
  final ValueChanged<int>? onNavigate;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final OrderApiClient api = widget.api ?? OrderApiClient();
  AdminDashboard? dashboard;
  AdminNotifications? notifications;
  Object? error;
  bool loading = true;
  DateTime? lastLoadedAt;
  int dashboardDays = 1;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Future.wait([api.fetchDashboard(days: dashboardDays), api.fetchNotifications()]);
      if (mounted) setState(() {
        dashboard = result[0] as AdminDashboard;
        notifications = result[1] as AdminNotifications;
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
    if (loading && dashboard == null) return const Center(child: CircularProgressIndicator());
    if (error != null && dashboard == null) return AdminErrorState(error: error!, onRetry: load);
    final data = dashboard!;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          if (error != null) AdminStaleBanner(detail: 'داده‌های فعلی ممکن است تازه نباشند. ${requestErrorMessage(error!)}', onRetry: load),
          LayoutBuilder(builder: (context, constraints) {
            final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('وضعیت فروشگاه', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
              const SizedBox(height: 6),
              const Text('نمای سریع از وضعیت امروز فروشگاه و کارهایی که نیاز به توجه دارند.', style: TextStyle(color: AdminColors.muted)),
              if (lastLoadedAt != null) ...[
                const SizedBox(height: 5),
                Text('آخرین به‌روزرسانی: ${formatPersianDateTime(lastLoadedAt!)}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
              ],
            ]);
            final refresh = IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد');
            return constraints.maxWidth < 500
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Align(alignment: AlignmentDirectional.centerEnd, child: refresh), heading])
                : Row(children: [Expanded(child: heading), refresh]);
          }),
          const SizedBox(height: 24),
          _DashboardPeriodSelector(
            selectedDays: dashboardDays,
            onChanged: (days) {
              setState(() => dashboardDays = days);
              load();
            },
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 14, children: [
            MetricCard(_periodLabel(dashboardDays), '${formatPersianNumber(data.periodRevenue)} ریال', Icons.payments_rounded, tint: AdminColors.mintSoft),
            MetricCard('تعداد سفارش بازه', formatPersianInteger(data.periodOrderCount), Icons.shopping_bag_rounded, tint: const Color(0xFFE6EEF8)),
            MetricCard('میانگین ارزش سفارش', '${formatPersianNumber(data.averageOrderValue)} ریال', Icons.insights_rounded, tint: const Color(0xFFFFF0D9)),
            MetricCard('در انتظار پرداخت', formatPersianInteger(data.awaitingPayment), Icons.schedule_rounded, tint: const Color(0xFFFFF0D9)),
            MetricCard('در حال پردازش', formatPersianInteger(data.processing), Icons.inventory_2_rounded, tint: const Color(0xFFE6EEF8)),
            MetricCard('ارسال‌شده', formatPersianInteger(data.shipped), Icons.local_shipping_rounded, tint: const Color(0xFFFCE6E0)),
            MetricCard('سفارش مشکل‌دار', formatPersianInteger(data.problemOrders), Icons.report_problem_outlined, tint: const Color(0xFFFCE6E0)),
            MetricCard('مشتری جدید بازه', formatPersianInteger(data.newCustomers), Icons.person_add_alt_1_rounded, tint: const Color(0xFFE6F5E8)),
            MetricCard('درخواست سازمانی جدید', formatPersianInteger(data.corporateNewRequests), Icons.business_center_rounded, tint: const Color(0xFFE6EEF8)),
          ]),
          const SizedBox(height: 24),
          const _DashboardSectionTitle(
            eyebrow: 'مسیرهای سریع',
            title: 'امروز چه کاری انجام دهید؟',
            detail: 'از همین‌جا به کاری بروید که بیشترین اثر را روی عملیات امروز دارد.',
          ),
          const SizedBox(height: 12),
          _DashboardQuickActions(onNavigate: widget.onNavigate),
          const SizedBox(height: 28),
          Builder(builder: (context) {
            final alertItems = notifications?.items ?? const <AdminNotification>[];
            final panels = [
              _DashboardPanel(
                title: 'هشدارهای عملیاتی',
                icon: Icons.notifications_active_rounded,
                child: alertItems.isEmpty
                    ? const AdminEmptyState(icon: Icons.check_circle_outline_rounded, title: 'همه‌چیز آرام است', detail: 'هشدار فوری برای پیگیری وجود ندارد.')
                    : Column(children: [
                        for (final item in alertItems.take(4))
                          AdminNotificationTile(item: item, onNavigate: widget.onNavigate),
                      ]),
              ),
              _DashboardPanel(
                title: 'موجودی کم',
                icon: Icons.warning_amber_rounded,
                child: data.lowStock.isEmpty
                    ? const AdminEmptyState(icon: Icons.inventory_2_outlined, title: 'موجودی مناسب است', detail: 'کالایی پایین‌تر از نقطه سفارش نیست.')
                    : Column(children: [
                        for (final item in data.lowStock.take(4))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${item.variantLabel} · ${item.sku}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                            trailing: Text(formatPersianInteger(item.availablePackages), style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.coral)),
                          ),
                      ]),
              ),
              _DashboardPanel(
                title: 'نزدیک به انقضا',
                icon: Icons.event_busy_rounded,
                child: data.expiringSoon.isEmpty
                    ? const AdminEmptyState(icon: Icons.check_circle_outline_rounded, title: 'بچ نزدیک انقضا نداریم', detail: 'تا ۳۰ روز آینده موردی برای پیگیری ثبت نشده است.')
                    : Column(children: [
                        for (final item in data.expiringSoon.take(5))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${item.variantLabel} · ${item.sku} · ${formatPersianInteger(item.remainingPackages)} بسته', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                            trailing: Text(formatPersianDateTime(item.expiresAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.coral)),
                          ),
                      ]),
              ),
            ];
            return LayoutBuilder(builder: (context, constraints) {
              final stacked = constraints.maxWidth < 720;
              return stacked
                  ? Column(children: [panels[0], const SizedBox(height: 14), panels[1], const SizedBox(height: 14), panels[2]])
                  : Column(children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: panels[0]), const SizedBox(width: 14), Expanded(child: panels[1])]), const SizedBox(height: 14), panels[2]]);
            });
          }),
        ],
      ),
    );
  }

  String _periodLabel(int days) => switch (days) {
        1 => 'فروش امروز',
        7 => 'فروش ۷ روز اخیر',
        30 => 'فروش ۳۰ روز اخیر',
        _ => 'فروش بازهٔ انتخابی',
      };

}

class _DashboardPeriodSelector extends StatelessWidget {
  const _DashboardPeriodSelector({required this.selectedDays, required this.onChanged});
  final int selectedDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('بازهٔ فروش', style: TextStyle(fontWeight: FontWeight.w900)),
            for (final option in const [(1, 'امروز'), (7, '۷ روز'), (30, '۳۰ روز')])
              ChoiceChip(
                label: Text(option.$2),
                selected: selectedDays == option.$1,
                onSelected: (_) => onChanged(option.$1),
              ),
          ],
        ),
      );
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({required this.eyebrow, required this.title, required this.detail});
  final String eyebrow;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow, style: const TextStyle(color: AdminColors.ink, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: AdminColors.inkDeep, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: AdminColors.muted, fontSize: 12)),
      ]);
}

class _DashboardQuickActions extends StatelessWidget {
  const _DashboardQuickActions({required this.onNavigate});
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final session = OwnerSession.instance;
    bool can(String permission) => !session.isAuthenticated || session.can(permission);
    final actions = [
      if (can(AdminPermissions.productsRead))
        can(AdminPermissions.productsWrite)
            ? (title: 'ثبت محصول', detail: 'محصول جدید را به‌صورت پیش‌نویس بسازید.', icon: Icons.add_box_rounded, destination: 2)
            : (title: 'مشاهده محصولات', detail: 'مشخصات، قیمت و وضعیت انتشار را بررسی کنید.', icon: Icons.inventory_2_outlined, destination: 2),
      if (can(AdminPermissions.ordersRead))
        (title: 'پیگیری سفارش‌ها', detail: 'سفارش‌های جدید و منتظر پرداخت را ببینید.', icon: Icons.receipt_long_rounded, destination: 1),
      if (can(AdminPermissions.inventoryRead))
        can(AdminPermissions.inventoryWrite)
            ? (title: 'اصلاح موجودی', detail: 'دریافت کالا یا اصلاح یک SKU را ثبت کنید.', icon: Icons.inventory_2_rounded, destination: 3)
            : (title: 'مشاهده موجودی', detail: 'موجودی کالا و بچ‌های نزدیک انقضا را بررسی کنید.', icon: Icons.warehouse_outlined, destination: 3),
      if (can(AdminPermissions.corporateRead))
        (title: 'پیگیری فروش سازمانی', detail: 'درخواست‌های جدید را از دست ندهید.', icon: Icons.business_center_rounded, destination: 8),
    ];
    if (actions.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'مسیر عملیاتی برای نقش شما فعال نیست',
        detail: 'برای دسترسی به محصولات، سفارش‌ها یا انبار با مدیر فروشگاه هماهنگ کنید. گزارش داشبورد همچنان قابل مشاهده است.',
      );
    }
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1050 ? 4 : constraints.maxWidth >= 650 ? 2 : 1;
      final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final action in actions)
          SizedBox(width: width, child: _DashboardQuickAction(action: action, onPressed: onNavigate == null ? null : () => onNavigate!(action.destination))),
      ]);
    });
  }
}

class _DashboardQuickAction extends StatelessWidget {
  const _DashboardQuickAction({required this.action, required this.onPressed});
  final ({String title, String detail, IconData icon, int destination}) action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onPressed != null,
        label: '${action.title}: ${action.detail}',
        child: Card(
          child: InkWell(
            key: ValueKey('dashboard-action-${action.destination}'),
            onTap: onPressed,
            focusColor: AdminColors.mintSoft,
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(builder: (context, constraints) {
              final compact = constraints.maxWidth < 320;
              final icon = Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: AdminColors.mintSoft, shape: BoxShape.circle),
                child: Icon(action.icon, color: AdminColors.ink),
              );
              final title = Text(action.title, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.inkDeep));
              final detail = Text(action.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, height: 1.5, color: AdminColors.ink));
              return Padding(
                padding: const EdgeInsets.all(16),
                child: compact
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Align(alignment: AlignmentDirectional.centerEnd, child: const Icon(Icons.arrow_back_rounded, size: 18, color: AdminColors.ink)),
                        icon,
                        const SizedBox(height: 10),
                        title,
                        const SizedBox(height: 6),
                        detail,
                      ])
                    : Row(children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 4), detail])),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_back_rounded, size: 18, color: AdminColors.ink),
                      ]),
              );
            }),
          ),
        ),
      );
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [Icon(icon, color: AdminColors.ink), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
    const SizedBox(height: 12), child,
  ])));
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.title, this.value, this.icon, {super.key, this.tint = AdminColors.mintSoft});
  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150),
      child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(backgroundColor: tint, foregroundColor: AdminColors.ink, child: Icon(icon)),
      const SizedBox(height: 12),
      Text(title, style: const TextStyle(color: AdminColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AdminColors.inkDeep)),
    ])))),
  );
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, this.api});
  final CatalogApiClient? api;

  @override
  State<CatalogPage> createState() => CatalogPageState();
}

class CatalogPageState extends State<CatalogPage> {
  late final CatalogApiClient api = widget.api ?? CatalogApiClient();
  List<Product> products = const [];
  List<Category> categories = const [];
  final Set<String> changingPublication = {};
  bool loading = true;
  Object? error;
  bool showDrafts = true;

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
      final result = await Future.wait([
        api.fetchProducts(includeDrafts: true),
        api.fetchCategories(),
      ]);
      if (mounted) setState(() {
        products = result[0] as List<Product>;
        categories = result[1] as List<Category>;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openCreateDialog() async {
    final command = await showDialog<CreateProductCommand>(context: context, builder: (_) => ProductDialog(mediaApi: MediaApiClient(), categories: categories));
    if (command == null) return;
    try {
      await api.createProduct(command);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('محصول به‌صورت پیش‌نویس ثبت شد.')));
      }
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString())));
    }
  }

  Future<void> changePublication(Product product) async {
    final target = !product.isPublished;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(target ? Icons.public_rounded : Icons.visibility_off_rounded),
        title: Text(target ? 'انتشار محصول؟' : 'خروج محصول از فروش؟'),
        content: Text(target
            ? '«${product.title}» پس از تأیید در فروشگاه قابل مشاهده خواهد بود.'
            : '«${product.title}» از فروشگاه مخفی می‌شود، اما اطلاعات و سابقه آن حذف نخواهد شد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(target ? 'انتشار' : 'خروج از فروش')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => changingPublication.add(product.slug));
    try {
      await api.setPublication(product.slug, target);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(target ? 'محصول منتشر شد.' : 'محصول از فروش خارج شد.'),
        ));
      }
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString())));
    } finally {
      if (mounted) setState(() => changingPublication.remove(product.slug));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('محصولات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const Text('پیش‌نویس‌ها فقط در پنل دیده می‌شوند.', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => CategoryManagerDialog(api: api, initial: categories, onChanged: load),
                );
              },
              icon: const Icon(Icons.category_rounded),
              label: Text('دسته‌ها (${formatPersianInteger(categories.length)})'),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('نمایش پیش‌نویس‌ها'),
              selected: showDrafts,
              onSelected: (value) => setState(() => showDrafts = value),
            ),
            const SizedBox(width: 8),
            IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
          ]),
          const SizedBox(height: 18),
          Expanded(child: _body()),
        ]),
      );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    final visible = showDrafts ? products : products.where((item) => item.isPublished).toList();
    if (visible.isEmpty) return const Center(child: AdminEmptyState(icon: Icons.inventory_2_outlined, title: 'محصولی پیدا نشد', detail: 'با تغییر فیلتر یا ثبت محصول جدید، فهرست را کامل کنید.'));
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: 285,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: visible.length,
        itemBuilder: (_, index) {
          final product = visible[index];
          return ProductCard(
            product,
            publicationBusy: changingPublication.contains(product.slug),
            onPublicationPressed: () => changePublication(product),
          );
        },
      );
    });
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard(
    this.product, {
    super.key,
    required this.publicationBusy,
    required this.onPublicationPressed,
  });

  final Product product;
  final bool publicationBusy;
  final VoidCallback onPublicationPressed;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: product.primaryImage.trim().isEmpty
                    ? Container(width: 58, height: 58, color: AdminColors.mintSoft, alignment: Alignment.center, child: Text(product.isWeight ? '⚖' : '●'))
                    : Image.network(product.primaryImage, width: 58, height: 58, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Container(width: 58, height: 58, color: const Color(0xFFFFF0D9), alignment: Alignment.center, child: const Icon(Icons.broken_image_outlined)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(product.galleryImages.isEmpty ? 'یک تصویر ثبت شده' : '${formatPersianInteger(product.galleryImages.length + 1)} تصویر ثبت شده', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
              ])),
              _PublicationBadge(product.isPublished),
            ]),
            const SizedBox(height: 8),
            Text('${product.category} · ${product.origin}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const Spacer(),
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (final variant in product.variants)
                Chip(label: Text('${variant.displayLabel} · ${formatPersianInteger(variant.availablePackages)} بسته', style: const TextStyle(fontSize: 10))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(
                  'موجودی کل: ${formatPersianInteger(product.totalStock)} بسته',
                  style: const TextStyle(color: Color(0xFF31584A), fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: publicationBusy ? null : onPublicationPressed,
                icon: publicationBusy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(product.isPublished ? Icons.visibility_off_rounded : Icons.public_rounded),
                label: Text(product.isPublished ? 'خروج از فروش' : 'انتشار'),
              ),
            ]),
          ]),
        ),
      );
}

class _PublicationBadge extends StatelessWidget {
  const _PublicationBadge(this.isPublished);
  final bool isPublished;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isPublished ? const Color(0xFFE7F1E2) : const Color(0xFFFFE8C8),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isPublished ? 'منتشرشده' : 'پیش‌نویس',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
}

class ProductDialog extends StatefulWidget {
  const ProductDialog({super.key, this.mediaApi, this.categories = const []});
  final MediaApiClient? mediaApi;
  final List<Category> categories;

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  late final MediaApiClient media = widget.mediaApi ?? MediaApiClient();
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final slug = TextEditingController();
  final origin = TextEditingController();
  final shortDescription = TextEditingController();
  final description = TextEditingController();
  final seoTitle = TextEditingController();
  final seoDescription = TextEditingController();
  final seoKeywords = TextEditingController();
  final specifications = TextEditingController();
  final costPrice = TextEditingController();
  final primaryImage = TextEditingController();
  final galleryImages = TextEditingController();
  final sku = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
  String unitType = 'Weight';
  String category = 'آجیل و مغزها';
  num quantity = 250;
  bool uploadingImage = false;
  String? mediaError;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) category = widget.categories.first.name;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('محصول جدید'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(children: [
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('محصول ابتدا به‌صورت پیش‌نویس ذخیره می‌شود.'),
                  subtitle: Text('بعد از تکمیل اطلاعات، آن را جداگانه منتشر کنید.'),
                ),
                TextFormField(controller: title, decoration: const InputDecoration(labelText: 'نام محصول'), validator: required),
                const SizedBox(height: 10),
                TextFormField(controller: slug, decoration: const InputDecoration(labelText: 'شناسه انگلیسی URL'), validator: required),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                  items: (widget.categories.isEmpty
                      ? const ['آجیل و مغزها', 'میوه خشک', 'لواشک و ترش‌مزه', 'کوکی و شیرینی', 'کم‌شکر و پروتئینی', 'هدیه']
                      : widget.categories.map((item) => item.name).toList())
                      .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                      .toList(),
                  onChanged: (value) => category = value!,
                ),
                const SizedBox(height: 10),
                TextFormField(controller: origin, decoration: const InputDecoration(labelText: 'مبدأ یا برند'), validator: required),
                const SizedBox(height: 10),
                TextFormField(controller: shortDescription, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیح کوتاه', helperText: 'یک جمله‌ی روشن برای کارت محصول و جست‌وجو.')),
                const SizedBox(height: 10),
                TextFormField(controller: description, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'توضیحات کامل', helperText: 'مواد، طعم، روش نگهداری و نکات مهم مشتری.')),
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('اطلاعات SEO و مشخصات', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('اختیاری، اما برای دیده‌شدن محصول پیشنهاد می‌شود.', style: TextStyle(fontSize: 11, color: AdminColors.muted)),
                  children: [
                    TextFormField(controller: seoTitle, decoration: const InputDecoration(labelText: 'عنوان SEO')),
                    const SizedBox(height: 10),
                    TextFormField(controller: seoDescription, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیح SEO')),
                    const SizedBox(height: 10),
                    TextFormField(controller: seoKeywords, decoration: const InputDecoration(labelText: 'کلمات کلیدی', hintText: 'مثلاً پسته، رفسنجان، شور')),
                    const SizedBox(height: 10),
                    TextFormField(controller: specifications, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'مشخصات ساختاریافته', hintText: 'هر خط: کلید=مقدار', helperText: 'مثلاً وزن خالص=۲۵۰ گرم')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: TextFormField(
                    controller: primaryImage,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'تصویر اصلی محصول',
                      hintText: 'لینک تصویر یا فایل آپلودشده',
                      helperText: 'در کارت محصول و صفحه‌ی محصول نمایش داده می‌شود.',
                      prefixIcon: Icon(Icons.image_outlined),
                    ),
                    onChanged: (_) => setState(() {}),
                  )),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: OutlinedButton.icon(
                      onPressed: uploadingImage ? null : pickImage,
                      icon: uploadingImage
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(uploadingImage ? 'در حال آپلود' : 'انتخاب فایل'),
                    ),
                  ),
                ]),
                if (mediaError != null)
                  Align(alignment: Alignment.centerRight, child: Text(mediaError!, style: const TextStyle(color: AdminColors.coral, fontSize: 11))),
                const SizedBox(height: 10),
                if (primaryImage.text.trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      primaryImage.text.trim(),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        alignment: Alignment.center,
                        color: const Color(0xFFFFF0D9),
                        child: const Text('پیش‌نمایش تصویر در دسترس نیست؛ لینک را بررسی کنید.'),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: galleryImages,
                  minLines: 2,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'تصاویر گالری',
                    hintText: 'هر لینک را در یک خط وارد کنید',
                    helperText: 'تصاویر گالری برای صفحه‌ی جزئیات محصول به‌ترتیب ذخیره می‌شوند.',
                    prefixIcon: Icon(Icons.collections_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Weight', label: Text('وزنی')),
                    ButtonSegment(value: 'Count', label: Text('عددی')),
                  ],
                  selected: {unitType},
                  onSelectionChanged: (value) => setState(() {
                    unitType = value.first;
                    quantity = unitType == 'Weight' ? 250 : 1;
                  }),
                ),
                const SizedBox(height: 10),
                TextFormField(controller: sku, decoration: const InputDecoration(labelText: 'SKU'), validator: required),
                const SizedBox(height: 10),
                TextFormField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'قیمت فروش ریال'),
                  validator: numberRequired,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: costPrice,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'قیمت تمام‌شده ریال', helperText: 'برای محاسبه سود و حاشیه سود استفاده می‌شود.'),
                  validator: numberRequired,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'تعداد بسته موجود'),
                  validator: numberRequired,
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(onPressed: submit, child: const Text('ذخیره پیش‌نویس')),
        ],
      );

  String? required(String? value) => value == null || value.trim().isEmpty ? 'این فیلد الزامی است.' : null;
  String? numberRequired(String? value) => parsePersianNumber(value) == null ? 'عدد معتبر وارد کنید.' : null;

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    setState(() { uploadingImage = true; mediaError = null; });
    try {
      final uploaded = await media.uploadImage(
        fileName: file.name,
        bytes: file.bytes!,
        contentType: _mimeFor(file.name),
      );
      if (mounted) setState(() => primaryImage.text = uploaded.url);
    } catch (exception) {
      if (mounted) setState(() => mediaError = exception.toString());
    } finally {
      if (mounted) setState(() => uploadingImage = false);
    }
  }

  String _mimeFor(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'avif' => 'image/avif',
      _ => 'image/jpeg',
    };
  }

  @override
  void dispose() {
    title.dispose();
    slug.dispose();
    origin.dispose();
    shortDescription.dispose();
    description.dispose();
    seoTitle.dispose();
    seoDescription.dispose();
    seoKeywords.dispose();
    specifications.dispose();
    costPrice.dispose();
    primaryImage.dispose();
    galleryImages.dispose();
    sku.dispose();
    price.dispose();
    stock.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    final label = unitType == 'Weight' ? '${formatPersianInteger(quantity.toInt())} گرم' : '${formatPersianInteger(quantity.toInt())} عدد';
    Navigator.pop(
      context,
      CreateProductCommand(
        title: title.text,
        slug: slug.text,
        category: category,
        origin: origin.text,
        shortDescription: shortDescription.text.trim(),
        description: description.text.trim(),
        seoTitle: seoTitle.text.trim(),
        seoDescription: seoDescription.text.trim(),
        seoKeywords: seoKeywords.text.trim(),
        specifications: {
          for (final line in specifications.text.split('\n'))
            if (line.contains('=')) line.split('=').first.trim(): line.substring(line.indexOf('=') + 1).trim(),
        },
        unitType: unitType,
        isPublished: false,
        primaryImage: primaryImage.text.trim(),
        galleryImages: galleryImages.text.split('\n').map((value) => value.trim()).where((value) => value.isNotEmpty).toList(),
        variants: [
          CreateVariantCommand(
            sku: sku.text,
            quantity: quantity,
            displayLabel: label,
            price: parsePersianNumber(price.text)!,
            costPrice: parsePersianNumber(costPrice.text)!,
            availablePackages: parsePersianInteger(stock.text)!,
          ),
        ],
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, this.api});
  final OrderApiClient? api;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final OrderApiClient api = widget.api ?? OrderApiClient();
  final states = const <String, String>{
    '': 'همه سفارش‌ها',
    'AwaitingPayment': 'در انتظار پرداخت',
    'Paid': 'پرداخت‌شده',
    'Preparing': 'در حال آماده‌سازی',
    'Shipped': 'ارسال‌شده',
    'Delivered': 'تحویل‌شده',
    'Cancelled': 'لغوشده',
    'Expired': 'منقضی‌شده',
  };
  List<AdminOrder> orders = const [];
  List<AdminOverdueShipment> overdueShipments = const [];
  String selectedState = '';
  bool overdueOnly = false;
  int overdueDays = 3;
  final searchController = TextEditingController();
  String searchQuery = '';
  Object? error;
  bool loading = true;
  bool exporting = false;
  final selectedOrders = <String>{};
  bool bulkBusy = false;
  String? busyOrder;

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
      if (overdueOnly) {
        final result = await api.fetchOverdueShipments(days: overdueDays);
        if (mounted) {
          setState(() {
            overdueShipments = result;
            orders = const [];
            selectedOrders.clear();
          });
        }
      } else {
        final result = await api.fetchOrders(state: selectedState.isEmpty ? null : selectedState, query: searchQuery);
        if (mounted) {
          setState(() {
            orders = result;
            overdueShipments = const [];
            selectedOrders.removeWhere((id) => !result.any((order) => order.id == id));
          });
        }
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> advance(AdminOrder order) async {
    final next = order.nextState;
    if (next == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغییر وضعیت سفارش'),
        content: Text('وضعیت سفارش ${order.id.substring(0, 8)} به «${states[next] ?? next}» تغییر کند؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأیید')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busyOrder = order.id);
    try {
      await api.transition(order.id, next);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('وضعیت سفارش به «${states[next] ?? next}» تغییر کرد.')),
        );
      }
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString())));
    } finally {
      if (mounted) setState(() => busyOrder = null);
    }
  }

  Future<void> openDetail(AdminOrder order) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OrderDetailSheet(api: api, order: order),
      );

  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final bytes = await api.exportOrdersCsv(state: selectedState.isEmpty ? null : selectedState, query: searchQuery);
      final opened = await launchUrl(
        Uri.dataFromBytes(bytes, mimeType: 'text/csv', parameters: {'charset': 'utf-8'}),
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خروجی باز نشد؛ اجازه بازکردن صفحه جدید را بررسی کنید.')));
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> bulkAdvance(String next) async {
    if (selectedOrders.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغییر وضعیت گروهی'),
        content: Text('${formatPersianInteger(selectedOrders.length)} سفارش به «${states[next] ?? next}» منتقل شود؟ سفارش‌هایی که مسیرشان مجاز نباشد، جدا گزارش می‌شوند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأیید عملیات')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => bulkBusy = true);
    try {
      final result = await api.bulkTransition(selectedOrders.toList(), next, reason: 'عملیات گروهی از پنل');
      await load();
      if (mounted) {
        setState(() => selectedOrders.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${formatPersianInteger(result.$1)} سفارش به‌روزرسانی شد${result.$2 == 0 ? '' : ' و ${formatPersianInteger(result.$2)} مورد نیازمند بررسی است.'}')),
        );
      }
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, constraints) {
            final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('سفارش‌ها', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const Text('فرآیند سفارش را از پرداخت تا تحویل کنترل کنید.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ]);
            final controls = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FilterChip(
                label: const Text('ارسال‌های تأخیردار'),
                selected: overdueOnly,
                onSelected: (value) {
                  setState(() {
                    overdueOnly = value;
                    selectedOrders.clear();
                  });
                  load();
                },
              ),
              if (overdueOnly)
                DropdownButton<int>(
                  value: overdueDays,
                  items: const [1, 3, 5, 7, 14].map((days) => DropdownMenuItem(value: days, child: Text('بیش از $days روز'))).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => overdueDays = value);
                    load();
                  },
                ),
              DropdownButton<String>(
                value: selectedState,
                items: states.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedState = value);
                  load();
                },
              ),
              FilledButton.tonalIcon(
                onPressed: exporting ? null : exportCsv,
                icon: exporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_download_outlined),
                label: const Text('خروجی CSV'),
              ),
              if (selectedOrders.isNotEmpty)
                PopupMenuButton<String>(
                  onSelected: bulkAdvance,
                  itemBuilder: (_) => states.entries
                      .where((entry) => entry.key.isNotEmpty)
                      .map((entry) => PopupMenuItem(value: entry.key, child: Text('انتقال به ${entry.value}')))
                      .toList(),
                  child: FilledButton.tonalIcon(
                    onPressed: bulkBusy ? null : () {},
                    icon: bulkBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.playlist_add_check_rounded),
                    label: Text('عملیات گروهی (${formatPersianInteger(selectedOrders.length)})'),
                  ),
                ),
              IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
            ]);
            return constraints.maxWidth < 560
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heading, const SizedBox(height: 10), controls])
                : Row(children: [Expanded(child: heading), controls]);
          }),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              setState(() => searchQuery = value.trim());
              load();
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'جست‌وجو با شماره سفارش، نام، موبایل یا شهر',
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'پاک‌کردن جست‌وجو',
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchQuery = '');
                        load();
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: _body()),
        ]),
      );

  Widget _overdueBody() {
    if (overdueShipments.isEmpty) {
      return const Center(
        child: AdminEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'ارسال تأخیردار پیدا نشد',
          detail: 'سفارش‌های ارسال‌شدهٔ قدیمی‌تر از بازه انتخابی اینجا نمایش داده می‌شوند.',
        ),
      );
    }
    return ListView.separated(
      itemCount: overdueShipments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final shipment = overdueShipments[index];
        return Card(
          child: InkWell(
            onTap: () => openDetail(shipment.toAdminOrder()),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                spacing: 18,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('سفارش ${shipment.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(shipment.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${shipment.province}، ${shipment.city} · ${formatPersianInteger(shipment.lineCount)} قلم', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                  ),
                  Chip(
                    label: Text('${formatPersianInteger(shipment.daysOverdue)} روز تأخیر'),
                    backgroundColor: const Color(0xFFFCE6E0),
                  ),
                  Text(
                    shipment.trackingCode?.isNotEmpty == true ? 'رهگیری: ${shipment.trackingCode}' : 'کد رهگیری ثبت نشده',
                    style: const TextStyle(fontSize: 11, color: AdminColors.muted),
                  ),
                  Text(
                    shipment.shippingCarrier?.isNotEmpty == true ? shipment.shippingCarrier! : 'شرکت حمل ثبت نشده',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('ارسال: ${formatPersianDateTime(shipment.shippedAt)}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                  const Icon(Icons.chevron_left_rounded, color: AdminColors.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    if (overdueOnly) return _overdueBody();
    if (orders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_rounded, size: 56, color: Color(0xFF9EACA1)),
          const SizedBox(height: 12),
          AdminEmptyState(
            icon: Icons.receipt_long_rounded,
            title: selectedState.isEmpty ? 'هنوز سفارشی ثبت نشده است' : 'سفارشی با این وضعیت وجود ندارد',
            detail: searchQuery.isNotEmpty
                ? 'عبارت جست‌وجو یا فیلتر وضعیت را تغییر دهید.'
                : selectedState.isEmpty
                    ? 'سفارش‌های جدید بعد از ثبت در این فهرست دیده می‌شوند.'
                    : 'فیلتر وضعیت را تغییر دهید یا همه سفارش‌ها را ببینید.',
          ),
        ]),
      );
    }
    return ListView.separated(
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final order = orders[index];
        final next = order.nextState;
        final busy = busyOrder == order.id;
        return Card(
          child: InkWell(
            onTap: () => openDetail(order),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 14,
              spacing: 20,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Checkbox(
                  value: selectedOrders.contains(order.id),
                  onChanged: bulkBusy ? null : (value) => setState(() => value == true ? selectedOrders.add(order.id) : selectedOrders.remove(order.id)),
                  semanticLabel: 'انتخاب سفارش ${order.id.substring(0, 8)} برای عملیات گروهی',
                ),
                SizedBox(
                  width: 210,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سفارش ${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${order.province}، ${order.city} · ${formatPersianInteger(order.lineCount)} قلم', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                ),
                Chip(
                  label: Text(states[order.state] ?? order.state),
                  backgroundColor: const Color(0xFFE7F1E2),
                ),
                Text('${formatPersianNumber(order.payable)} ${order.currency}', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (next != null)
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : () => advance(order),
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text('مرحله بعد: ${states[next] ?? next}'),
                  )
                else
                  const Text('فرآیند تکمیل شده', style: TextStyle(color: Color(0xFF31584A), fontWeight: FontWeight.w700)),
                const Icon(Icons.chevron_left_rounded, color: AdminColors.muted),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}


class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({required this.api, required this.order});
  final OrderApiClient api;
  final AdminOrder order;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  AdminOrderDetail? detail;
  Object? error;
  bool loading = true;
  bool savingNote = false;
  bool savingShipping = false;
  bool openingPackingSlip = false;
  final noteController = TextEditingController();
  final carrierController = TextEditingController();
  final trackingController = TextEditingController();
  final shippingExpenseController = TextEditingController();

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
      final result = await widget.api.fetchOrderDetail(widget.order.id);
      if (mounted) {
        carrierController.text = result.shippingCarrier ?? '';
        trackingController.text = result.trackingCode ?? '';
        shippingExpenseController.text = result.shippingExpense == 0 ? '' : formatPersianNumber(result.shippingExpense);
        setState(() => detail = result);
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    carrierController.dispose();
    trackingController.dispose();
    shippingExpenseController.dispose();
    super.dispose();
  }

  Future<void> saveNote() async {
    final note = noteController.text.trim();
    if (note.isEmpty) return;
    setState(() => savingNote = true);
    try {
      await widget.api.addOrderNote(widget.order.id, note);
      noteController.clear();
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('یادداشت داخلی ثبت شد.')));
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => savingNote = false);
    }
  }

  Future<void> saveShipping() async {
    final expense = shippingExpenseController.text.trim().isEmpty ? null : parsePersianNumber(shippingExpenseController.text);
    if (shippingExpenseController.text.trim().isNotEmpty && (expense == null || expense < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هزینه واقعی ارسال را به‌صورت عدد معتبر وارد کنید.')));
      return;
    }
    setState(() => savingShipping = true);
    try {
      final result = await widget.api.updateShipping(widget.order.id, carrier: carrierController.text.trim().isEmpty ? null : carrierController.text.trim(), trackingCode: trackingController.text.trim().isEmpty ? null : trackingController.text.trim(), actualShippingCost: expense);
      if (mounted) {
        setState(() => detail = result);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اطلاعات ارسال ذخیره شد.')));
      }
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => savingShipping = false);
    }
  }

  Future<void> openPackingSlip() async {
    setState(() => openingPackingSlip = true);
    try {
      final html = await widget.api.fetchPackingSlipHtml(widget.order.id);
      final opened = await launchUrl(
        Uri.dataFromString(html, mimeType: 'text/html', encoding: utf8),
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برگه باز نشد؛ اجازه بازکردن صفحه جدید را بررسی کنید.')));
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => openingPackingSlip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? AdminErrorState(error: error!, onRetry: load)
            : _content(detail!);
    return Material(
      color: AdminColors.canvas,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(children: [
              Expanded(child: Text('جزئیات سفارش', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), tooltip: 'بستن', icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }

  Widget _content(AdminOrderDetail detail) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('سفارش ${detail.order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Chip(label: Text(_stateLabel(detail.order.state)), backgroundColor: AdminColors.mintSoft),
            FilledButton.tonalIcon(
              onPressed: openingPackingSlip ? null : openPackingSlip,
              icon: openingPackingSlip ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.inventory_2_outlined),
              label: const Text('برگه بسته‌بندی'),
            ),
          ]),
          const SizedBox(height: 16),
          _detailCard(title: 'مشتری و تحویل', icon: Icons.person_pin_circle_outlined, child: Wrap(spacing: 28, runSpacing: 14, children: [
            _detailValue('مشتری', detail.order.customerName),
            _detailValue('تماس', detail.order.mobile),
            _detailValue('شهر', '${detail.order.province}، ${detail.order.city}'),
            _detailValue('روش ارسال', detail.shippingMethod),
            _detailValue('نشانی', detail.address, width: 320),
            _detailValue('کد پستی', detail.postalCode),
          ])),
          const SizedBox(height: 12),
          _detailCard(title: 'ارسال و هزینه واقعی', icon: Icons.local_shipping_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: 220, child: TextField(controller: carrierController, decoration: const InputDecoration(labelText: 'شرکت حمل'))),
              SizedBox(width: 220, child: TextField(controller: trackingController, decoration: const InputDecoration(labelText: 'کد رهگیری'))),
              SizedBox(width: 220, child: TextField(controller: shippingExpenseController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'هزینه واقعی ارسال', suffixText: 'ریال'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text(detail.shippedAt == null ? 'هنوز زمان ارسال ثبت نشده است.' : 'ارسال‌شده در ${formatPersianDateTime(detail.shippedAt!)}', style: const TextStyle(fontSize: 11, color: AdminColors.muted))),
              FilledButton.tonalIcon(onPressed: savingShipping ? null : saveShipping, icon: savingShipping ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('ذخیره ارسال')),
            ]),
          ])),
          const SizedBox(height: 12),
          _detailCard(title: 'اقلام سفارش', icon: Icons.shopping_bag_outlined, child: detail.lines.isEmpty
              ? const AdminEmptyState(icon: Icons.shopping_bag_outlined, title: 'قلمی ثبت نشده است', detail: 'اطلاعات اقلام این سفارش در دسترس نیست.')
              : Column(children: [for (var i = 0; i < detail.lines.length; i++) ...[
                  if (i > 0) const Divider(height: 22),
                  _lineRow(detail.lines[i]),
                ]])),
          const SizedBox(height: 12),
          _detailCard(title: 'جمع سفارش', icon: Icons.receipt_long_outlined, child: Column(children: [
            _moneyRow('جمع کالا', detail.subtotal, detail.order.currency),
            _moneyRow('ارسال', detail.shipping, detail.order.currency),
            if (detail.discount > 0) _moneyRow('تخفیف', -detail.discount, detail.order.currency),
            _moneyRow('مالیات', detail.tax, detail.order.currency),
            const Divider(height: 20),
            _moneyRow('مبلغ نهایی', detail.order.payable, detail.order.currency, strong: true),
            if (detail.shippingExpense > 0) _moneyRow('هزینه واقعی ارسال', detail.shippingExpense, detail.order.currency),
          ])),
          if (detail.payment != null) ...[
            const SizedBox(height: 12),
            _detailCard(title: 'پرداخت', icon: Icons.payments_outlined, child: Wrap(spacing: 28, runSpacing: 14, children: [
              _detailValue('وضعیت', detail.payment!.state),
              _detailValue('درگاه', detail.payment!.provider),
              _detailValue('مبلغ', '${formatPersianNumber(detail.payment!.amount)} ${detail.payment!.currency}'),
              if (detail.payment!.reference != null) _detailValue('شناسه پیگیری', detail.payment!.reference!),
            ])),
          ],
          const SizedBox(height: 12),
          _detailCard(title: 'مسیر سفارش', icon: Icons.route_rounded, child: detail.transitions.isEmpty
              ? const AdminEmptyState(icon: Icons.route_rounded, title: 'تاریخچه‌ای ثبت نشده است', detail: 'تغییرات وضعیت این سفارش هنوز ثبت نشده است.')
              : Column(children: [for (var i = 0; i < detail.transitions.length; i++) _timelineRow(detail.transitions[i], isLast: i == detail.transitions.length - 1)])),
          const SizedBox(height: 12),
          _detailCard(title: 'یادداشت داخلی', icon: Icons.sticky_note_2_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (detail.notes.isEmpty)
              const AdminEmptyState(icon: Icons.sticky_note_2_outlined, title: 'هنوز یادداشتی ثبت نشده است', detail: 'برای هماهنگی با همکاران، نتیجه تماس یا نکته مهم سفارش را اینجا بنویسید.'),
            if (detail.notes.isNotEmpty) ...[
              for (var i = 0; i < detail.notes.length; i++) ...[
                if (i > 0) const Divider(height: 22),
                _noteRow(detail.notes[i]),
              ],
              const SizedBox(height: 14),
            ],
            TextField(controller: noteController, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'یادداشت جدید', hintText: 'مثلاً: مشتری زمان تحویل را تأیید کرد.')),
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: savingNote ? null : saveNote, icon: savingNote ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('ثبت یادداشت'))),
          ])),
        ],
      );

  Widget _detailCard({required String title, required IconData icon, required Widget child}) => Card(
        child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 20, color: AdminColors.ink), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.inkDeep))]),
          const SizedBox(height: 16),
          child,
        ])),
      );

  Widget _detailValue(String label, String value, {double? width}) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AdminColors.muted)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );

  Widget _lineRow(AdminOrderLine line) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(line.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${line.variantLabel} · ${line.sku}', style: const TextStyle(fontSize: 11, color: AdminColors.muted))])),
        Text('${formatPersianInteger(line.quantity)} × ${formatPersianNumber(line.unitPrice)}', style: const TextStyle(fontSize: 12, color: AdminColors.muted)),
        const SizedBox(width: 12),
        Text('${formatPersianNumber(line.lineTotal)} ریال', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]);

  Widget _moneyRow(String label, num value, String currency, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: strong ? AdminColors.inkDeep : AdminColors.muted, fontWeight: strong ? FontWeight.w900 : FontWeight.w500))), Text('${formatPersianNumber(value)} $currency', style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, color: value < 0 ? AdminColors.coral : AdminColors.inkDeep))]),
      );

  Widget _timelineRow(AdminOrderTransition item, {required bool isLast}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 28, child: Column(children: [Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: AdminColors.ink)), if (!isLast) Container(width: 1, height: 48, color: AdminColors.border)])),
        Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_stateLabel(item.state), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${formatPersianDateTime(item.occurredAt)} · ${item.actor}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)), if (item.reason.isNotEmpty) Text(item.reason, style: const TextStyle(fontSize: 12, color: AdminColors.muted))]))),
      ]);

  Widget _noteRow(AdminOrderNote item) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.note, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
        const SizedBox(height: 4),
        Text('${formatPersianDateTime(item.createdAt)} · ${item.actor}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
      ]);

  String _stateLabel(String value) => const {
        'AwaitingPayment': 'در انتظار پرداخت', 'Paid': 'پرداخت‌شده', 'Preparing': 'در حال آماده‌سازی',
        'Shipped': 'ارسال‌شده', 'Delivered': 'تحویل‌شده', 'Cancelled': 'لغوشده', 'Expired': 'منقضی‌شده',
      }[value] ?? value;
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, this.catalog, this.orders});
  final CatalogApiClient? catalog;
  final OrderApiClient? orders;
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final CatalogApiClient catalog = widget.catalog ?? CatalogApiClient();
  late final OrderApiClient orders = widget.orders ?? OrderApiClient();
  List<Product> products = const [];
  List<StockMovement> movements = const [];
  List<InventoryBatch> batches = const [];
  Object? error;
  bool loading = true;
  String? busySku;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Future.wait([
        catalog.fetchProducts(includeDrafts: true),
        orders.fetchInventoryMovements(limit: 30),
        orders.fetchInventoryBatches(includeExpired: true, limit: 50),
      ]);
      if (mounted) setState(() {
        products = result[0] as List<Product>;
        movements = result[1] as List<StockMovement>;
        batches = result[2] as List<InventoryBatch>;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> adjust(ProductVariant variant) async {
    final result = await showDialog<_AdjustmentCommand>(
      context: context, builder: (_) => AdjustmentDialog(variant: variant),
    );
    if (result == null) return;
    setState(() => busySku = variant.sku);
    try {
      await orders.adjustStock(variant.sku, result.delta, result.reason);
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('موجودی با موفقیت ثبت شد.')));
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString())));
    } finally {
      if (mounted) setState(() => busySku = null);
    }
  }

  Future<void> receiveBatch() async {
    final result = await showDialog<_BatchCommand>(context: context, builder: (_) => BatchDialog(products: products));
    if (result == null) return;
    setState(() => busySku = result.sku);
    try {
      await orders.receiveInventoryBatch(
        sku: result.sku,
        batchCode: result.batchCode,
        receivedPackages: result.receivedPackages,
        producedAt: result.producedAt,
        expiresAt: result.expiresAt,
        costPrice: result.costPrice,
        packagingCost: result.packagingCost,
        additionalCost: result.additionalCost,
      );
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بچ و تاریخ انقضا ثبت شد.')));
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString())));
    } finally {
      if (mounted) setState(() => busySku = null);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مدیریت انبار', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const Text('موجودی هر SKU، اصلاحات دستی و دفترچه گردش کالا را یکجا کنترل کنید.', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ])),
        OutlinedButton.icon(onPressed: products.isEmpty ? null : receiveBatch, icon: const Icon(Icons.event_available_rounded), label: const Text('دریافت بچ')),
        const SizedBox(width: 8),
        IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
      ]),
      const SizedBox(height: 18),
      Expanded(child: _body()),
    ]),
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100 ? 2 : 1;
      final expiredCount = batches.where((item) => item.isExpired && item.remainingPackages > 0).length;
      final expiringCount = batches.where((item) => item.isExpiringSoon && item.remainingPackages > 0).length;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (expiredCount > 0 || expiringCount > 0) ...[
          _InventoryAttentionBanner(expiredCount: expiredCount, expiringCount: expiringCount),
          const SizedBox(height: 14),
        ],
        Expanded(child: GridView.count(
          crossAxisCount: columns, mainAxisSpacing: 14, crossAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 2.7 : 1.9,
          children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('موجودی محصولات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            Expanded(child: ListView.separated(
              itemCount: products.fold<int>(0, (sum, item) => sum + item.variants.length),
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (_, index) {
                var offset = index;
                Product? product;
                ProductVariant? variant;
                for (final candidate in products) {
                  if (offset < candidate.variants.length) { product = candidate; variant = candidate.variants[offset]; break; }
                  offset -= candidate.variants.length;
                }
                if (product == null || variant == null) return const SizedBox.shrink();
                final low = variant.availablePackages <= 5;
                final busy = busySku == variant.sku;
                return Row(children: [
                  CircleAvatar(backgroundColor: low ? const Color(0xFFFFE8C8) : const Color(0xFFE7F1E2), child: Text(formatPersianInteger(variant.availablePackages))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(product.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${variant.displayLabel} · ${variant.sku}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ])),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : () => adjust(variant!),
                    icon: busy ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.tune_rounded),
                    label: const Text('اصلاح'),
                  ),
                ]);
              },
            )),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('آخرین گردش موجودی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            Expanded(child: movements.isEmpty ? const Center(child: AdminEmptyState(icon: Icons.swap_vert_rounded, title: 'گردشی ثبت نشده است', detail: 'دریافت، فروش یا اصلاح موجودی در اینجا ثبت می‌شود.')) : ListView.separated(
              itemCount: movements.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (_, index) {
                final item = movements[index];
                final positive = item.quantityDelta >= 0;
                final sign = positive ? '+' : '-';
                return ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: positive ? const Color(0xFFE7F1E2) : const Color(0xFFFFE8C8),
                    child: Icon(positive ? Icons.add_rounded : Icons.remove_rounded, size: 18),
                  ),
                  title: Text('${item.sku} · $sign${formatPersianInteger(item.quantityDelta.abs())}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.reason} · مانده ${formatPersianInteger(item.balanceAfter)}', style: const TextStyle(fontSize: 11)),
                );
              },
            )),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('بچ‌ها و تاریخ انقضا', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            Expanded(child: batches.isEmpty ? const Center(child: AdminEmptyState(icon: Icons.event_available_rounded, title: 'هنوز بچی ثبت نشده است', detail: 'برای کنترل FEFO، اولین دریافت کالا را ثبت کنید.')) : ListView.separated(
              itemCount: batches.length,
              separatorBuilder: (_, __) => const Divider(height: 14),
              itemBuilder: (_, index) {
                final item = batches[index];
                final expired = item.isExpired;
                final expiringSoon = item.isExpiringSoon && !expired;
                return ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: Icon(expired || expiringSoon ? Icons.warning_amber_rounded : Icons.event_available_rounded, color: expired ? AdminColors.coral : expiringSoon ? AdminColors.amber : AdminColors.ink),
                  title: Text('${item.productTitle} · ${item.batchCode}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.sku} · مانده ${formatPersianInteger(item.remainingPackages)} · ${expired ? 'منقضی شده' : expiringSoon ? 'نزدیک انقضا' : 'انقضا'} ${formatPersianDateTime(item.expiresAt)}', style: TextStyle(fontSize: 11, color: expired ? AdminColors.coral : expiringSoon ? const Color(0xFF9A661D) : AdminColors.muted)),
                );
              },
            )),
          ]))),
          ],
        )),
      ]);
    });
  }
}

class _InventoryAttentionBanner extends StatelessWidget {
  const _InventoryAttentionBanner({required this.expiredCount, required this.expiringCount});

  final int expiredCount;
  final int expiringCount;

  @override
  Widget build(BuildContext context) {
    final expiredText = expiredCount == 0 ? '' : '${formatPersianInteger(expiredCount)} بچ منقضی با موجودی باقی‌مانده';
    final expiringText = expiringCount == 0 ? '' : '${formatPersianInteger(expiringCount)} بچ تا ۳۰ روز آینده منقضی می‌شود';
    final detail = [expiredText, expiringText].where((value) => value.isNotEmpty).join(' · ');
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'هشدار موجودی: $detail',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: expiredCount > 0 ? const Color(0xFFFFECE8) : const Color(0xFFFFF5DF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: expiredCount > 0 ? const Color(0xFFF1C5BB) : const Color(0xFFF0D69A)),
        ),
        child: Row(children: [
          Icon(expiredCount > 0 ? Icons.priority_high_rounded : Icons.schedule_rounded, color: expiredCount > 0 ? AdminColors.coral : const Color(0xFF9A661D)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(detail, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4)),
            const SizedBox(height: 3),
            const Text('اولویت با برداشت FEFO', style: TextStyle(fontSize: 11, color: AdminColors.muted)),
          ])),
        ]),
      ),
    );
  }
}

class _BatchCommand {
  const _BatchCommand({
    required this.sku,
    required this.batchCode,
    required this.receivedPackages,
    required this.producedAt,
    required this.expiresAt,
    required this.costPrice,
    required this.packagingCost,
    required this.additionalCost,
  });

  final String sku;
  final String batchCode;
  final int receivedPackages;
  final DateTime producedAt;
  final DateTime expiresAt;
  final num costPrice;
  final num packagingCost;
  final num additionalCost;
}

class BatchDialog extends StatefulWidget {
  const BatchDialog({super.key, required this.products});

  final List<Product> products;

  @override
  State<BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<BatchDialog> {
  final formKey = GlobalKey<FormState>();
  late String sku;
  final batchCode = TextEditingController();
  final received = TextEditingController();
  final produced = TextEditingController();
  final expires = TextEditingController();
  final cost = TextEditingController(text: '۰');
  final packaging = TextEditingController(text: '۰');
  final additional = TextEditingController(text: '۰');

  @override
  void initState() {
    super.initState();
    sku = widget.products.first.variants.first.sku;
  }

  DateTime? parseDate(String value) => DateTime.tryParse(value.trim());

  num parseNumber(String value) => parsePersianNumber(value) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('دریافت بچ جدید'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: sku,
                  decoration: const InputDecoration(labelText: 'SKU'),
                  items: widget.products
                      .expand(
                        (product) => product.variants.map(
                          (variant) => DropdownMenuItem<String>(
                            value: variant.sku,
                            child: Text('\${product.title} · \${variant.sku}'),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => sku = value ?? sku),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: batchCode,
                  decoration: const InputDecoration(labelText: 'کد بچ', hintText: 'LOT-1405-01'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'کد بچ الزامی است.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: received,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'تعداد بسته دریافتی'),
                  validator: (value) {
                    final number = parsePersianInteger(value);
                    return number == null || number <= 0 ? 'تعداد مثبت وارد کنید.' : null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: produced,
                        decoration: const InputDecoration(labelText: 'تولید (YYYY-MM-DD)'),
                        validator: (value) => parseDate(value ?? '') == null ? 'تاریخ معتبر وارد کنید.' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: expires,
                        decoration: const InputDecoration(labelText: 'انقضا (YYYY-MM-DD)'),
                        validator: (value) => parseDate(value ?? '') == null ? 'تاریخ معتبر وارد کنید.' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'خرید/مواد (ریال)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: packaging, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'بسته‌بندی (ریال)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: additional, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'جانبی (ریال)'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            final productionDate = parseDate(produced.text)!;
            final expiryDate = parseDate(expires.text)!;
            if (!expiryDate.isAfter(productionDate)) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('انقضا باید بعد از تولید باشد.')));
              return;
            }
            final receivedPackages = parsePersianInteger(received.text) ?? 0;
            Navigator.pop(
              context,
              _BatchCommand(
                sku: sku,
                batchCode: batchCode.text.trim(),
                receivedPackages: receivedPackages,
                producedAt: productionDate,
                expiresAt: expiryDate,
                costPrice: parseNumber(cost.text),
                packagingCost: parseNumber(packaging.text),
                additionalCost: parseNumber(additional.text),
              ),
            );
          },
          child: const Text('ثبت بچ'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    batchCode.dispose();
    received.dispose();
    produced.dispose();
    expires.dispose();
    cost.dispose();
    packaging.dispose();
    additional.dispose();
    super.dispose();
  }
}

class _AdjustmentCommand {
  const _AdjustmentCommand(this.delta, this.reason);
  final int delta;
  final String reason;
}

class AdjustmentDialog extends StatefulWidget {
  const AdjustmentDialog({super.key, required this.variant});
  final ProductVariant variant;
  @override
  State<AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<AdjustmentDialog> {
  final formKey = GlobalKey<FormState>();
  final delta = TextEditingController();
  final reason = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('اصلاح موجودی ${widget.variant.sku}'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('موجودی فعلی: ${formatPersianInteger(widget.variant.availablePackages)} بسته'),
            const SizedBox(height: 12),
            TextFormField(
              controller: delta,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'تغییر موجودی',
                hintText: 'مثبت برای ورود، منفی برای خروج',
              ),
              validator: (value) => parsePersianInteger(value) == null ? 'عدد معتبر وارد کنید.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'علت اصلاح'),
              validator: (value) => value == null || value.trim().isEmpty ? 'علت را وارد کنید.' : null,
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(context, _AdjustmentCommand(parsePersianInteger(delta.text)!, reason.text.trim()));
          },
          child: const Text('ثبت اصلاح'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    delta.dispose();
    reason.dispose();
    super.dispose();
  }
}


class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, this.api});
  final OrderApiClient? api;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final OrderApiClient api = widget.api ?? OrderApiClient();
  AdminAnalytics? analytics;
  List<AdminProductProfitability> profitability = const [];
  int days = 30;
  bool loading = true;
  Object? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Future.wait([
        api.fetchAnalytics(days: days),
        api.fetchProductProfitability(days: days),
      ]);
      if (mounted) setState(() {
        analytics = result[0] as AdminAnalytics;
        profitability = result[1] as List<AdminProductProfitability>;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('گزارش‌ها', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
          const SizedBox(height: 6),
          const Text('عملکرد فروش و سود را در یک نمای ساده و قابل تصمیم‌گیری ببینید.', style: TextStyle(color: AdminColors.muted)),
        ])),
        IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
      ]),
      const SizedBox(height: 20),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 7, label: Text('۷ روز')),
          ButtonSegment(value: 30, label: Text('۳۰ روز')),
          ButtonSegment(value: 90, label: Text('۹۰ روز')),
        ],
        selected: {days},
        onSelectionChanged: (value) {
          setState(() => days = value.first);
          load();
        },
      ),
      const SizedBox(height: 20),
      Expanded(child: _body()),
    ]),
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    final data = analytics!;
    if (data.orderCount == 0) return const Center(child: Text('برای این بازه هنوز داده‌ی فروش ثبت نشده است.', style: TextStyle(color: AdminColors.muted)));
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1050 ? 3 : constraints.maxWidth >= 680 ? 2 : 1;
      return ListView(children: [
        GridView.count(
          crossAxisCount: columns, crossAxisSpacing: 14, mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.2 : 1.9, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ReportMetric(title: 'درآمد شامل ارسال', value: '${formatPersianNumber(data.revenue)} ریال', icon: Icons.trending_up_rounded, tint: AdminColors.mintSoft),
            _ReportMetric(title: 'هزینه مواد و بسته‌بندی', value: '${formatPersianNumber(data.cost)} ریال', icon: Icons.inventory_2_rounded, tint: const Color(0xFFFFF0D9)),
            _ReportMetric(title: 'هزینه واقعی ارسال', value: '${formatPersianNumber(data.shippingExpense)} ریال', icon: Icons.local_shipping_rounded, tint: const Color(0xFFEAF3EE)),
            _ReportMetric(title: 'مالیات پرداختنی', value: '${formatPersianNumber(data.tax)} ریال', icon: Icons.account_balance_rounded, tint: const Color(0xFFFCE6E0)),
            _ReportMetric(title: 'سود خالص', value: '${formatPersianNumber(data.netProfit)} ریال', icon: Icons.account_balance_wallet_rounded, tint: const Color(0xFFE6EEF8)),
            _ReportMetric(title: 'حاشیه سود ناخالص', value: '${formatPersianNumber(data.grossMarginPercent, fractionDigits: 1)}٪', icon: Icons.percent_rounded, tint: const Color(0xFFFCE6E0)),
            _ReportMetric(title: 'تعداد سفارش', value: formatPersianInteger(data.orderCount), icon: Icons.receipt_long_rounded, tint: const Color(0xFFEDE8F8)),
            _ReportMetric(title: 'واحد فروخته‌شده', value: formatPersianInteger(data.unitsSold), icon: Icons.shopping_bag_rounded, tint: const Color(0xFFEAF3EE)),
          ],
        ),
        const SizedBox(height: 18),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('خلاصه‌ی تصمیم‌گیری', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AdminColors.inkDeep)),
          const SizedBox(height: 12),
          Text(
            'در ${formatPersianInteger(data.days)} روز گذشته، ${formatPersianInteger(data.orderCount)} سفارش با ${formatPersianInteger(data.unitsSold)} واحد ثبت شده است. '
            'هزینهٔ مواد، بسته‌بندی و جانبی ${formatPersianNumber(data.cost)} ریال، هزینهٔ واقعی ارسال ${formatPersianNumber(data.shippingExpense)} ریال، مالیات پرداختنی ${formatPersianNumber(data.tax)} ریال و سود خالص ${formatPersianNumber(data.netProfit)} ریال بوده است.',
            style: const TextStyle(height: 1.7, color: AdminColors.muted),
          ),
        ]))),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('سود به تفکیک محصول و Variant', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AdminColors.inkDeep)),
              const SizedBox(height: 6),
              const Text('هزینه از snapshot قیمت خرید، بسته‌بندی و هزینه جانبی هر سفارش خوانده می‌شود.', style: TextStyle(color: AdminColors.muted, fontSize: 12)),
              const SizedBox(height: 14),
              if (profitability.isEmpty)
                const AdminEmptyState(icon: Icons.query_stats_rounded, title: 'برای این بازه محصولی فروخته نشده است', detail: 'با ثبت سفارش پرداخت‌شده، سود هر SKU در اینجا نمایش داده می‌شود.')
              else
                Column(
                  children: [
                    for (final item in profitability.take(20))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          runSpacing: 8,
                          spacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SizedBox(
                              width: 220,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${item.variantLabel} · ${item.sku}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                              ]),
                            ),
                            Text('${formatPersianInteger(item.unitsSold)} واحد', style: const TextStyle(color: AdminColors.muted)),
                            Text('فروش ${formatPersianNumber(item.revenue)} ریال', style: const TextStyle(fontSize: 12)),
                            Text('سود ${formatPersianNumber(item.grossProfit)} ریال', style: TextStyle(fontWeight: FontWeight.w900, color: item.grossProfit < 0 ? AdminColors.coral : AdminColors.ink)),
                          ],
                        ),
                      ),
                  ],
                ),
            ]),
          ),
        ),
      ]);
    });
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.title, required this.value, required this.icon, required this.tint});
  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
    CircleAvatar(backgroundColor: tint, foregroundColor: AdminColors.ink, child: Icon(icon)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(title, style: const TextStyle(fontSize: 12, color: AdminColors.muted, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
    ])),
  ])));
}

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key, required this.api, required this.initial, required this.onChanged});
  final CatalogApiClient api;
  final List<Category> initial;
  final Future<void> Function() onChanged;
  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  late List<Category> categories = [...widget.initial];
  bool saving = false;
  String? error;
  String query = '';
  bool activeOnly = false;

  Future<void> addCategory() async {
    final command = await showDialog<CreateCategoryCommand>(context: context, builder: (_) => const CategoryDialog());
    if (command == null) return;
    setState(() { saving = true; error = null; });
    try {
      final created = await widget.api.createCategory(command);
      if (mounted) setState(() => categories = [...categories, created]);
      await widget.onChanged();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editCategory(Category item) async {
    final command = await showDialog<CreateCategoryCommand>(context: context, builder: (_) => CategoryDialog(initial: item));
    if (command == null) return;
    setState(() { saving = true; error = null; });
    try {
      await widget.api.updateCategory(item.slug, UpdateCategoryCommand(name: command.name, slug: command.slug, description: command.description, seoTitle: command.seoTitle, seoDescription: command.seoDescription, sortOrder: command.sortOrder, isActive: command.isActive));
      await widget.onChanged();
      if (mounted) setState(() => categories = [...categories.where((category) => category.id != item.id), Category(id: item.id, name: command.name, slug: command.slug, description: command.description, seoTitle: command.seoTitle, seoDescription: command.seoDescription, sortOrder: command.sortOrder, isActive: command.isActive)]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
    } catch (exception) { if (mounted) setState(() => error = exception.toString()); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> toggleCategory(Category item) async {
    setState(() { saving = true; error = null; });
    try { await widget.api.setCategoryActive(item.slug, !item.isActive); await widget.onChanged(); if (mounted) setState(() => categories = [for (final category in categories) category.id == item.id ? Category(id: category.id, name: category.name, slug: category.slug, description: category.description, seoTitle: category.seoTitle, seoDescription: category.seoDescription, sortOrder: category.sortOrder, isActive: !category.isActive) : category]); }
    catch (exception) { if (mounted) setState(() => error = exception.toString()); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> deleteCategory(Category item) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('حذف دسته‌بندی؟'), content: Text('دستهٔ «${item.name}» فقط اگر محصولی به آن متصل نباشد حذف می‌شود. در غیر این صورت، دسته را غیرفعال کنید.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف امن'))]));
    if (confirmed != true) return;
    setState(() { saving = true; error = null; });
    try { await widget.api.deleteCategory(item.slug); await widget.onChanged(); if (mounted) setState(() => categories.removeWhere((category) => category.id == item.id)); }
    catch (exception) { if (mounted) setState(() => error = exception.toString()); }
    finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('مدیریت دسته‌بندی‌ها'),
    content: SizedBox(
      width: 520,
      height: 360,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('دسته‌ها مسیر پیدا کردن محصول در فروشگاه هستند. نام و شناسه آدرس را خوانا و پایدار انتخاب کنید.', style: TextStyle(color: AdminColors.muted, fontSize: 12, height: 1.5)),
        const SizedBox(height: 14),
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'جست‌وجوی نام یا شناسه'), onChanged: (value) => setState(() => query = value.trim().toLowerCase())),
        Row(children: [FilterChip(label: const Text('فقط فعال‌ها'), selected: activeOnly, onSelected: (value) => setState(() => activeOnly = value)), const Spacer(), Text('${formatPersianInteger(categories.where((item) => (!activeOnly || item.isActive) && (query.isEmpty || item.name.toLowerCase().contains(query) || item.slug.toLowerCase().contains(query))).length)} دسته', style: const TextStyle(color: AdminColors.muted, fontSize: 12))]),
        if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: const TextStyle(color: AdminColors.coral))),
        Expanded(
          child: categories.where((item) => (!activeOnly || item.isActive) && (query.isEmpty || item.name.toLowerCase().contains(query) || item.slug.toLowerCase().contains(query))).isEmpty
              ? const Center(child: Text('هنوز دسته‌ای تعریف نشده است.'))
              : ListView.separated(
                  itemCount: categories.where((item) => (!activeOnly || item.isActive) && (query.isEmpty || item.name.toLowerCase().contains(query) || item.slug.toLowerCase().contains(query))).length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final item = categories.where((item) => (!activeOnly || item.isActive) && (query.isEmpty || item.name.toLowerCase().contains(query) || item.slug.toLowerCase().contains(query))).toList()[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: AdminColors.mintSoft, child: Text(formatPersianInteger(item.sortOrder))),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${item.slug} · ${(item.isActive ? 'فعال' : 'غیرفعال')}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                      trailing: PopupMenuButton<String>(onSelected: (action) { if (action == 'edit') editCategory(item); if (action == 'toggle') toggleCategory(item); if (action == 'delete') deleteCategory(item); }, itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('ویرایش')), PopupMenuItem(value: 'toggle', child: Text(item.isActive ? 'غیرفعال کردن' : 'فعال کردن')), const PopupMenuItem(value: 'delete', child: Text('حذف امن'))]),
                    );
                  },
                ),
        ),
      ]),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
      FilledButton.icon(
        onPressed: saving ? null : addCategory,
        icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded),
        label: const Text('دسته جدید'),
      ),
    ],
  );
}

class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, this.initial});
  final Category? initial;

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final slug = TextEditingController();
  final description = TextEditingController();
  final seoTitle = TextEditingController();
  final seoDescription = TextEditingController();
  final sortOrder = TextEditingController(text: '10');
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    if (item != null) { name.text = item.name; slug.text = item.slug; description.text = item.description; seoTitle.text = item.seoTitle; seoDescription.text = item.seoDescription; sortOrder.text = toPersianDigits(item.sortOrder); isActive = item.isActive; }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'افزودن دسته‌بندی' : 'ویرایش دسته‌بندی'),
    content: SizedBox(
      width: 500,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text('شناسه آدرس را کوتاه، خوانا و با حروف انگلیسی وارد کنید.', style: TextStyle(fontSize: 11, color: AdminColors.muted)),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'نام دسته *'),
              validator: (value) => value == null || value.trim().length < 2 ? 'نام دسته را وارد کنید.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: slug,
              decoration: const InputDecoration(labelText: 'شناسه آدرس (slug) *', hintText: 'مثلاً nuts-premium'),
              validator: (value) => value == null || value.trim().isEmpty ? 'شناسه آدرس را وارد کنید.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیح دسته', hintText: 'برای صفحه دسته و سئو استفاده می‌شود.')),
            const SizedBox(height: 10),
            TextFormField(controller: seoTitle, decoration: const InputDecoration(labelText: 'عنوان SEO', helperText: 'اگر خالی باشد از نام دسته استفاده می‌شود.')),
            const SizedBox(height: 10),
            TextFormField(controller: seoDescription, maxLines: 2, decoration: const InputDecoration(labelText: 'توضیح SEO')),
            const SizedBox(height: 10),
            TextFormField(controller: sortOrder, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ترتیب نمایش')),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('دسته فعال باشد'),
              value: isActive,
              onChanged: (value) => setState(() => isActive = value),
            ),
          ]),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(context, CreateCategoryCommand(
            name: name.text.trim(),
            slug: slug.text.trim().toLowerCase(),
            description: description.text.trim(),
            seoTitle: seoTitle.text.trim(),
            seoDescription: seoDescription.text.trim(),
            sortOrder: parsePersianInteger(sortOrder.text) ?? 0,
            isActive: isActive,
          ));
        },
        child: Text(widget.initial == null ? 'ثبت دسته' : 'ذخیره تغییرات'),
      ),
    ],
  );

  @override
  void dispose() {
    name.dispose();
    slug.dispose();
    description.dispose();
    seoTitle.dispose();
    seoDescription.dispose();
    sortOrder.dispose();
    super.dispose();
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, this.api, this.onNavigate});
  final OrderApiClient? api;
  final ValueChanged<int>? onNavigate;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final OrderApiClient api = widget.api ?? OrderApiClient();
  AdminNotifications? data;
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await api.fetchNotifications();
      if (mounted) setState(() => data = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مرکز اعلان‌ها', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: AdminColors.inkDeep)),
          const SizedBox(height: 6),
          const Text('هشدارهای سفارش، موجودی و کارهای مهم را در یک صف واضح دنبال کنید.', style: TextStyle(color: AdminColors.muted)),
        ])),
        IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
      ]),
      const SizedBox(height: 20),
      if (loading && data != null) const LinearProgressIndicator(),
      if (error != null && data != null && requestStatusCode(error!) != 401 && requestStatusCode(error!) != 403)
        AdminStaleBanner(detail: 'اعلان‌های قبلی نمایش داده می‌شوند. ${requestErrorMessage(error!)}', onRetry: load),
      Expanded(child: _body()),
    ]),
  );

  Widget _body() {
    if (loading && data == null) return const Center(child: CircularProgressIndicator());
    if (error != null && (data == null || requestStatusCode(error!) == 401 || requestStatusCode(error!) == 403)) {
      return AdminErrorState(error: error!, onRetry: load);
    }
    final items = data?.items ?? const <AdminNotification>[];
    if (items.isEmpty) return const Center(child: AdminEmptyState(icon: Icons.notifications_none_rounded, title: 'فعلاً اعلان مهمی ندارید', detail: 'اعلان سفارش، موجودی یا پیگیری بعدی اینجا نمایش داده می‌شود.'));
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) => Card(child: AdminNotificationTile(item: items[index], onNavigate: widget.onNavigate)),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(this.title, this.icon, {super.key});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: const Color(0xFF90A08F)),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const Text('در Vertical Slice بعدی عملیاتی می‌شود.'),
        ]),
      );
}
