import 'package:flutter/material.dart';

void main() => runApp(const MazedunehPartnerDemoApp());

class MazedunehPartnerDemoApp extends StatelessWidget {
  const MazedunehPartnerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دموی مدیریت مزه‌دونه',
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F6B45)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F2),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            side: BorderSide(color: Color(0xFFE1E7DF)),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: DemoAdminShell(),
      ),
    );
  }
}

class DemoAdminShell extends StatefulWidget {
  const DemoAdminShell({super.key});

  @override
  State<DemoAdminShell> createState() => _DemoAdminShellState();
}

class _DemoAdminShellState extends State<DemoAdminShell> {
  int selectedIndex = 0;
  late List<DemoOrder> orders = seedOrders();
  late List<DemoProduct> products = seedProducts();
  late List<DemoBatch> batches = seedBatches();

  static const destinations = <({String title, IconData icon})>[
    (title: 'داشبورد', icon: Icons.space_dashboard_rounded),
    (title: 'سفارش‌ها', icon: Icons.receipt_long_rounded),
    (title: 'محصولات', icon: Icons.inventory_2_rounded),
    (title: 'انبار', icon: Icons.warehouse_rounded),
    (title: 'گزارش‌ها', icon: Icons.query_stats_rounded),
  ];

  void advanceOrder(String id) {
    setState(() {
      orders = orders.map((order) {
        if (order.id != id) return order;
        final next = switch (order.state) {
          'پرداخت‌شده' => 'در حال آماده‌سازی',
          'در حال آماده‌سازی' => 'ارسال‌شده',
          'ارسال‌شده' => 'تحویل‌شده',
          _ => order.state,
        };
        return order.copyWith(state: next);
      }).toList();
    });
  }

  void toggleProduct(String sku) {
    setState(() {
      products = products
          .map((product) => product.sku == sku
              ? product.copyWith(published: !product.published)
              : product)
          .toList();
    });
  }

  void addDemoProduct() {
    final index = products.length + 1;
    setState(() {
      products = [
        DemoProduct(
          sku: 'DEMO-$index',
          title: 'محصول نمایشی جدید $index',
          category: 'پیش‌نویس',
          packageLabel: 'بسته ۵۰۰ گرمی',
          priceToman: 285000,
          stock: 9,
          published: false,
          icon: '🌰',
        ),
        ...products,
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('یک محصول پیش‌نویس نمونه اضافه شد.')),
    );
  }

  void receiveBatch() {
    final index = batches.length + 1;
    setState(() {
      batches = [
        DemoBatch(
          lot: 'LOT-DEMO-$index',
          sku: 'PI-AKB-500',
          supplier: 'تأمین‌کننده نمونه',
          remaining: 18,
          unitCostToman: 315000,
          bestBefore: '۱۴۰۶/۰۲/۱۵',
          status: 'تازه‌وارد',
        ),
        ...batches,
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('بچ نمایشی در انبار ثبت شد.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final page = switch (selectedIndex) {
      0 => DashboardView(orders: orders, products: products, batches: batches),
      1 => OrdersView(orders: orders, onAdvance: advanceOrder),
      2 => ProductsView(
          products: products,
          onToggle: toggleProduct,
          onAdd: addDemoProduct,
        ),
      3 => InventoryView(batches: batches, onReceive: receiveBatch),
      _ => ReportsView(orders: orders),
    };

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const DemoBrand(),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(32),
                child: DemoBanner(),
              ),
            ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (value) => setState(() => selectedIndex = value),
              destinations: [
                for (final item in destinations)
                  NavigationDestination(icon: Icon(item.icon), label: item.title),
              ],
            ),
      body: Row(
        children: [
          if (wide) _DesktopSidebar(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onSelected: (value) => setState(() => selectedIndex = value),
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(wide ? 24 : 14),
                child: page,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<({String title, IconData icon})> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF25372A),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.all(12), child: DemoBrand(dark: true)),
          const DemoBanner(dark: true),
          const SizedBox(height: 18),
          for (var index = 0; index < destinations.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                selected: selectedIndex == index,
                selectedTileColor: const Color(0xFF4A7651),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(
                  destinations[index].icon,
                  color: selectedIndex == index
                      ? Colors.white
                      : const Color(0xFFB9C8BC),
                ),
                title: Text(
                  destinations[index].title,
                  style: TextStyle(
                    color: selectedIndex == index
                        ? Colors.white
                        : const Color(0xFFB9C8BC),
                  ),
                ),
                onTap: () => onSelected(index),
              ),
            ),
          const Spacer(),
          const ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 8),
            leading: CircleAvatar(
              backgroundColor: Color(0xFFF1C792),
              child: Text('ح'),
            ),
            title: Text('حمیدرضا', style: TextStyle(color: Colors.white)),
            subtitle: Text('مدیر دمو', style: TextStyle(color: Color(0xFF9DAEA0))),
          ),
        ],
      ),
    );
  }
}

class DemoBrand extends StatelessWidget {
  const DemoBrand({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            'assets/mazedooneh-mark.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مدیریت مزه‌دونه',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: dark ? Colors.white : null,
              ),
            ),
            Text(
              'دموی ارائه شریک تجاری',
              style: TextStyle(
                fontSize: 9,
                color: dark ? const Color(0xFFB7C7BA) : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF344A39) : const Color(0xFFFFE6C7),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        'داده آزمایشی · بدون تراکنش واقعی',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: dark ? const Color(0xFFF4D2AA) : const Color(0xFF825328),
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.orders,
    required this.products,
    required this.batches,
  });

  final List<DemoOrder> orders;
  final List<DemoProduct> products;
  final List<DemoBatch> batches;

  @override
  Widget build(BuildContext context) {
    final revenue = orders
        .where((order) => order.state != 'لغوشده')
        .fold<int>(0, (sum, order) => sum + order.payableToman);
    final active = orders
        .where((order) => order.state != 'تحویل‌شده' && order.state != 'لغوشده')
        .length;
    final lowStock = products.where((product) => product.stock <= 8).length;

    return ListView(
      children: [
        const PageHeading(
          title: 'سلام حمیدرضا 🌿',
          subtitle: 'تصویر کامل فروش، سفارش و انبار در سناریوی نمایشی امروز',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              title: 'فروش امروز',
              value: '${toman(revenue)} تومان',
              icon: Icons.payments_rounded,
              tone: const Color(0xFFE5F0DF),
            ),
            MetricCard(
              title: 'سفارش فعال',
              value: '$active سفارش',
              icon: Icons.shopping_bag_rounded,
              tone: const Color(0xFFFFE5C8),
            ),
            MetricCard(
              title: 'هشدار موجودی',
              value: '$lowStock مورد',
              icon: Icons.inventory_rounded,
              tone: const Color(0xFFF5DCD0),
            ),
            MetricCard(
              title: 'بچ‌های فعال',
              value: '${batches.length} بچ',
              icon: Icons.qr_code_2_rounded,
              tone: const Color(0xFFE8E0F2),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final recentOrders = RecentOrdersCard(orders: orders.take(5).toList());
            final stock = LowStockCard(
              products: products.where((product) => product.stock <= 10).toList(),
            );
            if (constraints.maxWidth < 850) {
              return Column(children: [recentOrders, const SizedBox(height: 12), stock]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: recentOrders),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: stock),
              ],
            );
          },
        ),
      ],
    );
  }
}

class OrdersView extends StatelessWidget {
  const OrdersView({super.key, required this.orders, required this.onAdvance});

  final List<DemoOrder> orders;
  final ValueChanged<String> onAdvance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          title: 'سفارش‌ها',
          subtitle: 'چرخه دمو از پرداخت تا تحویل را با دکمه مرحله بعد نمایش بده.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final order = orders[index];
              final canAdvance = const {
                'پرداخت‌شده',
                'در حال آماده‌سازی',
                'ارسال‌شده',
              }.contains(order.state);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 18,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.id, style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text(
                              '${order.customer} · ${order.city}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${toman(order.payableToman)} تومان',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      StateChip(order.state),
                      Text(
                        order.paymentReference,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: canAdvance ? () => onAdvance(order.id) : null,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(canAdvance ? 'مرحله بعد' : 'تکمیل‌شده'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ProductsView extends StatelessWidget {
  const ProductsView({
    super.key,
    required this.products,
    required this.onToggle,
    required this.onAdd,
  });

  final List<DemoProduct> products;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 18,
          runSpacing: 12,
          children: [
            const SizedBox(
              width: 520,
              child: PageHeading(
                title: 'محصولات',
                subtitle: 'انتشار، موجودی، قیمت و بسته فروش در یک نمای قابل ارائه',
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('محصول نمونه'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1100
                  ? 3
                  : constraints.maxWidth >= 670
                      ? 2
                      : 1;
              return GridView.builder(
                itemCount: products.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 255,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, index) {
                  final product = products[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFE7F0E1),
                                child: Text(product.icon),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  product.title,
                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                              Chip(label: Text(product.published ? 'منتشر' : 'پیش‌نویس')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${product.category} · ${product.sku}',
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              InfoPill(product.packageLabel),
                              InfoPill('${product.stock} بسته'),
                              InfoPill('${toman(product.priceToman)} تومان'),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product.published ? 'قابل خرید در سایت' : 'فقط پنل مدیریت',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => onToggle(product.sku),
                                child: Text(product.published ? 'خروج از فروش' : 'انتشار'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class InventoryView extends StatelessWidget {
  const InventoryView({super.key, required this.batches, required this.onReceive});

  final List<DemoBatch> batches;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 18,
          runSpacing: 12,
          children: [
            const SizedBox(
              width: 520,
              child: PageHeading(
                title: 'انبار و بچ‌ها',
                subtitle: 'ردیابی تأمین‌کننده، قیمت خرید، مانده و تاریخ مصرف',
              ),
            ),
            FilledButton.icon(
              onPressed: onReceive,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('ثبت ورود نمونه'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: batches.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final batch = batches[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 185,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(batch.lot, style: const TextStyle(fontWeight: FontWeight.w900)),
                            Text(batch.sku, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      Text(batch.supplier),
                      InfoPill('${batch.remaining} بسته مانده'),
                      Text('${toman(batch.unitCostToman)} تومان خرید'),
                      Text(
                        'مصرف تا ${batch.bestBefore}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      StateChip(batch.status),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ReportsView extends StatelessWidget {
  const ReportsView({super.key, required this.orders});

  final List<DemoOrder> orders;

  @override
  Widget build(BuildContext context) {
    final validOrders = orders.where((order) => order.state != 'لغوشده');
    final revenue = validOrders.fold<int>(0, (sum, order) => sum + order.payableToman);
    final cost = validOrders.fold<int>(0, (sum, order) => sum + order.estimatedCostToman);
    final profit = revenue - cost;
    final margin = revenue == 0 ? 0 : (profit / revenue * 100).round();

    return ListView(
      children: [
        const PageHeading(
          title: 'گزارش مدیریتی',
          subtitle: 'نمونه گزارش فروش، حاشیه سود و سلامت موجودی برای ارائه شریک',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MetricCard(
              title: 'فروش ناخالص',
              value: '${toman(revenue)} تومان',
              icon: Icons.trending_up_rounded,
              tone: const Color(0xFFE5F0DF),
            ),
            MetricCard(
              title: 'بهای تقریبی کالا',
              value: '${toman(cost)} تومان',
              icon: Icons.price_check_rounded,
              tone: const Color(0xFFFFE5C8),
            ),
            MetricCard(
              title: 'سود ناخالص',
              value: '${toman(profit)} تومان',
              icon: Icons.savings_rounded,
              tone: const Color(0xFFE8E0F2),
            ),
            MetricCard(
              title: 'حاشیه سود',
              value: '$margin٪',
              icon: Icons.pie_chart_rounded,
              tone: const Color(0xFFF5DCD0),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const WeeklyChart(),
      ],
    );
  }
}

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key});

  @override
  Widget build(BuildContext context) {
    const data = [('ش', .42), ('ی', .58), ('د', .36), ('س', .72), ('چ', .64), ('پ', .9), ('ج', .78)];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'فروش هفت روز اخیر · داده دمو',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in data)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: item.$2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5D865F),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(item.$1, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
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
}

class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      height: 158,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: tone,
                child: Icon(icon, size: 20, color: const Color(0xFF3F6B45)),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentOrdersCard extends StatelessWidget {
  const RecentOrdersCard({super.key, required this.orders});

  final List<DemoOrder> orders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'آخرین سفارش‌ها',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            for (final order in orders)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE8EFE3),
                  child: Text(order.customer.substring(0, 1)),
                ),
                title: Text(order.customer),
                subtitle: Text('${order.id} · ${order.city}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${toman(order.payableToman)} تومان',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      order.state,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LowStockCard extends StatelessWidget {
  const LowStockCard({super.key, required this.products});

  final List<DemoProduct> products;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نیازمند توجه',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 12),
            for (final product in products)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFE6C7),
                  child: Text('${product.stock}'),
                ),
                title: Text(product.title),
                subtitle: Text(product.sku),
                trailing: const Icon(Icons.chevron_left_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class StateChip extends StatelessWidget {
  const StateChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'تحویل‌شده' => const Color(0xFFDDEDD9),
      'ارسال‌شده' => const Color(0xFFE5DDF0),
      'در حال آماده‌سازی' => const Color(0xFFFFE4C5),
      'پرداخت‌شده' => const Color(0xFFDCE9E1),
      'تازه‌وارد' => const Color(0xFFDDEDD9),
      _ => const Color(0xFFF2E2D8),
    };
    return Chip(backgroundColor: color, label: Text(label));
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10)),
    );
  }
}

class DemoOrder {
  const DemoOrder({
    required this.id,
    required this.customer,
    required this.city,
    required this.payableToman,
    required this.estimatedCostToman,
    required this.state,
    required this.paymentReference,
  });

  final String id;
  final String customer;
  final String city;
  final int payableToman;
  final int estimatedCostToman;
  final String state;
  final String paymentReference;

  DemoOrder copyWith({String? state}) {
    return DemoOrder(
      id: id,
      customer: customer,
      city: city,
      payableToman: payableToman,
      estimatedCostToman: estimatedCostToman,
      state: state ?? this.state,
      paymentReference: paymentReference,
    );
  }
}

class DemoProduct {
  const DemoProduct({
    required this.sku,
    required this.title,
    required this.category,
    required this.packageLabel,
    required this.priceToman,
    required this.stock,
    required this.published,
    required this.icon,
  });

  final String sku;
  final String title;
  final String category;
  final String packageLabel;
  final int priceToman;
  final int stock;
  final bool published;
  final String icon;

  DemoProduct copyWith({bool? published}) {
    return DemoProduct(
      sku: sku,
      title: title,
      category: category,
      packageLabel: packageLabel,
      priceToman: priceToman,
      stock: stock,
      published: published ?? this.published,
      icon: icon,
    );
  }
}

class DemoBatch {
  const DemoBatch({
    required this.lot,
    required this.sku,
    required this.supplier,
    required this.remaining,
    required this.unitCostToman,
    required this.bestBefore,
    required this.status,
  });

  final String lot;
  final String sku;
  final String supplier;
  final int remaining;
  final int unitCostToman;
  final String bestBefore;
  final String status;
}

List<DemoOrder> seedOrders() => const [
      DemoOrder(
        id: 'NS-1048',
        customer: 'سارا احمدی',
        city: 'تهران',
        payableToman: 1005000,
        estimatedCostToman: 682000,
        state: 'پرداخت‌شده',
        paymentReference: 'DEMO-PAY-82413',
      ),
      DemoOrder(
        id: 'NS-1047',
        customer: 'محمد رضایی',
        city: 'کرج',
        payableToman: 1290000,
        estimatedCostToman: 890000,
        state: 'در حال آماده‌سازی',
        paymentReference: 'DEMO-PAY-82402',
      ),
      DemoOrder(
        id: 'NS-1046',
        customer: 'نگار اکبری',
        city: 'اصفهان',
        payableToman: 775000,
        estimatedCostToman: 498000,
        state: 'ارسال‌شده',
        paymentReference: 'DEMO-PAY-82381',
      ),
      DemoOrder(
        id: 'NS-1045',
        customer: 'علی موسوی',
        city: 'شیراز',
        payableToman: 1580000,
        estimatedCostToman: 1030000,
        state: 'تحویل‌شده',
        paymentReference: 'DEMO-PAY-82340',
      ),
      DemoOrder(
        id: 'NS-1044',
        customer: 'مریم کریمی',
        city: 'رشت',
        payableToman: 650000,
        estimatedCostToman: 420000,
        state: 'تحویل‌شده',
        paymentReference: 'DEMO-PAY-82312',
      ),
      DemoOrder(
        id: 'NS-1043',
        customer: 'رضا نادری',
        city: 'تبریز',
        payableToman: 930000,
        estimatedCostToman: 601000,
        state: 'تحویل‌شده',
        paymentReference: 'DEMO-PAY-82298',
      ),
    ];

List<DemoProduct> seedProducts() => const [
      DemoProduct(sku: 'PI-AKB-500', title: 'پسته اکبری ممتاز', category: 'مغزیجات', packageLabel: '۵۰۰ گرم', priceToman: 465000, stock: 12, published: true, icon: '🥜'),
      DemoProduct(sku: 'PI-AHM-500', title: 'پسته احمدآقایی', category: 'مغزیجات', packageLabel: '۵۰۰ گرم', priceToman: 445000, stock: 10, published: true, icon: '🟢'),
      DemoProduct(sku: 'NU-ALM-500', title: 'بادام درختی خام', category: 'مغزیجات', packageLabel: '۵۰۰ گرم', priceToman: 330000, stock: 16, published: true, icon: '🌰'),
      DemoProduct(sku: 'NU-WAL-500', title: 'مغز گردوی ایرانی', category: 'مغزیجات', packageLabel: '۵۰۰ گرم', priceToman: 305000, stock: 8, published: true, icon: '🧠'),
      DemoProduct(sku: 'DF-MIX-300', title: 'میکس میوه خشک', category: 'میوه خشک', packageLabel: '۳۰۰ گرم', priceToman: 238000, stock: 21, published: true, icon: '🍊'),
      DemoProduct(sku: 'SE-PUM-500', title: 'تخمه کدو گوشتی', category: 'تنقلات', packageLabel: '۵۰۰ گرم', priceToman: 180000, stock: 6, published: true, icon: '🎃'),
      DemoProduct(sku: 'CK-PRO-4', title: 'کوکی پروتئینی', category: 'خوراکی سالم', packageLabel: 'پک ۴ عددی', priceToman: 360000, stock: 20, published: true, icon: '🍪'),
      DemoProduct(sku: 'GF-PARTY-12', title: 'جعبه هدیه دورهمی', category: 'هدیه', packageLabel: '۱٫۲ کیلوگرم', priceToman: 1290000, stock: 7, published: true, icon: '🎁'),
      DemoProduct(sku: 'DR-APRICOT-250', title: 'برگه زردآلو', category: 'میوه خشک', packageLabel: '۲۵۰ گرم', priceToman: 195000, stock: 5, published: false, icon: '🍑'),
    ];

List<DemoBatch> seedBatches() => const [
      DemoBatch(lot: 'LOT-1405-071', sku: 'PI-AKB-500', supplier: 'تعاونی رفسنجان', remaining: 12, unitCostToman: 318000, bestBefore: '۱۴۰۶/۰۱/۲۰', status: 'فعال'),
      DemoBatch(lot: 'LOT-1405-068', sku: 'PI-AHM-500', supplier: 'خشکبار کرمان', remaining: 10, unitCostToman: 302000, bestBefore: '۱۴۰۵/۱۲/۲۵', status: 'فعال'),
      DemoBatch(lot: 'LOT-1405-063', sku: 'NU-WAL-500', supplier: 'باغداران تویسرکان', remaining: 8, unitCostToman: 211000, bestBefore: '۱۴۰۵/۱۰/۱۰', status: 'نزدیک مصرف'),
      DemoBatch(lot: 'LOT-1405-060', sku: 'SE-PUM-500', supplier: 'بازرگانی سبزینه', remaining: 6, unitCostToman: 108000, bestBefore: '۱۴۰۵/۰۹/۳۰', status: 'کم‌موجودی'),
    ];

String toman(num value) {
  return value.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '٬',
      );
}
