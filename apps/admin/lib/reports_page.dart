import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_theme.dart';
import 'formatters.dart';
import 'order_api.dart';

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
