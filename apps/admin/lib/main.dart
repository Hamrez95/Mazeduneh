import 'package:flutter/material.dart';

import 'catalog_api.dart';
import 'order_api.dart';

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
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF31584A)),
          scaffoldBackgroundColor: const Color(0xFFFAF7EF),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
              side: BorderSide(color: Color(0xFFE3E8E1)),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
          ),
        ),
        home: const Directionality(textDirection: TextDirection.rtl, child: AdminShell()),
      );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  var index = 0;
  final catalogKey = GlobalKey<CatalogPageState>();
  static const items = [
    ('داشبورد', Icons.space_dashboard_rounded),
    ('سفارش‌ها', Icons.receipt_long_rounded),
    ('محصولات', Icons.inventory_2_rounded),
    ('انبار', Icons.warehouse_rounded),
    ('گزارش‌ها', Icons.query_stats_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final pages = [
      const DashboardPage(),
      const OrdersPage(),
      CatalogPage(key: catalogKey),
      const InventoryPage(),
      const PlaceholderPage('گزارش‌ها', Icons.query_stats_rounded),
    ];
    return Scaffold(
      appBar: desktop ? null : AppBar(title: const Brand()),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => setState(() => index = value),
              destinations: [for (final item in items) NavigationDestination(icon: Icon(item.$2), label: item.$1)],
            ),
      body: Row(children: [
        if (desktop)
          Container(
            width: 245,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF203E34), borderRadius: BorderRadius.circular(24)),
            child: Column(children: [
              const Padding(padding: EdgeInsets.all(12), child: Brand(dark: true)),
              const SizedBox(height: 20),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: index == i,
                    selectedTileColor: const Color(0xFF31584A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: Icon(items[i].$2, color: index == i ? Colors.white : const Color(0xFFD5DFD6)),
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
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset('assets/mazedooneh-mark.png', width: 45, height: 45, fit: BoxFit.cover),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مدیریت مزه‌دونه', style: TextStyle(fontWeight: FontWeight.w800, color: dark ? Colors.white : null)),
          Text('کاتالوگ زنده فروشگاه', style: TextStyle(fontSize: 10, color: dark ? const Color(0xFFB9C8BC) : Colors.grey)),
        ]),
      ]);
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('سلام حمیدرضا 🌿', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('هسته عملیاتی فروشگاه در حال اتصال به داده‌های واقعی است.'),
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, children: const [
            MetricCard('فروش امروز', 'آزمایشی', Icons.payments_rounded),
            MetricCard('سفارش جدید', '۰', Icons.shopping_bag_rounded),
            MetricCard('کاتالوگ', 'متصل به API', Icons.cloud_done_rounded),
            MetricCard('وضعیت پرداخت', 'غیرفعال', Icons.lock_rounded),
          ]),
        ],
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.title, this.value, this.icon, {super.key});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 250,
        height: 135,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: const Color(0xFF31584A)),
              const Spacer(),
              Text(title, style: const TextStyle(color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
          ),
        ),
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
  final Set<String> changingPublication = {};
  bool loading = true;
  String? error;
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
      final result = await api.fetchProducts(includeDrafts: true);
      if (mounted) setState(() => products = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openCreateDialog() async {
    final command = await showDialog<CreateProductCommand>(context: context, builder: (_) => const ProductDialog());
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
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.grey),
          const SizedBox(height: 12),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
        ]),
      );
    }
    final visible = showDrafts ? products : products.where((item) => item.isPublished).toList();
    if (visible.isEmpty) return const Center(child: Text('محصولی با این وضعیت وجود ندارد.'));
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
            Row(children: [
              CircleAvatar(backgroundColor: const Color(0xFFE7F1E2), child: Text(product.isWeight ? '⚖' : '●')),
              const SizedBox(width: 10),
              Expanded(child: Text(product.title, style: const TextStyle(fontWeight: FontWeight.w900))),
              _PublicationBadge(product.isPublished),
            ]),
            const SizedBox(height: 8),
            Text('${product.category} · ${product.origin}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const Spacer(),
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (final variant in product.variants)
                Chip(label: Text('${variant.displayLabel} · ${variant.availablePackages} بسته', style: const TextStyle(fontSize: 10))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(
                  'موجودی کل: ${product.totalStock} بسته',
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
  const ProductDialog({super.key});

  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final slug = TextEditingController();
  final origin = TextEditingController();
  final sku = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
  String unitType = 'Weight';
  String category = 'آجیل و مغزها';
  num quantity = 250;

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
                  items: const [
                    DropdownMenuItem(value: 'آجیل و مغزها', child: Text('آجیل و مغزها')),
                    DropdownMenuItem(value: 'میوه خشک', child: Text('میوه خشک')),
                    DropdownMenuItem(value: 'لواشک و ترش‌مزه', child: Text('لواشک و ترش‌مزه')),
                    DropdownMenuItem(value: 'کوکی و شیرینی', child: Text('کوکی و شیرینی')),
                    DropdownMenuItem(value: 'کم‌شکر و پروتئینی', child: Text('کم‌شکر و پروتئینی')),
                    DropdownMenuItem(value: 'هدیه', child: Text('هدیه')),
                    DropdownMenuItem(value: 'پسته و مغزیجات', child: Text('پسته و مغزیجات')),
                    DropdownMenuItem(value: 'تخمه و تنقلات', child: Text('تخمه و تنقلات')),
                    DropdownMenuItem(value: 'کوکی و کیک سالم', child: Text('کوکی و کیک سالم')),
                  ],
                  onChanged: (value) => category = value!,
                ),
                const SizedBox(height: 10),
                TextFormField(controller: origin, decoration: const InputDecoration(labelText: 'مبدأ یا برند'), validator: required),
                const SizedBox(height: 10),
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
                  decoration: const InputDecoration(labelText: 'قیمت ریال'),
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
  String? numberRequired(String? value) => num.tryParse(value ?? '') == null ? 'عدد معتبر وارد کنید.' : null;

  void submit() {
    if (!formKey.currentState!.validate()) return;
    final label = unitType == 'Weight' ? '${quantity.toInt()} گرم' : '${quantity.toInt()} عدد';
    Navigator.pop(
      context,
      CreateProductCommand(
        title: title.text,
        slug: slug.text,
        category: category,
        origin: origin.text,
        unitType: unitType,
        isPublished: false,
        variants: [
          CreateVariantCommand(
            sku: sku.text,
            quantity: quantity,
            displayLabel: label,
            price: num.parse(price.text),
            availablePackages: int.parse(stock.text),
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
  String selectedState = '';
  String? error;
  bool loading = true;
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
      final result = await api.fetchOrders(state: selectedState.isEmpty ? null : selectedState);
      if (mounted) setState(() => orders = result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
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

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('سفارش‌ها', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const Text('فرآیند سفارش را از پرداخت تا تحویل کنترل کنید.', style: TextStyle(color: Colors.grey, fontSize: 11)),
              ]),
            ),
            DropdownButton<String>(
              value: selectedState,
              items: states.entries
                  .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => selectedState = value);
                load();
              },
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
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.grey),
          const SizedBox(height: 12),
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
        ]),
      );
    }
    if (orders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_rounded, size: 56, color: Color(0xFF9EACA1)),
          const SizedBox(height: 12),
          Text(selectedState.isEmpty ? 'هنوز سفارشی ثبت نشده است.' : 'سفارشی با این وضعیت وجود ندارد.'),
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
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 14,
              spacing: 20,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 210,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سفارش ${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${order.province}، ${order.city} · ${order.lineCount} قلم', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                ),
                Chip(
                  label: Text(states[order.state] ?? order.state),
                  backgroundColor: const Color(0xFFE7F1E2),
                ),
                Text('${order.payable.toStringAsFixed(0)} ${order.currency}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
              ],
            ),
          ),
        );
      },
    );
  }
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
  String? error;
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
      ]);
      if (mounted) setState(() {
        products = result[0] as List<Product>;
        movements = result[1] as List<StockMovement>;
      });
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
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

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مدیریت انبار', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const Text('موجودی هر SKU، اصلاحات دستی و دفترچه گردش کالا را یکجا کنترل کنید.', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ])),
        IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
      ]),
      const SizedBox(height: 18),
      Expanded(child: _body()),
    ]),
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.grey),
      const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center),
      const SizedBox(height: 12), FilledButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('تلاش دوباره')),
    ]));
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100 ? 2 : 1;
      return GridView.count(
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
                  CircleAvatar(backgroundColor: low ? const Color(0xFFFFE8C8) : const Color(0xFFE7F1E2), child: Text('\${variant.availablePackages}')),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(product.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('\${variant.displayLabel} · \${variant.sku}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ])),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : () => adjust(variant!),
                    icon: busy ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.tune_rounded),
                    label: const Text('اصلاح'),
                  ),
                ]);
              },
            )),
          ])),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('آخرین گردش موجودی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            Expanded(child: movements.isEmpty ? const Center(child: Text('گردشی ثبت نشده است.')) : ListView.separated(
              itemCount: movements.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (_, index) {
                final item = movements[index];
                final positive = item.quantityDelta >= 0;
                return ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: positive ? const Color(0xFFE7F1E2) : const Color(0xFFFFE8C8),
                    child: Icon(positive ? Icons.add_rounded : Icons.remove_rounded, size: 18),
                  ),
                  title: Text('\${item.sku} · \${positive ? '+' : ''}\${item.quantityDelta}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('\${item.reason} · مانده \${item.balanceAfter}', style: const TextStyle(fontSize: 11)),
                );
              },
            )),
          ])),
        ],
      );
    });
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
  Widget build(BuildContext context) => AlertDialog(
    title: Text('اصلاح موجودی \${widget.variant.sku}'),
    content: SizedBox(width: 430, child: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('موجودی فعلی: \${widget.variant.availablePackages} بسته'),
      const SizedBox(height: 12),
      TextFormField(controller: delta, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تغییر موجودی', hintText: 'مثبت برای ورود، منفی برای خروج'), validator: (value) => int.tryParse(value ?? '') == null ? 'عدد معتبر وارد کنید.' : null),
      const SizedBox(height: 10),
      TextFormField(controller: reason, decoration: const InputDecoration(labelText: 'علت اصلاح'), validator: (value) => value == null || value.trim().isEmpty ? 'علت را وارد کنید.' : null),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(onPressed: () {
        if (!formKey.currentState!.validate()) return;
        Navigator.pop(context, _AdjustmentCommand(int.parse(delta.text), reason.text.trim()));
      }, child: const Text('ثبت اصلاح')),
    ],
  );

  @override
  void dispose() {
    delta.dispose();
    reason.dispose();
    super.dispose();
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
