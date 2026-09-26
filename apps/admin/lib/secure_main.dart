import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_session.dart';
import 'catalog_api.dart';
import 'order_api.dart';
import 'product_management_page.dart';

void main() => runApp(const MazedunehSecureAdminApp());

class MazedunehSecureAdminApp extends StatelessWidget {
  const MazedunehSecureAdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'مدیریت مزه‌دونه',
        locale: const Locale('fa'),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F6B45)),
          scaffoldBackgroundColor: const Color(0xFFF6F8F4),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              side: BorderSide(color: Color(0xFFE0E8DE)),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          ),
        ),
        home: const Directionality(textDirection: TextDirection.rtl, child: OwnerAuthGate()),
      );
}

class OwnerAuthGate extends StatefulWidget {
  const OwnerAuthGate({super.key, this.authApi});
  final AuthApiClient? authApi;

  @override
  State<OwnerAuthGate> createState() => _OwnerAuthGateState();
}

class _OwnerAuthGateState extends State<OwnerAuthGate> {
  late final StreamSubscription<bool> subscription;

  @override
  void initState() {
    super.initState();
    subscription = OwnerSession.instance.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OwnerSession.instance.isAuthenticated
      ? const AdminOperationsShell()
      : OwnerLoginPage(api: widget.authApi);
}

class OwnerLoginPage extends StatefulWidget {
  const OwnerLoginPage({super.key, this.api});
  final AuthApiClient? api;

  @override
  State<OwnerLoginPage> createState() => _OwnerLoginPageState();
}

class _OwnerLoginPageState extends State<OwnerLoginPage> {
  late final AuthApiClient api = widget.api ?? AuthApiClient();
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController(text: 'Hamidrezapakpour95@gmail.com');
  final password = TextEditingController();
  bool submitting = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await api.login(email: email.text.trim(), password: password.text);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(alignment: Alignment.center, child: BrandMark()),
                        const SizedBox(height: 20),
                        Text(
                          'ورود مدیر مزه‌دونه',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'مدیریت محصولات، سفارش‌ها و موجودی',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'ایمیل مدیر',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (value) => value == null || !value.contains('@') ? 'ایمیل معتبر وارد کنید.' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: password,
                          obscureText: obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => submitting ? null : submit(),
                          decoration: InputDecoration(
                            labelText: 'رمز عبور',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => obscure = !obscure),
                              icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'رمز عبور را وارد کنید.' : null,
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 14),
                          Semantics(
                            liveRegion: true,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECE8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(error!, style: const TextStyle(color: Color(0xFF9A3E36))),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: submitting ? null : submit,
                          icon: submitting
                              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.login_rounded),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 13),
                            child: Text('ورود امن'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'رمز و توکن داخل کد یا آدرس صفحه ذخیره نمی‌شوند.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
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
  List<AdminOrder> orders = const [];
  List<StockMovement> movements = const [];
  AdminDashboard? dashboard;
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
        orderApi.fetchOrders(state: orderFilter),
        orderApi.fetchDashboard(),
        orderApi.fetchInventoryMovements(limit: 100),
      ]);
      if (!mounted) return;
      setState(() {
        products = result[0] as List<Product>;
        orders = result[1] as List<AdminOrder>;
        dashboard = result[2] as AdminDashboard;
        movements = result[3] as List<StockMovement>;
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
          IconButton(onPressed: loading ? null : loadAll, tooltip: 'تازه‌سازی', icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: OwnerSession.instance.clear, tooltip: 'خروج امن', icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              destinations: destinations,
              onDestinationSelected: (index) => setState(() => selectedIndex = index),
            ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => setState(() => selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.8,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.space_dashboard_rounded), label: Text('داشبورد')),
                NavigationRailDestination(icon: Icon(Icons.receipt_long_rounded), label: Text('سفارش‌ها')),
                NavigationRailDestination(icon: Icon(Icons.inventory_2_rounded), label: Text('محصولات')),
                NavigationRailDestination(icon: Icon(Icons.warehouse_rounded), label: Text('انبار')),
              ],
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
      2 => ProductManagementPage(products: products, api: catalogApi, onReload: loadAll),
      _ => inventoryView(),
    };
  }

  Widget inventoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(title: 'گردش موجودی', subtitle: 'ردپای رزرو، آزادسازی و موجودی اولیه از دفتر ثبت سرور'),
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
