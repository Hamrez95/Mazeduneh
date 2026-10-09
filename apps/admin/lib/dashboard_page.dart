Warning: truncated output (original token count: 9056)
Total output lines: 705

import 'package:flutter/material.dart';

import 'admin_navigation.dart';
import 'admin_permissions.dart';
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
  AdminDashboardHealth? systemHealth;
  AdminNotifications? notifications;
  DashboardPreferences preferences = DashboardPreferences.defaults;
  Object? error;
  bool loading = true;
  bool healthLoading = true;
  DateTime? lastLoadedAt;
  int dashboardDays = 1;
  DateTimeRange? customRange;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() {
      loading = true;
      healthLoading = true;
      error = null;
      systemHealth = null;
    });
    final healthFuture = api.fetchDashboardHealth()
        .then<Object?>((value) => value)
        .catchError((Object exception) => exception);
    try {
      final today = DateUtils.dateOnly(DateTime.now());
      final rangeStart = customRange?.start ?? DateTime(today.year, today.month, today.day - dashboardDays + 1);
      final rangeEnd = customRange?.end ?? today;
      final result = await Future.wait([
        api.fetchDashboard(
          days: dashboardDays,
          fromUtc: rangeStart.toUtc(),
          toUtcExclusive: DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day + 1).toUtc(),
        ),
        api.fetchNotifications(),
        api.fetchDashboardPreferences(),
      ]);
      if (mounted) setState(() {
        dashboard = result[0] as AdminDashboard;
        notifications = result[1] as AdminNotifications;
        preferences = result[2] as DashboardPreferences;
        lastLoadedAt = DateTime.now();
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
    final healthResult = await healthFuture;
    if (mounted) setState(() {
      healthLoading = false;
      if (healthResult is AdminDashboardHealth) {
        systemHealth = healthResult;
      }
    });
  }

  Future<void> customizeDashboard() async {
    final updated = await showDialog<DashboardPreferences>(
      context: context,
      builder: (_) => DashboardPreferencesDialog(initial: preferences, onSave: api.saveDashboardPreferences),
    );
    if (updated != null && mounted) setState(() => preferences = updated);
  }

  Future<void> chooseCustomRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _DashboardRangeDialog(initialRange: customRange, today: today),
    );
    if (selected == null || !mounted) return;
    setState(() => customRange = DateTimeRange(
          start: DateUtils.dateOnly(selected.start),
          end: DateUtils.dateOnly(selected.end),
        ));
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (loading && dashboard == null) return const Center(child: CircularProgressIndicator());
    if (error != null && dashboard == null) return AdminErrorState(error: error!, onRetry: load);
    final data = dashboard!;
    final session = OwnerSession.instance;
    bool can(String permission) => !session.isAuthenticated || session.can(permission);
    final sections = <String, Widget>{
      'metrics': _metricsSection(data, can),
      'quickActions': _quickActionsSection(),
      'alerts': _alertsPanel(),
      'lowStock': _lowStockPanel(data, can),
      'expiring': _expiringPanel(data, can),
    };
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
            final customize = IconButton(onPressed: customizeDashboard, icon: const Icon(Icons.tune_rounded), tooltip: 'تنظیم بخش‌های داشبورد');
            return constraints.maxWidth < 500
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Align(alignment: AlignmentDirectional.centerEnd, child: Wrap(children: [customize, refresh])), heading])
                : Row(children: [Expanded(child: heading), customize, refresh]);
          }),
          if (preferences.widgets.every((item) => !item.visible))
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: AdminEmptyState(icon: Icons.dashboard_customize_outlined, title: 'داشبورد خلوت است', detail: 'از تنظیمات بالای صفحه، بخش‌های موردنیاز را دوباره فعال کنید.'),
            ),
          LayoutBuilder(builder: (context, constraints) {
            final visible = preferences.widgets.where((item) => item.visible).toList();
            final compact = constraints.maxWidth < 720;
            return Wrap(spacing: 14, runSpacing: 14, children: [
              for (final item in visible)
                SizedBox(
                  width: item.id == 'metrics' || item.id == 'quickActions' || compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 14) / 2,
                  child: sections[item.id],
                ),
            ]);
          }),
        ],
      ),
    );
  }

  String _periodLabel(int days, DateTimeRange? range) {
    if (range != null) return 'فروش ${formatPersianDate(range.start)} تا ${formatPersianDate(range.end)}';
    return switch (days) {
        1 => 'فروش امروز',
        7 => 'فروش ۷ روز اخیر',
        30 => 'فروش ۳۰ روز اخیر',
        _ => 'فروش بازهٔ انتخابی',
      };
  }

  Widget _metricsSection(AdminDashboard data, bool Function(String) can) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _DashboardPeriodSelector(
        selectedDays: dashboardDays,
        customRange: customRange,
        onChanged: (days) {
          setState(() {
            dashboardDays = days;
            customRange = null;
          });
          load();
        },
        onChooseCustomRange: chooseCustomRange,
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 14, runSpacing: 14, children: [
        if (data.financialsVisible) MetricCard(_periodLabel(dashboardDays, customRange), '${formatPersianNumber(data.periodRevenue)} ریال', Icons.payments_rounded, tint: AdminColors.mintSoft, onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.reports))),
        if (can(AdminPermissions.ordersRead)) ...[
          MetricCard('تعداد سفارش بازه', formatPersianInteger(data.periodOrderCount), Icons.shopping_bag_rounded, tint: const Color(0xFFE6EEF8), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders))),
          if (data.financialsVisible) MetricCard('میانگین ارزش سفارش', '${formatPersianNumber(data.averageOrderValue)} ریال', Icons.insights_rounded, tint: const Color(0xFFFFF0D9), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.reports))),
          MetricCard('در انتظار پرداخت', formatPersianInteger(data.awaitingPayment), Icons.schedule_rounded, tint: const Color(0xFFFFF0D9), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.awaitingPayment))),
          MetricCard('در حال پردازش', formatPersianInteger(data.processing), Icons.inventory_2_rounded, tint: const Color(0xFFE6EEF8), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.processing))),
          MetricCard('ارسال‌شده', formatPersianInteger(data.shipped), Icons.local_shipping_rounded, tint: const Color(0xFFFCE6E0), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.shipped))),
          MetricCard('سفارش مشکل‌دار', formatPersianInteger(data.problemOrders), Icons.report_problem_outlined, tint: const Color(0xFFFCE6E0), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.orders, orderFilter: AdminOrderFilter.problem))),
        ],
        if (can(AdminPermissions.customersRead)) MetricCard('مشتری جدید بازه', formatPersianInteger(data.newCustomers), Icons.person_add_alt_1_rounded, tint: const Color(0xFFE6F5E8), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.customers))),
        if (can(AdminPermissions.corporateRead)) MetricCard('درخواست سازمانی جدید', formatPersianInteger(data.corporateNewRequests), Icons.business_center_rounded, tint: const Color(0xFFE6EEF8), onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(const AdminNavigationIntent(module: AdminModule.corporate))),
      ]),
    ],
  );

  Widget _quickActionsSection() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const _DashboardSectionTitle(
      eyebrow: 'مسیرهای سریع',
      title: 'امروز چه کاری انجام دهید؟',
      detail: 'از همین‌جا به کاری بروید که بیشترین اثر را روی عملیات امروز دارد.',
    ),
    const SizedBox(height: 12),
    _DashboardQuickActions(onNavigate: widget.onNavigate),
  ]);

  Widget _alertsPanel() {
    final items = notifications?.items ?? const <AdminNotification>[];
    return _DashboardPanel(
      title: 'هشدارهای عملیاتی',
      icon: Icons.notifications_active_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _systemHealthPanel(),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const AdminEmptyState(icon: Icons.check_circle_outline_rounded, title: 'همه‌چیز آرام است', detail: 'هشدار فوری برای پیگیری وجود ندارد.')
          else
            for (final item in items.take(4)) AdminNotificationTile(item: item, onNavigate: widget.onNavigate),
        ],
      ),
    );
  }

  Widget _systemHealthPanel() {
    if (healthLoading) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('در حال بررسی وضعیت سامانه'),
      );
    }
    if (systemHealth == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.cloud_off_outlined, color: AdminColors.coral),
        title: const Text('وضعیت فنی در دسترس نیست'),
        subtitle: const Text('ارتباط با سرویس وضعیت برقرار نشد. برای بررسی دوباره تلاش کنید.'),
        trailing: IconButton(
          tooltip: 'بررسی دوبارهٔ وضعیت سامانه',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }

    final health = systemHealth!;
    final healthyColor = health.ready ? AdminColors.ink : AdminColors.coral;
    String label(String value) => switch (value) {
          'healthy' || 'ready' || 'tracked' => 'سالم',
          'configured' => 'پیکربندی شده',
          'not-configured' => 'پیکربندی نشده',
          'sandbox-enabled' => 'حالت آزمایشی فعال',
          'disabled' => 'غیرفعال',
          'local' => 'محلی',
          's3-configured' => 'S3 پیکربندی شده',
          'empty' => 'نیازمند راه‌اندازی',
          'unhealthy' || 'unavailable' || 'degraded' || 'not-ready' => 'نیاز به بررسی',
          _ => 'نامشخص',
        };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: health.ready ? AdminColors.mintSoft : const Color(0xFFFFF0D9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(health.ready ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded, color: healthyColor),
            const SizedBox(width: 8),
            Expanded(child: Text(health.ready ? 'API و زیرساخت پایه آماده است' : 'API یا پایگاه داده نیاز به بررسی دارد', style: const TextStyle(fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          for (final item in [
            ('API', health.api),
            ('پایگاه داده', health.database),
            ('مهاجرت‌های پایگاه داده', health.migrations),
            ('ورود مدیر', health.adminAuthentication),
            ('پرداخت', health.payment),
            ('ذخیره‌سازی رسانه', health.mediaStorage),
          ])
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('${item.$1}: ${label(item.$2)}', style: const TextStyle(fontSize: 12, color: AdminColors.ink)),
            ),
          const SizedBox(height: 6),
          const Text(
            'وضعیت پرداخت و رسانه از روی پیکربندی است؛ اتصال بیرونی آن‌ها اینجا آزموده نمی‌شود.',
            style: TextStyle(fontSize: 11, color: AdminColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _lowStockPanel(AdminDashboard data, bool Function(String) can) => _DashboardPanel(
    title: 'موجودی کم',
    icon: Icons.warning_amber_rounded,
    child: !can(AdminPermissions.inventoryRead)
        ? const AdminEmptyState(icon: Icons.lock_outline_rounded, title: 'دسترسی انبار لازم است', detail: 'برای مشاهده هشدارهای موجودی، دسترسی انبار را از مدیر سیستم بگیرید.')
        : data.lowStock.isEmpty
            ? const AdminEmptyState(icon: Icons.inventory_2_outlined, title: 'موجودی مناسب است', detail: 'کالایی پایین‌تر از نقطه سفارش نیست.')
            : Column(children: [for (final item in data.lowStock.take(4)) ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.variantLabel} · ${item.sku}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                trailing: Text(formatPersianInteger(item.availablePackages), style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.coral)),
                onTap: can(AdminPermissions.inventoryRead) ? () => widget.onNavigate?.call(AdminNavigationIntent(module: AdminModule.inventory, sku: item.sku)) : null,
              )]),
  );

  Widget _expiringPanel(AdminDashboard data, bool Function(String) can) => _DashboardPanel(
    title: 'نزدیک به انقضا',
    icon: Icons.event_busy_rounded,
    child: !can(AdminPermissions.inventoryRead)
        ? const AdminEmptyState(icon: Icons.lock_outline_rounded, title: 'دسترسی انبار لازم است', detail: 'برای مشاهده بچ‌های نزدیک انقضا، دسترسی انبار را از مدیر سیستم بگیرید.')
        : data.expiringSoon.isEmpty
            ? const AdminEmptyState(icon: Icons.check_circle_outline_rounded, title: 'بچ نزدیک انقضا نداریم', detail: 'تا ۳۰ روز آینده موردی برای پیگیری ثبت نشده است.')
            : Column(children: [for (final item in data.expiringSoon.take(5)) LayoutBuilder(
                builder: (context, cons…56 tokens truncated… ${formatPersianInteger(item.remainingPackages)} بسته';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: compact
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(details, style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                            const SizedBox(height: 4),
                            Text('انقضا: $expiryDate', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.coral)),
                          ])
                        : Text(details, style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                    trailing: compact
                        ? null
                        : Text(expiryDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.coral)),
                    onTap: can(AdminPermissions.inventoryRead) ? () => widget.onNavigate?.call(AdminNavigationIntent(module: AdminModule.inventory, sku: item.sku, batchCode: item.batchCode)) : null,
                  );
                },
              )]),
  );

}

class _DashboardPeriodSelector extends StatelessWidget {
  const _DashboardPeriodSelector({required this.selectedDays, required this.customRange, required this.onChanged, required this.onChooseCustomRange});
  final int selectedDays;
  final DateTimeRange? customRange;
  final ValueChanged<int> onChanged;
  final VoidCallback onChooseCustomRange;

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
                selected: customRange == null && selectedDays == option.$1,
                onSelected: (_) => onChanged(option.$1),
              ),
            OutlinedButton.icon(
              key: const ValueKey('dashboard-custom-range'),
              onPressed: onChooseCustomRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(customRange == null
                  ? 'بازهٔ دلخواه'
                  : '${formatPersianDate(customRange!.start)} تا ${formatPersianDate(customRange!.end)}'),
            ),
            const Text('تاریخ‌ها بر اساس منطقهٔ زمانی این دستگاه هستند.', style: TextStyle(fontSize: 12, color: AdminColors.muted)),
          ],
        ),
      );
}

class _DashboardRangeDialog extends StatefulWidget {
  const _DashboardRangeDialog({required this.initialRange, required this.today});

  final DateTimeRange? initialRange;
  final DateTime today;

  @override
  State<_DashboardRangeDialog> createState() => _DashboardRangeDialogState();
}

class _DashboardRangeDialogState extends State<_DashboardRangeDialog> {
  late DateTime start = widget.initialRange?.start ?? widget.today;
  late DateTime end = widget.initialRange?.end ?? widget.today;

  Future<void> pickStart() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: DateTime(widget.today.year, widget.today.month, widget.today.day - 365),
      lastDate: end,
      locale: Localizations.localeOf(context),
    );
    if (selected == null) return;
    setState(() => start = DateUtils.dateOnly(selected));
  }

  Future<void> pickEnd() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: end,
      firstDate: start,
      lastDate: widget.today,
      locale: Localizations.localeOf(context),
    );
    if (selected == null) return;
    setState(() => end = DateUtils.dateOnly(selected));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('بازهٔ گزارش را انتخاب کنید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('روز شروع'),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: pickStart,
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(formatPersianDate(start)),
            ),
            const SizedBox(height: 12),
            const Text('روز پایان'),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: pickEnd,
              icon: const Icon(Icons.event_available_rounded),
              label: Text(formatPersianDate(end)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(
            onPressed: () => Navigator.pop(context, DateTimeRange(start: start, end: end)),
            child: const Text('اعمال بازه'),
          ),
        ],
      );
}

class DashboardPreferencesDialog extends StatefulWidget {
  const DashboardPreferencesDialog({super.key, required this.initial, required this.onSave});
  final DashboardPreferences initial;
  final Future<DashboardPreferences> Function(DashboardPreferences) onSave;
  @override
  State<DashboardPreferencesDialog> createState() => _DashboardPreferencesDialogState();
}

class _DashboardPreferencesDialogState extends State<DashboardPreferencesDialog> {
  late DashboardPreferences draft = widget.initial;
  bool saving = false;
  String? error;
  static const labels = {
    'metrics': 'شاخص‌های فروش و سفارش',
    'quickActions': 'مسیرهای سریع',
    'alerts': 'هشدارهای عملیاتی',
    'lowStock': 'موجودی کم',
    'expiring': 'کالاهای نزدیک به انقضا',
  };

  Future<void> save() async {
    setState(() { saving = true; error = null; });
    try {
      final saved = await widget.onSave(draft);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (exception) {
      if (mounted) setState(() => error = requestErrorMessage(exception));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('تنظیم داشبورد این نقش', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('بخش‌ها را روشن یا خاموش کنید و ترتیب نمایش را تغییر دهید.', style: TextStyle(color: AdminColors.muted)),
          const SizedBox(height: 12),
          Flexible(child: ListView.builder(
            shrinkWrap: true,
            itemCount: draft.widgets.length,
            itemBuilder: (context, index) {
              final item = draft.widgets[index];
              return Semantics(
                container: true,
                label: labels[item.id],
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labels[item.id] ?? item.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                  leading: Checkbox(
                    value: item.visible,
                    onChanged: saving ? null : (value) => setState(() => draft = draft.setVisible(index, value ?? false)),
                  ),
                  trailing: Wrap(spacing: 0, children: [
                    IconButton(
                      tooltip: 'انتقال به بالا',
                      onPressed: saving || index == 0 ? null : () => setState(() => draft = draft.move(index, index - 1)),
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    ),
                    IconButton(
                      tooltip: 'انتقال به پایین',
                      onPressed: saving || index == draft.widgets.length - 1 ? null : () => setState(() => draft = draft.move(index, index + 1)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ]),
                ),
              );
            },
          )),
          if (error != null) ...[
            const SizedBox(height: 8),
            Semantics(liveRegion: true, child: Text(error!, style: const TextStyle(color: AdminColors.coral))),
          ],
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
            TextButton(onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text('انصراف')),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(saving ? 'در حال ذخیره' : 'ذخیره چیدمان'),
            ),
          ]),
        ]),
      ),
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
          SizedBox(width: width, child: _DashboardQuickAction(action: action, onPressed: onNavigate == null ? null : () => onNavigate!(AdminNavigationIntent(module: action.destination, orderFilter: action.destination == AdminModule.orders ? AdminOrderFilter.awaitingPayment : AdminOrderFilter.all)))),
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
            key: ValueKey('dashboard-action-${action.destination.name}'),
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




