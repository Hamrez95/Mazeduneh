import 'package:flutter/material.dart';

import 'admin_permissions.dart';
import 'admin_navigation.dart';
import 'admin_state.dart';
import 'admin_theme.dart';
import 'auth_session.dart';
import 'formatters.dart';
import 'notification_tile.dart';
import 'order_api.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.api, this.onNavigate});
  final OrderApiClient? api;
  final ValueChanged<AdminNavigationIntent>? onNavigate;
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
    final session = OwnerSession.instance;
    bool can(String permission) => !session.isAuthenticated || session.can(permission);
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
            if (data.financialsVisible) MetricCard(_periodLabel(dashboardDays), '${formatPersianNumber(data.periodRevenue)} ریال', Icons.payments_rounded, tint: AdminColors.mintSoft, onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.reports))),
            if (can(AdminPermissions.ordersRead)) ...[
              MetricCard('تعداد سفارش بازه', formatPersianInteger(data.periodOrderCount), Icons.shopping_bag_rounded, tint: const Color(0xFFE6EEF8), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders))),
              if (data.financialsVisible) MetricCard('میانگین ارزش سفارش', '${formatPersianNumber(data.averageOrderValue)} ریال', Icons.insights_rounded, tint: const Color(0xFFFFF0D9), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.reports))),
              MetricCard('در انتظار پرداخت', formatPersianInteger(data.awaitingPayment), Icons.schedule_rounded, tint: const Color(0xFFFFF0D9), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.awaitingPayment))),
              MetricCard('در حال پردازش', formatPersianInteger(data.processing), Icons.inventory_2_rounded, tint: const Color(0xFFE6EEF8), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders))),
              MetricCard('ارسال‌شده', formatPersianInteger(data.shipped), Icons.local_shipping_rounded, tint: const Color(0xFFFCE6E0), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.shipped))),
              MetricCard('سفارش مشکل‌دار', formatPersianInteger(data.problemOrders), Icons.report_problem_outlined, tint: const Color(0xFFFCE6E0), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders))),
            ],
            if (can(AdminPermissions.customersRead)) MetricCard('مشتری جدید بازه', formatPersianInteger(data.newCustomers), Icons.person_add_alt_1_rounded, tint: const Color(0xFFE6F5E8), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.customers))),
            if (can(AdminPermissions.corporateRead)) MetricCard('درخواست سازمانی جدید', formatPersianInteger(data.corporateNewRequests), Icons.business_center_rounded, tint: const Color(0xFFE6EEF8), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.corporate))),
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
                child: !can(AdminPermissions.inventoryRead)
                    ? const AdminEmptyState(icon: Icons.lock_outline_rounded, title: 'دسترسی انبار لازم است', detail: 'برای مشاهده هشدارهای موجودی، دسترسی انبار را از مدیر سیستم بگیرید.')
                    : data.lowStock.isEmpty
                    ? const AdminEmptyState(icon: Icons.inventory_2_outlined, title: 'موجودی مناسب است', detail: 'کالایی پایین‌تر از نقطه سفارش نیست.')
                    : Column(children: [
                        for (final item in data.lowStock.take(4))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${item.variantLabel} · ${item.sku}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                            trailing: Text(formatPersianInteger(item.availablePackages), style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.coral)),
                            onTap: can(AdminPermissions.inventoryRead) ? () => widget.onNavigate?.call(AdminNavigationIntent(module: AdminModule.inventory, sku: item.sku)) : null,
                          ),
                      ]),
              ),
              _DashboardPanel(
                title: 'نزدیک به انقضا',
                icon: Icons.event_busy_rounded,
                child: !can(AdminPermissions.inventoryRead)
                    ? const AdminEmptyState(icon: Icons.lock_outline_rounded, title: 'دسترسی انبار لازم است', detail: 'برای مشاهده بچ‌های نزدیک انقضا، دسترسی انبار را از مدیر سیستم بگیرید.')
                    : data.expiringSoon.isEmpty
                    ? const AdminEmptyState(icon: Icons.check_circle_outline_rounded, title: 'بچ نزدیک انقضا نداریم', detail: 'تا ۳۰ روز آینده موردی برای پیگیری ثبت نشده است.')
                    : Column(children: [
                        for (final item in data.expiringSoon.take(5))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${item.variantLabel} · ${item.sku} · ${formatPersianInteger(item.remainingPackages)} بسته', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                            trailing: Text(formatPersianDateTime(item.expiresAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.coral)),
                            onTap: can(AdminPermissions.inventoryRead) ? () => widget.onNavigate?.call(AdminNavigationIntent(module: AdminModule.inventory, sku: item.sku, batchCode: item.batchCode)) : null,
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
  final ValueChanged<AdminNavigationIntent>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final session = OwnerSession.instance;
    bool can(String permission) => !session.isAuthenticated || session.can(permission);
    final actions = [
      if (can(AdminPermissions.productsRead))
        can(AdminPermissions.productsWrite)
            ? (title: 'ثبت محصول', detail: 'محصول جدید را به‌صورت پیش‌نویس بسازید.', icon: Icons.add_box_rounded, destination: AdminModule.products)
            : (title: 'مشاهده محصولات', detail: 'مشخصات، قیمت و وضعیت انتشار را بررسی کنید.', icon: Icons.inventory_2_outlined, destination: AdminModule.products),
      if (can(AdminPermissions.ordersRead))
        (title: 'پیگیری سفارش‌ها', detail: 'سفارش‌های جدید و منتظر پرداخت را ببینید.', icon: Icons.receipt_long_rounded, destination: AdminModule.orders),
      if (can(AdminPermissions.inventoryRead))
        can(AdminPermissions.inventoryWrite)
            ? (title: 'اصلاح موجودی', detail: 'دریافت کالا یا اصلاح یک SKU را ثبت کنید.', icon: Icons.inventory_2_rounded, destination: AdminModule.inventory)
            : (title: 'مشاهده موجودی', detail: 'موجودی کالا و بچ‌های نزدیک انقضا را بررسی کنید.', icon: Icons.warehouse_outlined, destination: AdminModule.inventory),
      if (can(AdminPermissions.corporateRead))
        (title: 'پیگیری فروش سازمانی', detail: 'درخواست‌های جدید را از دست ندهید.', icon: Icons.business_center_rounded, destination: AdminModule.corporate),
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
          SizedBox(width: width, child: _DashboardQuickAction(action: action, onPressed: onNavigate == null ? null : () => onNavigate!(AdminNavigationIntent(module: action.destination)))),
      ]);
    });
  }
}

class _DashboardQuickAction extends StatelessWidget {
  const _DashboardQuickAction({required this.action, required this.onPressed});
  final ({String title, String detail, IconData icon, AdminModule destination}) action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onPressed != null,
        label: '${action.title}: ${action.detail}',
        child: Card(
          child: InkWell(
            key: ValueKey('dashboard-action-${action.destination.index}'),
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
  const MetricCard(this.title, this.value, this.icon, {super.key, this.tint = AdminColors.mintSoft, this.onTap});
  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 250,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 150),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(backgroundColor: tint, foregroundColor: AdminColors.ink, child: Icon(icon)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: AdminColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AdminColors.inkDeep)),
          ])),
        ),
      ),
    ),
  );
}

