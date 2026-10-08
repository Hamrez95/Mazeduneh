import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'admin_auth_gate.dart';
import 'admin_theme.dart';
import 'auth_api.dart';
import 'auth_session.dart';
import 'catalog_api.dart';
import 'order_api.dart';
import 'product_management_page.dart';
import 'customer_management_page.dart';
import 'commerce_settings_page.dart';
import 'corporate_requests_page.dart';
import 'main.dart' show AdminShell;
import 'notifications_page.dart' show NotificationsPage;
import 'reports_page.dart' show ReportsPage;

void main() => runApp(const MazedunehSecureAdminApp());

class MazedunehSecureAdminApp extends StatefulWidget {
  const MazedunehSecureAdminApp({super.key, this.authApi, this.initialUri, this.child});

  final AuthApiClient? authApi;
  final Uri? initialUri;
  final Widget? child;

  @override
  State<MazedunehSecureAdminApp> createState() => _MazedunehSecureAdminAppState();
}

class _MazedunehSecureAdminAppState extends State<MazedunehSecureAdminApp> {
  GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  int revision = OwnerSession.instance.revision;
  StreamSubscription<bool>? subscription;

  @override
  void initState() {
    super.initState();
    subscription = OwnerSession.instance.changes.listen((_) {
      if (!mounted) return;
      setState(() {
        if (revision != OwnerSession.instance.revision) {
          revision = OwnerSession.instance.revision;
          navigatorKey = GlobalKey<NavigatorState>();
        }
      });
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مدیریت مزه‌دونه',
        navigatorKey: navigatorKey,
        locale: const Locale('fa'),
        theme: buildAdminTheme(),
        home: widget.child ?? const AdminShell(),
        builder: (_, navigator) => Directionality(
          textDirection: TextDirection.rtl,
          child: AdminAuthGate(api: widget.authApi, initialUri: widget.initialUri, child: navigator!),
        ),
      );
}

class AdminOperationsShell extends StatefulWidget {
  const AdminOperationsShell({super.key, this.catalogApi, this.orderApi});
  final CatalogApiClient? catalogApi;
  final OrderApiClient? orderApi;

  @override
  State<AdminOperationsShell> createState() => _AdminOperationsShellState();
}

class _AdminOperationsShellState extends State<AdminOperationsShell> {
  late final CatalogApiClient catalogApi = widget.catalogApi ?? CatalogApiClient();
  late final OrderApiClient orderApi = widget.orderApi ?? OrderApiClient();

  List<Product> products = const [];
  List<Category> categories = const [];
  List<AdminOrder> orders = const [];
  List<StockMovement> movements = const [];
  AdminDashboard? dashboard;
  AdminAnalytics? analytics;
  AdminNotifications? notifications;
  bool loading = true;
  String? error;
  int selectedIndex = 0;
  String orderFilter = '';
  String? changingOrderId;

  static const destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.space_dashboard_rounded), label: 'داشبورد'),
    NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'سفارش‌ها'),
    NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'محصولات'),
    NavigationDestination(icon: Icon(Icons.warehouse_rounded), label: 'انبار'),
    NavigationDestination(icon: Icon(Icons.query_stats_rounded), label: 'گزارش‌ها'),
    NavigationDestination(icon: Icon(Icons.notifications_active_rounded), label: 'اعلان‌ها'),
    NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'مشتری‌ها'),
    NavigationDestination(icon: Icon(Icons.percent_rounded), label: 'قیمت و ارسال'),
    NavigationDestination(icon: Icon(Icons.business_center_rounded), label: 'فروش سازمانی'),
  ];

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await Future.wait<dynamic>([
        catalogApi.fetchProducts(includeDrafts: true),
        catalogApi.fetchCategories(),
        orderApi.fetchOrders(state: orderFilter),
        orderApi.fetchDashboard(),
        orderApi.fetchAnalytics(),
        orderApi.fetchNotifications(),
        orderApi.fetchInventoryMovements(limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        products = result[0] as List<Product>;
        categories = result[1] as List<Category>;
        orders = result[2] as List<AdminOrder>;
        dashboard = result[3] as AdminDashboard;
        analytics = result[4] as AdminAnalytics;
        notifications = result[5] as AdminNotifications;
        movements = result[6] as List<StockMovement>;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changeOrder(AdminOrder order, String target) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغییر وضعیت به «${stateLabel(target)}»؟'),
        content: Text('سفارش ${order.id.substring(0, 8)} برای ${order.customerName} به مرحله بعد منتقل می‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأیید')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => changingOrderId = order.id);
    try {
      await orderApi.transition(order.id, target);
      await loadAll();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.toString()), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => changingOrderId = null);
    }
  }

  Future<void> cancelOrder(AdminOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('لغو سفارش پرداخت‌نشده؟'),
        content: const Text('موجودی رزروشده به انبار بازمی‌گردد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('لغو و آزادسازی موجودی'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => changingOrderId = order.id);
    try {
      await orderApi.transition(order.id, 'Cancelled', reason: 'owner-cancelled-before-payment');
      await loadAll();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.toString()), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => changingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [BrandMark(size: 38), SizedBox(width: 10), Text('مدیریت مزه‌دونه')],
        ),
        actions: [
          if (notifications != null)
            Badge(
              isLabelVisible: notifications!.count > 0,
              label: Text('${notifications!.count}'),
              child: IconButton(
                onPressed: loading ? null : () => setState(() => selectedIndex = 5),
                tooltip: 'رفتن به اعلان‌ها',
                icon: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          IconButton(onPressed: loading ? null : loadAll, tooltip: 'تازه‌سازی', icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: OwnerSession.instance.clear, tooltip: 'خروج امن', icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(children: [BrandMark(size: 38), SizedBox(width: 10), Text('مدیریت مزه‌دونه', style: TextStyle(fontWeight: FontWeight.w800))]),
                    ),
                    for (var i = 0; i < destinations.length; i++)
                      ListTile(
                        selected: selectedIndex == i,
                        leading: destinations[i].icon,
                        title: Text(destinations[i].label),
                        onTap: () {
                          setState(() => selectedIndex = i);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 220,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Row(children: [BrandMark(size: 38), SizedBox(width: 10), Expanded(child: Text('مدیریت مزه‌دونه', style: TextStyle(fontWeight: FontWeight.w800)))]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: destinations.length,
                      itemBuilder: (context, index) => ListTile(
                        selected: selectedIndex == index,
                        leading: destinations[index].icon,
                        title: Text(destinations[index].label),
                        onTap: () => setState(() => selectedIndex = index),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(wide ? 24 : 14),
                child: content(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget content() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52),
            const SizedBox(height: 10),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: loadAll, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
          ],
        ),
      );
    }
    return switch (selectedIndex) {
      0 => dashboardView(),
      1 => ordersView(),
      2 => ProductManagementPage(products: products, categories: categories, api: catalogApi, onReload: loadAll),
      3 => inventoryView(),
      4 => ReportsPage(api: orderApi),
      5 => NotificationsPage(api: orderApi),
      6 => const CustomerManagementPage(),
      7 => const CommerceSettingsPage(),
      8 => const CorporateRequestsPage(),
      _ => dashboardView(),
    };
  }

  Future<void> _openStockAdjustment() async {
    final changed = await showDialog<bool>(context: context, builder: (_) => _StockAdjustmentDialog(api: orderApi));
    if (changed == true) await loadAll();
  }

  Widget inventoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: PageHeader(title: 'گردش موجودی', subtitle: 'ردپای رزرو، آزادسازی و موجودی اولیه از دفتر ثبت سرور')),
          FilledButton.icon(onPressed: _openStockAdjustment, icon: const Icon(Icons.tune_rounded), label: const Text('اصلاح موجودی')),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: movements.isEmpty
              ? const Center(child: Text('هنوز گردش موجودی ثبت نشده است.'))
              : ListView.separated(
                  itemCount: movements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final movement = movements[index];
                    final positive = movement.quantityDelta > 0;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: positive ? const Color(0xFFE7F1E2) : const Color(0xFFFFE8C8),
                          child: Icon(positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                        ),
                        title: Text('${movement.sku} · ${movement.movementType}'),
                        subtitle: Text('${movement.reason} · ${movement.actor} · ${formatDateTime(movement.createdAt)}'),
                        trailing: Text(
                          '${positive ? '+' : ''}${movement.quantityDelta}  |  ${movement.balanceAfter}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget dashboardView() {
    final data = dashboard!;
    final finance = analytics!;
    final notices = notifications!;
    final cards = [
      MetricCard(
        title: 'فروش امروز',
        value: formatToman(data.todayRevenue),
        suffix: 'تومان',
        icon: Icons.payments_rounded,
        tone: const Color(0xFFE7F1E2),
      ),
      MetricCard(
        title: 'در انتظار پرداخت',
        value: '${data.awaitingPayment}',
        suffix: 'سفارش',
        icon: Icons.hourglass_top_rounded,
        tone: const Color(0xFFFFE8C8),
      ),
      MetricCard(
        title: 'در حال پردازش',
        value: '${data.processing}',
        suffix: 'سفارش',
        icon: Icons.inventory_rounded,
        tone: const Color(0xFFF8DDD0),
      ),
      MetricCard(
        title: 'ارسال‌شده',
        value: '${data.shipped}',
        suffix: 'سفارش',
        icon: Icons.local_shipping_rounded,
        tone: const Color(0xFFE8E1F3),
      ),
      MetricCard(
        title: 'سود ناخالص ۳۰ روز',
        value: formatToman(finance.grossProfit),
        suffix: 'تومان',
        icon: Icons.trending_up_rounded,
        tone: const Color(0xFFDCEFEA),
      ),
      MetricCard(
        title: 'حاشیه سود',
        value: finance.grossMarginPercent.toStringAsFixed(1),
        suffix: 'درصد',
        icon: Icons.percent_rounded,
        tone: const Color(0xFFE9E2F3),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1150 ? 4 : constraints.maxWidth >= 620 ? 2 : 1;
        return ListView(
          children: [
            PageHeader(
              title: 'داشبورد عملیاتی',
              subtitle: '${OwnerSession.instance.email ?? 'مالک'} · داده زنده از PostgreSQL',
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 136,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) => cards[index],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('هشدارهای موجودی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        ),
                        Text('${data.lowStock.length} مورد', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (data.lowStock.isEmpty)
                      const Text('موجودی بحرانی وجود ندارد.')
                    else
                      ...data.lowStock.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFE8C8),
                            child: Text('${item.availablePackages}'),
                          ),
                          title: Text(item.productTitle),
                          subtitle: Text('${item.variantLabel} · ${item.sku}'),
                          trailing: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB06B26)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('اعلان‌های مدیریتی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  const SizedBox(height: 10),
                  if (notices.items.isEmpty)
                    const Text('اعلان جدیدی وجود ندارد.')
                  else
                    ...notices.items.take(5).map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item.type == 'low-stock' ? Icons.warning_amber_rounded : Icons.notifications_active_rounded),
                      title: Text(item.title),
                      subtitle: Text(item.detail),
                    )),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget ordersView() {
    const filters = <String, String>{
      '': 'همه',
      'AwaitingPayment': 'در انتظار پرداخت',
      'Paid': 'پرداخت‌شده',
      'Preparing': 'آماده‌سازی',
      'Shipped': 'ارسال‌شده',
      'Delivered': 'تحویل‌شده',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(title: 'سفارش‌ها', subtitle: 'مدیریت چرخه پرداخت، آماده‌سازی، ارسال و تحویل'),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: orderFilter,
          decoration: const InputDecoration(labelText: 'فیلتر وضعیت', prefixIcon: Icon(Icons.filter_alt_rounded)),
          items: filters.entries.map((item) => DropdownMenuItem(value: item.key, child: Text(item.value))).toList(),
          onChanged: (value) {
            setState(() => orderFilter = value ?? '');
            loadAll();
          },
        ),
        const SizedBox(height: 14),
        Expanded(
          child: orders.isEmpty
              ? const Center(child: Text('سفارشی در این وضعیت وجود ندارد.'))
              : ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      order: order,
                      busy: changingOrderId == order.id,
                      onNext: order.nextState == null ? null : () => changeOrder(order, order.nextState!),
                      onCancel: order.state == 'AwaitingPayment' ? () => cancelOrder(order) : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.tone,
  });
  final String title;
  final String value;
  final String suffix;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.grey)),
                    const Spacer(),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 21)),
                    Text(suffix, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: const Color(0xFF3F6B45)),
              ),
            ],
          ),
        ),
      );
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, required this.busy, this.onNext, this.onCancel});
  final AdminOrder order;
  final bool busy;
  final VoidCallback? onNext;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 245,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w900))),
                        StateChip(state: order.state),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text('${order.city}، ${order.province} · ${order.mobile}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text('کد: ${order.id.substring(0, 8)} · ${order.lineCount} ردیف', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مبلغ سفارش', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text('${formatToman(order.payable)} تومان', style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (order.paymentReference != null)
                      Text(order.paymentReference!, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ),
              if (busy)
                const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2))
              else ...[
                if (onCancel != null)
                  OutlinedButton.icon(onPressed: onCancel, icon: const Icon(Icons.cancel_outlined), label: const Text('لغو')),
                if (onNext != null)
                  FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(nextActionLabel(order.nextState!)),
                  ),
              ],
            ],
          ),
        ),
      );
}

class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.state});
  final String state;

  @override
  Widget build(BuildContext context) => Chip(label: Text(stateLabel(state)), backgroundColor: stateColor(state));
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 54});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .32),
        child: Image.asset('assets/mazedooneh-mark.png', width: size, height: size, fit: BoxFit.cover),
      );
}

String formatToman(num irr) => '${(irr / 10).round()}'.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '٬',
    );

String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String stateLabel(String state) => switch (state) {
      'AwaitingPayment' => 'در انتظار پرداخت',
      'Paid' => 'پرداخت‌شده',
      'Preparing' => 'آماده‌سازی',
      'Shipped' => 'ارسال‌شده',
      'Delivered' => 'تحویل‌شده',
      'Cancelled' => 'لغوشده',
      'Expired' => 'منقضی',
      _ => state,
    };

String nextActionLabel(String state) => switch (state) {
      'Preparing' => 'شروع آماده‌سازی',
      'Shipped' => 'ثبت ارسال',
      'Delivered' => 'ثبت تحویل',
      _ => 'مرحله بعد',
    };

Color stateColor(String state) => switch (state) {
      'Paid' => const Color(0xFFE7F1E2),
      'Preparing' => const Color(0xFFFFE8C8),
      'Shipped' => const Color(0xFFE8E1F3),
      'Delivered' => const Color(0xFFDDF1ED),
      'Cancelled' => const Color(0xFFFFE7E2),
      'Expired' => const Color(0xFFFFE7E2),
      _ => const Color(0xFFF2E7D6),
    };


class _StockAdjustmentDialog extends StatefulWidget {
  const _StockAdjustmentDialog({required this.api});
  final OrderApiClient api;
  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final formKey = GlobalKey<FormState>();
  final sku = TextEditingController();
  final delta = TextEditingController();
  final reason = TextEditingController(text: 'اصلاح دستی موجودی');
  bool submitting = false;
  String? error;
  String? operationKey, previousPayload;
  @override
  void dispose() { sku.dispose(); delta.dispose(); reason.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    final payload = jsonEncode([sku.text.trim(), int.parse(delta.text.trim()), reason.text.trim()]);
    if (operationKey == null || payload != previousPayload) {
      operationKey = List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      previousPayload = payload;
    }
    setState(() { submitting = true; error = null; });
    try {
      await widget.api.adjustStock(sku.text.trim(), int.parse(delta.text.trim()), reason.text.trim(), operationKey: operationKey!);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) { if (mounted) setState(() => error = exception.toString()); }
    finally { if (mounted) setState(() => submitting = false); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('اصلاح دستی موجودی'),
    content: SizedBox(width: 420, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: sku, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'SKU'), validator: (value) => value == null || value.trim().isEmpty ? 'SKU الزامی است.' : null),
      const SizedBox(height: 10),
      TextFormField(controller: delta, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تغییر تعداد بسته', hintText: 'مثبت برای افزایش، منفی برای کاهش'), validator: (value) => int.tryParse(value ?? '') == null || int.parse(value!) == 0 ? 'یک عدد غیرصفر وارد کنید.' : null),
      const SizedBox(height: 10),
      TextFormField(controller: reason, decoration: const InputDecoration(labelText: 'دلیل تغییر'), validator: (value) => value == null || value.trim().isEmpty ? 'دلیل الزامی است.' : null),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
    ]))),
    actions: [TextButton(onPressed: submitting ? null : () => Navigator.pop(context, false), child: const Text('انصراف')), FilledButton(onPressed: submitting ? null : submit, child: const Text('ثبت تغییر'))],
  );
}
