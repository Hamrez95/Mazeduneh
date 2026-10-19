import 'analytics_panels.dart';
import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_theme.dart';
import 'admin_navigation.dart';
import 'admin_permissions.dart';
import 'auth_session.dart';
import 'formatters.dart';
import 'localized_calendar.dart';
import 'order_api.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    this.api,
    this.initialFromUtc,
    this.initialToUtcExclusive,
    this.onNavigate,
  });
  final OrderApiClient? api;
  final DateTime? initialFromUtc;
  final DateTime? initialToUtcExclusive;
  final ValueChanged<AdminNavigationIntent>? onNavigate;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final OrderApiClient api = widget.api ?? OrderApiClient();
  AdminAnalytics? analytics;
  List<AdminProductProfitability> profitability = const [];
  List<AdminPriceHistoryPoint> priceHistory = const [];
  List<AdminPriceHistorySku> priceHistorySkus = const [];
  String? selectedPriceSku;
  bool loadingPriceHistory = false;
  int days = 30;
  String productQuery = '';
  int productPage = 0;
  DateTimeRange? selectedRange;
  bool loading = true;
  Object? error;

  @override
  void initState() {
    super.initState();
    if (widget.initialFromUtc != null && widget.initialToUtcExclusive != null) {
      final localStart = widget.initialFromUtc!.toLocal();
      final localEndExclusive = widget.initialToUtcExclusive!.toLocal();
      selectedRange = DateTimeRange(
        start: DateTime(localStart.year, localStart.month, localStart.day),
        end: DateTime(
          localEndExclusive.year,
          localEndExclusive.month,
          localEndExclusive.day - 1,
        ),
      );
    }
    load();
  }

  DateTime? get _fromUtc => selectedRange == null
      ? null
      : DateTime(
          selectedRange!.start.year,
          selectedRange!.start.month,
          selectedRange!.start.day,
        ).toUtc();

  DateTime? get _toUtcExclusive => selectedRange == null
      ? null
      : DateTime(
          selectedRange!.end.year,
          selectedRange!.end.month,
          selectedRange!.end.day + 1,
        ).toUtc();

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        api.fetchAnalytics(
          days: days,
          fromUtc: _fromUtc,
          toUtcExclusive: _toUtcExclusive,
        ),
        api.fetchProductProfitability(
          days: days,
          fromUtc: _fromUtc,
          toUtcExclusive: _toUtcExclusive,
        ),
        api.fetchPriceHistorySkus(),
      ]);
      if (mounted)
        setState(() {
          analytics = result[0] as AdminAnalytics;
          profitability = result[1] as List<AdminProductProfitability>;
          priceHistorySkus = result[2] as List<AdminPriceHistorySku>;
          productPage = 0;
          selectedPriceSku = priceHistorySkus.any((item) => item.sku == selectedPriceSku)
              ? selectedPriceSku
              : (priceHistorySkus.isEmpty ? null : priceHistorySkus.first.sku);
        });
      if (mounted && selectedPriceSku != null) await loadPriceHistory(selectedPriceSku!);
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadPriceHistory(String sku) async {
    setState(() => loadingPriceHistory = true);
    try {
      final rows = await api.fetchPriceHistory(sku, days: days, fromUtc: _fromUtc, toUtcExclusive: _toUtcExclusive);
      if (mounted) setState(() => priceHistory = rows);
    } catch (_) {
      if (mounted) setState(() => priceHistory = const []);
    } finally {
      if (mounted) setState(() => loadingPriceHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'گزارش‌ها',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AdminColors.inkDeep,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'عملکرد فروش و سود را در یک نمای ساده و قابل تصمیم‌گیری ببینید.',
                    style: TextStyle(color: AdminColors.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'بارگذاری مجدد',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (selectedRange == null)
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
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Localizations.localeOf(context).languageCode == 'en' ? 'Dashboard range' : 'بازهٔ داشبورد'}: ${formatCalendarDate(selectedRange!.start, Localizations.localeOf(context))} ${Localizations.localeOf(context).languageCode == 'en' ? 'to' : 'تا'} ${formatCalendarDate(selectedRange!.end, Localizations.localeOf(context))}',
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    selectedRange = null;
                    days = 30;
                  });
                  load();
                },
                child: const Text('۳۰ روز اخیر'),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Expanded(child: _body()),
      ],
    ),
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    final data = analytics!;
    if (data.orderCount == 0)
      return ListView(key: const ValueKey('reports-content'), padding: const EdgeInsets.only(bottom: 24), children: [
        const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('برای این بازه هنوز دادهٔ فروش ثبت نشده است.', style: TextStyle(color: AdminColors.muted)))),
        const SizedBox(height: 14),
        _priceHistoryPanel(),
      ]);
    final merchandiseSalesAfterDiscount =
        data.merchandiseRevenue - data.discount;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        return ListView(
          key: const ValueKey('reports-content'),
          children: [
            GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 132 * MediaQuery.textScalerOf(context).scale(1),
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ReportMetric(
                  title: 'مبلغ پرداخت‌شده با ارسال و مالیات',
                  value: '${formatPersianNumber(data.revenue)} ریال',
                  icon: Icons.payments_rounded,
                  tint: AdminColors.mintSoft,
                ),
                _ReportMetric(
                  title: 'فروش کالا پس از تخفیف',
                  value:
                      '${formatPersianNumber(merchandiseSalesAfterDiscount)} ریال',
                  icon: Icons.trending_up_rounded,
                  tint: AdminColors.mintSoft,
                ),
                _ReportMetric(
                  title: 'هزینهٔ کالا، آماده‌سازی و اقلام داخلی',
                  value: '${formatPersianNumber(data.cost)} ریال',
                  icon: Icons.inventory_2_rounded,
                  tint: AdminColors.warningSoft,
                ),
                _ReportMetric(
                  title: 'هزینه‌های داخلی سفارش',
                  value: '${formatPersianNumber(data.orderInternalCosts)} ریال',
                  icon: Icons.card_giftcard_outlined,
                  tint: AdminColors.warningSoft,
                ),
                _ReportMetric(
                  title: 'درآمد ارسال',
                  value: '${formatPersianNumber(data.shippingRevenue)} ریال',
                  icon: Icons.local_shipping_outlined,
                  tint: AdminColors.successSoft,
                ),
                _ReportMetric(
                  title: 'هزینهٔ واقعی ارسال',
                  value: '${formatPersianNumber(data.shippingExpense)} ریال',
                  icon: Icons.local_shipping_rounded,
                  tint: AdminColors.successSoft,
                ),
                _ReportMetric(
                  title: 'مالیات پرداختنی',
                  value: '${formatPersianNumber(data.tax)} ریال',
                  icon: Icons.account_balance_rounded,
                  tint: AdminColors.dangerSoft,
                ),
                _ReportMetric(
                  title: 'سود پس از هزینه‌های ثبت‌شده',
                  value: '${formatPersianNumber(data.netProfit)} ریال',
                  icon: Icons.account_balance_wallet_rounded,
                  tint: AdminColors.infoSoft,
                ),
                _ReportMetric(
                  title: 'حاشیه سود ناخالص',
                  value:
                      '${formatPersianNumber(data.grossMarginPercent, fractionDigits: 1)}٪',
                  icon: Icons.percent_rounded,
                  tint: AdminColors.dangerSoft,
                ),
              ],
            ),
            const SizedBox(height: 18),
            AdminAnalyticsPanels(analytics: data, products: profitability),
            const SizedBox(height: 18),
            _priceHistoryPanel(),
            const SizedBox(height: 18),
            _salesSummary(data),
            const SizedBox(height: 20),
            _productProfitCards(),
          ],
        );
      },
    );
  }

  Widget _priceHistoryPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('روند بهای خرید و قیمت فروش', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AdminColors.heading))),
          if (priceHistorySkus.isNotEmpty) SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              value: selectedPriceSku,
              decoration: const InputDecoration(labelText: 'گونهٔ کالا'),
              items: priceHistorySkus.map((item) => DropdownMenuItem(value: item.sku, child: Text('${item.productTitle} · ${item.variantLabel}', overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (sku) {
                if (sku == null) return;
                setState(() => selectedPriceSku = sku);
                loadPriceHistory(sku);
              },
            ),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('بهای خرید هر بسته از بچ‌های ثبت‌شده با قیمت فروش همان SKU مقایسه می‌شود. سوابق از زمان ثبت در سیستم در دسترس‌اند.', style: TextStyle(fontSize: 11, color: AdminColors.muted)),
        const SizedBox(height: 16),
        if (loadingPriceHistory) const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
        else if (selectedPriceSku == null) const SizedBox(height: 120, child: Center(child: Text('گونه‌ای از کالا ثبت نشده است.')))
        else if (priceHistory.isEmpty) const SizedBox(height: 120, child: Center(child: Text('در این بازه سابقهٔ خرید یا تغییر قیمت ثبت نشده است.')))
        else AdminPriceHistoryChart(points: priceHistory),
      ]),
    ),
  );

  Widget _salesSummary(AdminAnalytics data) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'فروش چگونه به سود تبدیل شده؟',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AdminColors.heading,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatPersianInteger(data.orderCount)} سفارش پرداخت‌شده • ${formatPersianInteger(data.unitsSold)} بسته در این بازه',
            style: const TextStyle(color: AdminColors.muted),
          ),
          const SizedBox(height: 16),
          _moneyGrid([
            ('فروش کالا قبل از تخفیف', data.merchandiseRevenue),
            ('تخفیف کسرشده', data.discount),
            ('فروش کالا پس از تخفیف', data.merchandiseRevenue - data.discount),
            ('هزینهٔ کالا و آماده‌سازی', data.cost),
            ('از این مبلغ: هزینه‌های داخلی سفارش', data.orderInternalCosts),
            ('سود ناخالص کالا', data.grossProfit),
            ('سود پس از هزینهٔ کالا و ارسال', data.netProfit),
          ]),
          const SizedBox(height: 16),
          const Text(
            'سود ناخالص = فروش کالا پس از تخفیف − هزینهٔ کالا، آماده‌سازی و هزینه‌های داخلی سفارش.\nسود پس از هزینه‌های ثبت‌شده = سود ناخالص + درآمد ارسال − هزینهٔ واقعی ارسال. مالیات درآمد فروشگاه نیست.\nهزینه‌هایی مثل اجاره، دستمزد، تبلیغات و کارمزد درگاه در این عدد نیستند؛ پس این شاخص سود نهایی حسابداری نیست.',
            style: TextStyle(
              fontSize: 12,
              height: 1.9,
              color: AdminColors.muted,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _moneyGrid(List<(String, num)> items) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 660
          ? 3
          : box.maxWidth >= 420
          ? 2
          : 1;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AdminColors.canvas,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: AdminColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatPersianNumber(item.$2),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: item.$2 < 0
                            ? AdminColors.coral
                            : AdminColors.heading,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'ریال',
                      style: TextStyle(color: AdminColors.subtle, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _productProfitCards() {
    final query = normalizeNumberDigits(productQuery.trim().toLowerCase());
    final rows = profitability
        .where(
          (p) => normalizeNumberDigits(
            '${p.productTitle} ${p.variantLabel} ${p.sku}'.toLowerCase(),
          ).contains(query),
        )
        .toList();
    final last = rows.isEmpty ? 0 : (rows.length - 1) ~/ 5;
    final page = productPage.clamp(0, last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'سود به تفکیک محصول و بسته',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AdminColors.heading,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'هر کارت مربوط به یک اندازهٔ بسته است. هزینه‌ها از زمان ثبت همان سفارش خوانده می‌شوند؛ سود این کارت‌ها بدون درآمد و هزینهٔ ارسال است.',
          style: TextStyle(fontSize: 12, height: 1.8, color: AdminColors.muted),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() {
            productQuery = value;
            productPage = 0;
          }),
          decoration: const InputDecoration(
            labelText: 'جست‌وجوی محصول یا بسته',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const AdminEmptyState(
            icon: Icons.query_stats_rounded,
            title: 'محصولی برای نمایش نیست',
            detail: 'بازهٔ گزارش یا عبارت جست‌وجو را تغییر دهید.',
          ),
        for (final item in rows.skip(page * 5).take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.productTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.heading,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${toPersianDigits(item.variantLabel)} • ${formatPersianInteger(item.unitsSold)} بسته فروخته‌شده',
                      style: const TextStyle(color: AdminColors.primaryLight),
                    ),
                    Text(
                      item.quantitySold == null
                          ? 'مقدار وزنی برای سفارش‌های قدیمی ثبت نشده است.'
                          : item.baseUnit == 'gram'
                          ? 'وزن فروخته‌شده: ${formatPersianNumber(item.quantitySold! / 1000, fractionDigits: 3)} کیلوگرم'
                          : 'تعداد فروخته‌شده: ${formatPersianInteger(item.quantitySold!)} عدد',
                      style: const TextStyle(fontSize: 12, color: AdminColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'کد انبار: ${item.sku}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminColors.subtle,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _moneyGrid([
                      ('فروش قبل از تخفیف', item.revenue),
                      ('تخفیف', item.discount),
                      ('فروش پس از تخفیف', item.revenue - item.discount),
                      ('هزینهٔ کل', item.cost),
                      ('سود ناخالص', item.grossProfit),
                    ]),
                    const SizedBox(height: 14),
                    Text(
                      'حاشیه سود ناخالص: ${formatPersianNumber(_productMargin(item), fractionDigits: 1)}٪',
                      style: TextStyle(
                        color: item.grossProfit < 0
                            ? AdminColors.coral
                            : AdminColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.hasCostBreakdown) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      const Text(
                        'تفکیک هزینه',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      _moneyGrid([
                        ('خرید کالا', item.productCost),
                        ('بسته‌بندی', item.packagingCost),
                        ('هزینه‌های جانبی', item.additionalCost),
                        ('سهم هزینهٔ داخلی سفارش', item.orderInternalCost),
                      ]),
                    ],
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        if (!OwnerSession.instance.isAuthenticated ||
                            OwnerSession.instance.can(
                              AdminPermissions.inventoryRead,
                            ))
                          OutlinedButton.icon(
                            onPressed: widget.onNavigate == null
                                ? null
                                : () => widget.onNavigate!(
                                    AdminNavigationIntent(
                                      module: AdminModule.inventory,
                                      sku: item.sku,
                                    ),
                                  ),
                            icon: const Icon(
                              Icons.warehouse_outlined,
                              size: 18,
                            ),
                            label: const Text('مشاهده در انبار'),
                          ),
                        if (OwnerSession.instance.can(
                          AdminPermissions.ordersRead,
                        ))
                          OutlinedButton.icon(
                            onPressed: widget.onNavigate == null
                                ? null
                                : () => widget.onNavigate!(
                                    AdminNavigationIntent(
                                      module: AdminModule.orders,
                                      query: item.sku,
                                      createdFromUtc: _fromUtc,
                                      createdToUtcExclusive: _toUtcExclusive,
                                    ),
                                  ),
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                            ),
                            label: const Text('مشاهده سفارش‌ها'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'نمایش ${formatPersianInteger(rows.isEmpty ? 0 : page * 5 + 1)} تا ${formatPersianInteger((page * 5 + 5).clamp(0, rows.length))} از ${formatPersianInteger(rows.length)} بسته',
            ),
            TextButton(
              onPressed: page == 0
                  ? null
                  : () => setState(() => productPage = page - 1),
              child: const Text('قبلی'),
            ),
            TextButton(
              onPressed: page == last
                  ? null
                  : () => setState(() => productPage = page + 1),
              child: const Text('بعدی'),
            ),
          ],
        ),
        if (profitability.length >= 200)
          const Text(
            'این فهرست حداکثر ۲۰۰ بستهٔ گزارش‌شده را نشان می‌دهد؛ برای بررسی دقیق‌تر بازه را کوتاه‌تر کنید.',
            style: TextStyle(fontSize: 11, color: AdminColors.muted),
          ),
      ],
    );
  }

  num _productMargin(AdminProductProfitability item) {
    final netRevenue = item.revenue - item.discount;
    return netRevenue <= 0 ? 0 : item.grossProfit / netRevenue * 100;
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  String get help => switch (title) {
    'مبلغ پرداخت‌شده با ارسال و مالیات' => 'جمع مبلغی که مشتری برای سفارش‌های پرداخت‌شده پرداخته است؛ شامل کالا، ارسال و مالیات پس از تخفیف.',
    'فروش کالا پس از تخفیف' => 'درآمد اقلام کالا پس از اعمال تخفیف؛ هزینهٔ ارسال و مالیات در این رقم نیست.',
    'هزینهٔ کالا، آماده‌سازی و اقلام داخلی' => 'بهای کالا و آماده‌سازی ثبت‌شده در اقلام، به‌علاوه هزینه‌های خصوصی ثبت‌شده برای هر سفارش.',
    'هزینه‌های داخلی سفارش' => 'جمع بسته‌بندی اضافه، نمونه یا هدیه‌ای که برای مشتری رایگان است اما هزینه‌اش در حسابداری از سود کم می‌شود.',
    'درآمد ارسال' => 'هزینهٔ ارسالی که از مشتری دریافت شده است.',
    'هزینهٔ واقعی ارسال' => 'هزینهٔ ارسال ثبت‌شده برای سفارش‌ها؛ اگر هزینهٔ واقعی وارد نشده باشد، رقم گزارش ممکن است کمتر از واقع باشد.',
    'مالیات پرداختنی' => 'مالیات محاسبه‌شده برای سفارش‌های پرداخت‌شده در بازه.',
    'سود پس از هزینه‌های ثبت‌شده' => 'مبلغ فروش پس از کسر بهای کالا، هزینه‌های داخلی سفارش و هزینه واقعی ارسال. این شاخص هزینه‌های ثابت کسب‌وکار را کم نمی‌کند.',
    'حاشیه سود ناخالص' => 'نسبت سود کالا به فروش کالا پس از تخفیف؛ هزینه‌های ثابت و مالیات در این درصد لحاظ نشده‌اند.',
    _ => 'این شاخص بر اساس سفارش‌های بازهٔ انتخابی محاسبه شده است.',
  };
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: tint,
            foregroundColor: AdminColors.ink,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AdminColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    )),
                    Tooltip(
                      message: help,
                      child: const Icon(Icons.info_outline_rounded, size: 16, color: AdminColors.subtle),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AdminColors.inkDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
