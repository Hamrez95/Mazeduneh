import 'package:flutter/material.dart';
import 'demo_main.dart' as seed;

void main() => runApp(const MazedunehProfessionalDemoApp());

const Color kForest = Color(0xFF214A34);
const Color kForestSoft = Color(0xFF3F704E);
const Color kCanvas = Color(0xFFF4F6F1);
const Color kInk = Color(0xFF1D3125);
const Color kMuted = Color(0xFF718077);
const Color kLine = Color(0xFFE0E6DE);
const Color kSage = Color(0xFFE0ECD7);
const Color kSand = Color(0xFFF6E6D4);
const Color kRose = Color(0xFFF3DDD8);
const Color kLilac = Color(0xFFE9E1F1);

class MazedunehProfessionalDemoApp extends StatelessWidget {
  const MazedunehProfessionalDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مدیریت مزه‌دونه · نسخه نمایشی',
      locale: const Locale('fa'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kForest),
        scaffoldBackgroundColor: kCanvas,
        fontFamily: 'Tahoma',
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(22)),
            side: BorderSide(color: kLine),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kLine),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kForestSoft, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kForest,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kForest,
            minimumSize: const Size(0, 43),
            side: const BorderSide(color: Color(0xFFCCD8CE)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: DemoAuthGate(),
      ),
    );
  }
}

class DemoAuthGate extends StatefulWidget {
  const DemoAuthGate({super.key});

  @override
  State<DemoAuthGate> createState() => _DemoAuthGateState();
}

class _DemoAuthGateState extends State<DemoAuthGate> {
  bool signedIn = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: signedIn
          ? ProfessionalAdminShell(
              key: const ValueKey<String>('admin'),
              onLogout: () => setState(() => signedIn = false),
            )
          : DemoLoginPage(
              key: const ValueKey<String>('login'),
              onLogin: () => setState(() => signedIn = true),
            ),
    );
  }
}

class DemoLoginPage extends StatefulWidget {
  const DemoLoginPage({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  State<DemoLoginPage> createState() => _DemoLoginPageState();
}

class _DemoLoginPageState extends State<DemoLoginPage> {
  static const String demoEmail = 'admin@mazeduneh.ir';
  static const String demoPassword = 'Mazeduneh1405';

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscure = true;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void fillCredentials() {
    emailController.text = demoEmail;
    passwordController.text = demoPassword;
    setState(() => error = null);
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      loading = true;
      error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    if (emailController.text.trim() == demoEmail &&
        passwordController.text == demoPassword) {
      widget.onLogin();
      return;
    }

    setState(() {
      loading = false;
      error = 'برای ورود از اطلاعات حساب نمایشی استفاده کن.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 900;
          return Stack(
            children: <Widget>[
              const Positioned.fill(child: _LoginBackground()),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Color(0x24294333),
                                blurRadius: 55,
                                offset: Offset(0, 25),
                              ),
                            ],
                          ),
                          child: wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    const Expanded(child: LoginStory()),
                                    Expanded(child: loginForm()),
                                  ],
                                )
                              : Column(
                                  children: <Widget>[
                                    const LoginStory(compact: true),
                                    loginForm(),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget loginForm() {
    return Container(
      constraints: const BoxConstraints(minHeight: 620),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
      color: Colors.white,
      child: Form(
        key: formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'ورود به پنل مدیریت',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            const Text(
              'برای بررسی کامل تجربه مدیریتی وارد حساب دمو شو.',
              style: TextStyle(color: kMuted, fontSize: 11),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6ED),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFDCE7D7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      Icon(Icons.science_rounded, size: 17, color: kForestSoft),
                      SizedBox(width: 7),
                      Text(
                        'اطلاعات ورود دمو',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const SelectableText(
                    'ایمیل: admin@mazeduneh.ir',
                    style: TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 4),
                  const SelectableText(
                    'رمز: Mazeduneh1405',
                    style: TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 7),
                  TextButton.icon(
                    onPressed: fillCredentials,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: const Text('پرکردن خودکار'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 19),
            const Text(
              'ایمیل مدیر',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                hintText: 'admin@mazeduneh.ir',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (String? value) {
                final String text = value?.trim() ?? '';
                if (text.isEmpty) return 'ایمیل را وارد کن.';
                if (!text.contains('@')) return 'فرمت ایمیل درست نیست.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'رمز عبور',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            TextFormField(
              controller: passwordController,
              obscureText: obscure,
              textDirection: TextDirection.ltr,
              onFieldSubmitted: (_) {
                if (!loading) submit();
              },
              decoration: InputDecoration(
                hintText: 'رمز عبور دمو',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (String? value) {
                if ((value ?? '').isEmpty) return 'رمز عبور را وارد کن.';
                if ((value ?? '').length < 8) {
                  return 'رمز باید حداقل ۸ نویسه باشد.';
                }
                return null;
              },
            ),
            if (error != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(
                    color: Color(0xFF994E3B),
                    fontSize: 9,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading ? null : submit,
                icon: loading
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(
                  loading ? 'در حال ورود...' : 'ورود به پنل نمایشی',
                ),
              ),
            ),
            const SizedBox(height: 13),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.shield_outlined, size: 15, color: kMuted),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'ورود فقط در همین نشست مرورگر نگه داشته می‌شود و هیچ رمز یا توکنی ذخیره نمی‌شود.',
                    style: TextStyle(color: kMuted, fontSize: 8, height: 1.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFFF4F7EF), Color(0xFFF9EEDF)],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -170,
            right: -80,
            child: Container(
              width: 410,
              height: 410,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xA8DCEACC),
              ),
            ),
          ),
          Positioned(
            bottom: -170,
            left: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xA8F0D6C2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginStory extends StatelessWidget {
  const LoginStory({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 300 : 620),
      padding: EdgeInsets.all(compact ? 28 : 50),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFF193B29), Color(0xFF315F3F)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const MazedunehBrand(light: true),
          SizedBox(height: compact ? 30 : 78),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
            child: const Text(
              'نسخه نمایشی حرفه‌ای · داده محلی',
              style: TextStyle(
                color: Color(0xFFD5E5C6),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'فروش، سفارش و انبار؛\nهمه در یک تصویر روشن.',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 29 : 42,
              height: 1.45,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'این پنل برای نمایش تجربه مدیریتی مزه‌دونه ساخته شده و بدون اتصال به پرداخت، پیامک یا داده واقعی کار می‌کند.',
            style: TextStyle(
              color: Color(0xFFB9CABC),
              height: 1.9,
              fontSize: 11,
            ),
          ),
          if (!compact) ...<Widget>[
            const Spacer(),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                StoryPill(
                  icon: Icons.receipt_long_rounded,
                  label: 'چرخه سفارش',
                ),
                StoryPill(
                  icon: Icons.inventory_2_rounded,
                  label: 'کاتالوگ و انتشار',
                ),
                StoryPill(
                  icon: Icons.warehouse_rounded,
                  label: 'بچ و موجودی',
                ),
                StoryPill(
                  icon: Icons.query_stats_rounded,
                  label: 'گزارش سود',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class StoryPill extends StatelessWidget {
  const StoryPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: const Color(0xFFD6E6C8)),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class MazedunehBrand extends StatelessWidget {
  const MazedunehBrand({super.key, this.light = false, this.compact = false});

  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color foreground = light ? Colors.white : kInk;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            'assets/mazedooneh-mark.png',
            width: compact ? 39 : 46,
            height: compact ? 39 : 46,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'مدیریت مزه‌دونه',
              style: TextStyle(
                color: foreground,
                fontSize: compact ? 14 : 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'فروش، سفارش و موجودی',
              style: TextStyle(
                color: light ? const Color(0xFFAFC2B3) : kMuted,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum AdminSection { dashboard, orders, products, inventory, reports }

extension AdminSectionInfo on AdminSection {
  String get title {
    switch (this) {
      case AdminSection.dashboard:
        return 'داشبورد';
      case AdminSection.orders:
        return 'سفارش‌ها';
      case AdminSection.products:
        return 'محصولات';
      case AdminSection.inventory:
        return 'انبار و بچ‌ها';
      case AdminSection.reports:
        return 'گزارش‌ها';
    }
  }

  String get subtitle {
    switch (this) {
      case AdminSection.dashboard:
        return 'نمای امروز کسب‌وکار';
      case AdminSection.orders:
        return 'پرداخت، آماده‌سازی و ارسال';
      case AdminSection.products:
        return 'کاتالوگ، انتشار و موجودی';
      case AdminSection.inventory:
        return 'سری ورود، بهای خرید و انقضا';
      case AdminSection.reports:
        return 'فروش، سود و عملکرد هفتگی';
    }
  }

  IconData get icon {
    switch (this) {
      case AdminSection.dashboard:
        return Icons.space_dashboard_rounded;
      case AdminSection.orders:
        return Icons.receipt_long_rounded;
      case AdminSection.products:
        return Icons.inventory_2_rounded;
      case AdminSection.inventory:
        return Icons.warehouse_rounded;
      case AdminSection.reports:
        return Icons.query_stats_rounded;
    }
  }
}

class ProfessionalAdminShell extends StatefulWidget {
  const ProfessionalAdminShell({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<ProfessionalAdminShell> createState() =>
      _ProfessionalAdminShellState();
}

class _ProfessionalAdminShellState extends State<ProfessionalAdminShell> {
  AdminSection section = AdminSection.dashboard;
  late List<seed.DemoOrder> orders = seed.seedOrders();
  late List<seed.DemoProduct> products = seed.seedProducts();
  late List<seed.DemoBatch> batches = seed.seedBatches();

  void selectSection(AdminSection value) {
    setState(() => section = value);
  }

  void advanceOrder(String id) {
    setState(() {
      orders = orders.map((seed.DemoOrder order) {
        if (order.id != id) return order;
        final String next = switch (order.state) {
          'پرداخت‌شده' => 'در حال آماده‌سازی',
          'در حال آماده‌سازی' => 'ارسال‌شده',
          'ارسال‌شده' => 'تحویل‌شده',
          _ => order.state,
        };
        return order.copyWith(state: next);
      }).toList();
    });
    showToast('مرحله سفارش به‌روزرسانی شد.');
  }

  void toggleProduct(String sku) {
    setState(() {
      products = products.map((seed.DemoProduct product) {
        if (product.sku != sku) return product;
        return product.copyWith(published: !product.published);
      }).toList();
    });
    showToast('وضعیت انتشار محصول تغییر کرد.');
  }

  void addSampleProduct() {
    final int number = products.length + 1;
    setState(() {
      products = <seed.DemoProduct>[
        seed.DemoProduct(
          sku: 'DEMO-$number',
          title: 'محصول نمایشی جدید $number',
          category: 'پیش‌نویس',
          packageLabel: '۵۰۰ گرم',
          priceToman: 285000,
          stock: 9,
          published: false,
          icon: 'ن',
        ),
        ...products,
      ];
    });
    showToast('محصول جدید به‌صورت پیش‌نویس ثبت شد.');
  }

  void receiveSampleBatch() {
    final int number = batches.length + 1;
    setState(() {
      batches = <seed.DemoBatch>[
        seed.DemoBatch(
          lot: 'LOT-DEMO-$number',
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
    showToast('ورود بچ نمایشی ثبت شد.');
  }

  void showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool desktop = width >= 1030;
    final bool tablet = width >= 700;

    final Widget page = switch (section) {
      AdminSection.dashboard => DashboardPage(
          orders: orders,
          products: products,
          batches: batches,
          openOrders: () => selectSection(AdminSection.orders),
        ),
      AdminSection.orders => OrdersPage(
          orders: orders,
          advanceOrder: advanceOrder,
        ),
      AdminSection.products => ProductsPage(
          products: products,
          toggleProduct: toggleProduct,
          addProduct: addSampleProduct,
        ),
      AdminSection.inventory => InventoryPage(
          batches: batches,
          receiveBatch: receiveSampleBatch,
        ),
      AdminSection.reports => ReportsPage(
          orders: orders,
          products: products,
        ),
    };

    return Scaffold(
      appBar: desktop
          ? null
          : AppBar(
              toolbarHeight: 70,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const MazedunehBrand(compact: true),
              actions: <Widget>[
                IconButton(
                  onPressed: showNotifications,
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
                PopupMenuButton<String>(
                  onSelected: (String value) {
                    if (value == 'logout') widget.onLogout();
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Text('خروج از دمو'),
                    ),
                  ],
                  icon: const CircleAvatar(
                    backgroundColor: kSand,
                    child: Text(
                      'ح',
                      style: TextStyle(
                        color: kForest,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(31),
                child: DemoStatusStrip(),
              ),
            ),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              height: 70,
              selectedIndex: AdminSection.values.indexOf(section),
              onDestinationSelected: (int index) {
                selectSection(AdminSection.values[index]);
              },
              destinations: <NavigationDestination>[
                for (final AdminSection item in AdminSection.values)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.title,
                  ),
              ],
            ),
      body: Row(
        children: <Widget>[
          if (desktop)
            AdminSidebar(
              selected: section,
              onSelect: selectSection,
              onLogout: widget.onLogout,
            ),
          Expanded(
            child: Column(
              children: <Widget>[
                if (desktop)
                  AdminTopBar(
                    section: section,
                    onNotifications: showNotifications,
                    onLogout: widget.onLogout,
                  ),
                Expanded(
                  child: SafeArea(
                    top: !desktop,
                    child: Padding(
                      padding: EdgeInsets.all(tablet ? 22 : 14),
                      child: page,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text(
                    'اعلان‌های عملیاتی',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 14),
                  NotificationTile(
                    icon: Icons.inventory_rounded,
                    tone: kSand,
                    title: 'موجودی تخمه کدو کم است',
                    subtitle: '۶ بسته آماده فروش باقی مانده است.',
                  ),
                  SizedBox(height: 9),
                  NotificationTile(
                    icon: Icons.timer_outlined,
                    tone: kRose,
                    title: 'یک بچ نزدیک تاریخ مصرف است',
                    subtitle: 'LOT-1405-063 نیازمند بررسی FEFO است.',
                  ),
                  SizedBox(height: 9),
                  NotificationTile(
                    icon: Icons.shopping_bag_outlined,
                    tone: kSage,
                    title: 'سفارش NS-1048 پرداخت شده',
                    subtitle: 'آماده انتقال به مرحله آماده‌سازی است.',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class DemoStatusStrip extends StatelessWidget {
  const DemoStatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 31,
      alignment: Alignment.center,
      color: const Color(0xFFFFE8CB),
      child: const Text(
        'داده آزمایشی · بدون تراکنش، پیامک یا تغییر دیتابیس واقعی',
        style: TextStyle(
          color: Color(0xFF80562F),
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
  });

  final AdminSection selected;
  final ValueChanged<AdminSection> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 266,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF19372A),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x19233B2C),
            blurRadius: 35,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(10),
            child: MazedunehBrand(light: true),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '● نسخه دمو · داده محلی',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFF0C99D),
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (final AdminSection item in AdminSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: selected == item
                    ? const Color(0xFF3E694B)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelect(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          item.icon,
                          size: 20,
                          color: selected == item
                              ? Colors.white
                              : const Color(0xFFAABCAF),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: selected == item
                                  ? Colors.white
                                  : const Color(0xFFB5C4B9),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (selected == item)
                          const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: kSand,
                  child: Text(
                    'ح',
                    style: TextStyle(
                      color: kForest,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'حمیدرضا',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'مدیر نسخه نمایشی',
                        style: TextStyle(
                          color: Color(0xFF98AA9E),
                          fontSize: 7,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onLogout,
                  tooltip: 'خروج',
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFC3D0C6),
                    size: 19,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    super.key,
    required this.section,
    required this.onNotifications,
    required this.onLogout,
  });

  final AdminSection section;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      margin: const EdgeInsets.fromLTRB(10, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kLine),
      ),
      child: Row(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                section.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                section.subtitle,
                style: const TextStyle(color: kMuted, fontSize: 8),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.cloud_done_outlined, size: 16, color: kForestSoft),
                SizedBox(width: 6),
                Text(
                  'دمو آماده ارائه',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Badge(
            label: const Text('۳'),
            child: IconButton(
              onPressed: onNotifications,
              tooltip: 'اعلان‌ها',
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'logout') onLogout();
            },
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('خروج از دمو'),
              ),
            ],
            child: const Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: kSand,
                  child: Text(
                    'ح',
                    style: TextStyle(
                      color: kForest,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'حمیدرضا',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 20,
      runSpacing: 12,
      children: <Widget>[
        SizedBox(
          width: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                eyebrow,
                style: const TextStyle(
                  color: kForestSoft,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 9,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.orders,
    required this.products,
    required this.batches,
    required this.openOrders,
  });

  final List<seed.DemoOrder> orders;
  final List<seed.DemoProduct> products;
  final List<seed.DemoBatch> batches;
  final VoidCallback openOrders;

  @override
  Widget build(BuildContext context) {
    final Iterable<seed.DemoOrder> validOrders =
        orders.where((seed.DemoOrder order) => order.state != 'لغوشده');
    final int revenue = validOrders.fold<int>(
      0,
      (int sum, seed.DemoOrder order) => sum + order.payableToman,
    );
    final int cost = validOrders.fold<int>(
      0,
      (int sum, seed.DemoOrder order) => sum + order.estimatedCostToman,
    );
    final int activeOrders = orders
        .where(
          (seed.DemoOrder order) =>
              order.state != 'تحویل‌شده' && order.state != 'لغوشده',
        )
        .length;
    final int lowStock = products
        .where((seed.DemoProduct product) => product.stock <= 8)
        .length;
    final int margin = revenue == 0 ? 0 : ((revenue - cost) / revenue * 100).round();

    return ListView(
      children: <Widget>[
        PageHeading(
          eyebrow: 'شنبه ۱۰ مرداد · سناریوی نمایشی',
          title: 'سلام حمیدرضا؛ امروز چه خبر است؟',
          subtitle:
              'شاخص‌های مهم فروش و عملیات را یک‌جا ببین و از هشدارها مستقیم وارد کار لازم شو.',
          action: FilledButton.icon(
            onPressed: openOrders,
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('بررسی سفارش‌ها'),
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 1080
                ? 4
                : constraints.maxWidth >= 570
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 2.5 : 1.65,
              children: <Widget>[
                DashboardMetric(
                  title: 'فروش ثبت‌شده',
                  value: '${seed.toman(revenue)} تومان',
                  detail: '۶ سفارش معتبر',
                  icon: Icons.payments_outlined,
                  tone: kSage,
                  trend: '+۱۲٪',
                ),
                DashboardMetric(
                  title: 'سفارش فعال',
                  value: '$activeOrders سفارش',
                  detail: '۱ مورد آماده اقدام',
                  icon: Icons.shopping_bag_outlined,
                  tone: kSand,
                  trend: 'امروز',
                ),
                DashboardMetric(
                  title: 'حاشیه سود',
                  value: '$margin٪',
                  detail: 'برآورد با بهای بچ',
                  icon: Icons.donut_large_rounded,
                  tone: kLilac,
                  trend: '+۳٪',
                ),
                DashboardMetric(
                  title: 'هشدار موجودی',
                  value: '$lowStock مورد',
                  detail: '${batches.length} بچ فعال',
                  icon: Icons.inventory_2_outlined,
                  tone: kRose,
                  trend: 'نیازمند توجه',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 13),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget recent = RecentOrdersCard(
              orders: orders.take(5).toList(),
              openOrders: openOrders,
            );
            final Widget attention = AttentionCard(
              products: products,
              batches: batches,
            );
            if (constraints.maxWidth < 900) {
              return Column(
                children: <Widget>[
                  recent,
                  const SizedBox(height: 12),
                  attention,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 3, child: recent),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: attention),
              ],
            );
          },
        ),
        const SizedBox(height: 13),
        const OperationsJourneyCard(),
      ],
    );
  }
}

class DashboardMetric extends StatelessWidget {
  const DashboardMetric({
    super.key,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tone,
    required this.trend,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color tone;
  final String trend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: kForest, size: 21),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trend,
                    style: const TextStyle(
                      color: kForestSoft,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(title, style: const TextStyle(color: kMuted, fontSize: 9)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(color: Color(0xFF98A198), fontSize: 7),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentOrdersCard extends StatelessWidget {
  const RecentOrdersCard({
    super.key,
    required this.orders,
    required this.openOrders,
  });

  final List<seed.DemoOrder> orders;
  final VoidCallback openOrders;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PanelHeader(
              title: 'آخرین سفارش‌ها',
              subtitle: 'جدیدترین جریان‌های پرداخت و ارسال',
              actionLabel: 'مشاهده همه',
              onAction: openOrders,
            ),
            const SizedBox(height: 13),
            for (final seed.DemoOrder order in orders)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBF8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: kSage,
                        child: Text(
                          order.customer.substring(0, 1),
                          style: const TextStyle(
                            color: kForest,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              order.customer,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${order.id} · ${order.city}',
                              style: const TextStyle(color: kMuted, fontSize: 7),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            '${seed.toman(order.payableToman)} تومان',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          OrderStateBadge(order.state),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AttentionCard extends StatelessWidget {
  const AttentionCard({
    super.key,
    required this.products,
    required this.batches,
  });

  final List<seed.DemoProduct> products;
  final List<seed.DemoBatch> batches;

  @override
  Widget build(BuildContext context) {
    final List<seed.DemoProduct> low = products
        .where((seed.DemoProduct product) => product.stock <= 8)
        .take(3)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PanelHeader(
              title: 'نیازمند توجه',
              subtitle: 'هشدارهایی که بهتر است امروز بررسی شوند',
            ),
            const SizedBox(height: 13),
            for (final seed.DemoProduct product in low)
              AttentionRow(
                icon: Icons.inventory_2_outlined,
                tone: product.stock <= 5 ? kRose : kSand,
                title: product.title,
                subtitle: '${product.stock} بسته موجود · ${product.sku}',
              ),
            if (batches.any(
              (seed.DemoBatch batch) => batch.status == 'نزدیک مصرف',
            ))
              const AttentionRow(
                icon: Icons.event_busy_outlined,
                tone: kLilac,
                title: 'بچ نزدیک تاریخ مصرف',
                subtitle: 'LOT-1405-063 را برای برداشت FEFO بررسی کن.',
              ),
          ],
        ),
      ),
    );
  }
}

class AttentionRow extends StatelessWidget {
  const AttentionRow({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBF8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: kForest),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kMuted,
                      fontSize: 7,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: Color(0xFF9CA69E),
            ),
          ],
        ),
      ),
    );
  }
}

class OperationsJourneyCard extends StatelessWidget {
  const OperationsJourneyCard({super.key});

  @override
  Widget build(BuildContext context) {
    const List<JourneyStep> steps = <JourneyStep>[
      JourneyStep('پرداخت‌شده', '۱ سفارش', Icons.payments_outlined),
      JourneyStep('آماده‌سازی', '۱ سفارش', Icons.inventory_outlined),
      JourneyStep('ارسال‌شده', '۱ سفارش', Icons.local_shipping_outlined),
      JourneyStep('تحویل‌شده', '۳ سفارش', Icons.task_alt_rounded),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PanelHeader(
              title: 'مسیر عملیات امروز',
              subtitle: 'از تأیید پرداخت تا تحویل نهایی سفارش',
            ),
            const SizedBox(height: 17),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool narrow = constraints.maxWidth < 650;
                if (narrow) {
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.55,
                    mainAxisSpacing: 9,
                    crossAxisSpacing: 9,
                    children: <Widget>[
                      for (int index = 0; index < steps.length; index++)
                        JourneyTile(step: steps[index], active: index == 0),
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    for (int index = 0; index < steps.length; index++) ...<Widget>[
                      Expanded(
                        child: JourneyTile(
                          step: steps[index],
                          active: index == 0,
                        ),
                      ),
                      if (index < steps.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFFB0BBB1),
                            size: 17,
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyStep {
  const JourneyStep(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class JourneyTile extends StatelessWidget {
  const JourneyTile({
    super.key,
    required this.step,
    required this.active,
  });

  final JourneyStep step;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF1F6ED) : const Color(0xFFFAFBF8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(step.icon, color: kForestSoft),
          const SizedBox(height: 8),
          Text(
            step.title,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            step.value,
            style: const TextStyle(color: kMuted, fontSize: 7),
          ),
        ],
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    required this.orders,
    required this.advanceOrder,
  });

  final List<seed.DemoOrder> orders;
  final ValueChanged<String> advanceOrder;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String filter = 'همه';

  @override
  Widget build(BuildContext context) {
    const List<String> states = <String>[
      'همه',
      'پرداخت‌شده',
      'در حال آماده‌سازی',
      'ارسال‌شده',
      'تحویل‌شده',
    ];
    final List<seed.DemoOrder> visible = widget.orders.where(
      (seed.DemoOrder order) => filter == 'همه' || order.state == filter,
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PageHeading(
          eyebrow: 'عملیات فروش',
          title: 'سفارش‌ها',
          subtitle:
              'هر سفارش را از پرداخت تا آماده‌سازی، ارسال و تحویل با وضعیت روشن مدیریت کن.',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final String state in states)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        selected: filter == state,
                        label: Text(state, style: const TextStyle(fontSize: 8)),
                        onSelected: (_) => setState(() => filter = state),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (BuildContext context, int index) {
              final seed.DemoOrder order = visible[index];
              final bool canAdvance = <String>{
                'پرداخت‌شده',
                'در حال آماده‌سازی',
                'ارسال‌شده',
              }.contains(order.state);
              return OrderManagementCard(
                order: order,
                canAdvance: canAdvance,
                onAdvance: () => widget.advanceOrder(order.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class OrderManagementCard extends StatelessWidget {
  const OrderManagementCard({
    super.key,
    required this.order,
    required this.canAdvance,
    required this.onAdvance,
  });

  final seed.DemoOrder order;
  final bool canAdvance;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool mobile = constraints.maxWidth < 650;
            final Widget identity = Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: kSage,
                  child: Text(
                    order.customer.substring(0, 1),
                    style: const TextStyle(
                      color: kForest,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.id,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order.customer} · ${order.city}',
                        style: const TextStyle(color: kMuted, fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final List<Widget> details = <Widget>[
              Fact(label: 'مبلغ', value: '${seed.toman(order.payableToman)} تومان'),
              Fact(label: 'مرجع پرداخت', value: order.paymentReference),
              OrderStateBadge(order.state),
              FilledButton.tonalIcon(
                onPressed: canAdvance ? onAdvance : null,
                icon: Icon(
                  canAdvance
                      ? Icons.arrow_back_rounded
                      : Icons.done_all_rounded,
                  size: 17,
                ),
                label: Text(canAdvance ? 'مرحله بعد' : 'تکمیل‌شده'),
              ),
            ];
            if (mobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  identity,
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: details,
                  ),
                ],
              );
            }
            return Row(
              children: <Widget>[
                SizedBox(width: 230, child: identity),
                const SizedBox(width: 15),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 18,
                    runSpacing: 10,
                    children: details,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    super.key,
    required this.products,
    required this.toggleProduct,
    required this.addProduct,
  });

  final List<seed.DemoProduct> products;
  final ValueChanged<String> toggleProduct;
  final VoidCallback addProduct;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String filter = 'همه';

  @override
  Widget build(BuildContext context) {
    final List<seed.DemoProduct> visible = widget.products.where(
      (seed.DemoProduct product) {
        switch (filter) {
          case 'منتشرشده':
            return product.published;
          case 'پیش‌نویس':
            return !product.published;
          case 'کم‌موجودی':
            return product.stock <= 8;
          default:
            return true;
        }
      },
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PageHeading(
          eyebrow: 'کاتالوگ قابل فروش',
          title: 'محصولات',
          subtitle:
              'محصول را با قیمت، بسته فروش، موجودی و وضعیت انتشار مستقل مدیریت کن.',
          action: FilledButton.icon(
            onPressed: widget.addProduct,
            icon: const Icon(Icons.add_rounded),
            label: const Text('محصول نمونه'),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final String value in <String>[
                    'همه',
                    'منتشرشده',
                    'پیش‌نویس',
                    'کم‌موجودی',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        selected: filter == value,
                        label: Text(value, style: const TextStyle(fontSize: 8)),
                        onSelected: (_) => setState(() => filter = value),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 1050
                  ? 3
                  : constraints.maxWidth >= 650
                      ? 2
                      : 1;
              return GridView.builder(
                itemCount: visible.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 292,
                  crossAxisSpacing: 11,
                  mainAxisSpacing: 11,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final seed.DemoProduct product = visible[index];
                  return ProductCard(
                    product: product,
                    onToggle: () => widget.toggleProduct(product.sku),
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

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onToggle,
  });

  final seed.DemoProduct product;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final Color tone = product.stock <= 5
        ? kRose
        : product.stock <= 8
            ? kSand
            : kSage;
    final double progress = (product.stock / 24).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    product.title.substring(0, 1),
                    style: const TextStyle(
                      color: kForest,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${product.category} · ${product.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kMuted, fontSize: 7),
                      ),
                    ],
                  ),
                ),
                PublicationBadge(published: product.published),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: <Widget>[
                Expanded(
                  child: FactBox(
                    label: 'بسته فروش',
                    value: product.packageLabel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FactBox(
                    label: 'قیمت',
                    value: '${seed.toman(product.priceToman)} تومان',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FactBox(
              label: 'موجودی آماده فروش',
              value: '${product.stock} بسته',
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: const Color(0xFFEDF0EB),
                color: product.stock <= 5
                    ? const Color(0xFFC97462)
                    : const Color(0xFF6F9A70),
              ),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    product.published
                        ? 'در فروشگاه قابل خرید است'
                        : 'فقط در پنل دیده می‌شود',
                    style: const TextStyle(color: kMuted, fontSize: 7),
                  ),
                ),
                OutlinedButton(
                  onPressed: onToggle,
                  child: Text(product.published ? 'خروج از فروش' : 'انتشار'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({
    super.key,
    required this.batches,
    required this.receiveBatch,
  });

  final List<seed.DemoBatch> batches;
  final VoidCallback receiveBatch;

  @override
  Widget build(BuildContext context) {
    final int total = batches.fold<int>(
      0,
      (int sum, seed.DemoBatch batch) => sum + batch.remaining,
    );
    final int value = batches.fold<int>(
      0,
      (int sum, seed.DemoBatch batch) =>
          sum + batch.remaining * batch.unitCostToman,
    );
    final int expiring = batches
        .where((seed.DemoBatch batch) => batch.status == 'نزدیک مصرف')
        .length;

    return ListView(
      children: <Widget>[
        PageHeading(
          eyebrow: 'عملیات انبار',
          title: 'انبار و بچ‌ها',
          subtitle:
              'مانده هر سری ورود، تأمین‌کننده، بهای خرید و تاریخ مصرف را قابل ردیابی نگه دار.',
          action: FilledButton.icon(
            onPressed: receiveBatch,
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('ثبت ورود نمونه'),
          ),
        ),
        const SizedBox(height: 17),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            InventorySummary(
              title: 'موجودی بچ‌ها',
              value: '$total بسته',
              icon: Icons.inventory_outlined,
              tone: kSage,
            ),
            InventorySummary(
              title: 'ارزش خرید موجودی',
              value: '${seed.toman(value)} تومان',
              icon: Icons.account_balance_wallet_outlined,
              tone: kSand,
            ),
            InventorySummary(
              title: 'نزدیک تاریخ مصرف',
              value: '$expiring بچ',
              icon: Icons.event_busy_outlined,
              tone: kRose,
            ),
          ],
        ),
        const SizedBox(height: 13),
        for (final seed.DemoBatch batch in batches)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: BatchCard(batch: batch),
          ),
      ],
    );
  }
}

class InventorySummary extends StatelessWidget {
  const InventorySummary({
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
      width: 270,
      height: 112,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: kForest),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(color: kMuted, fontSize: 8),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BatchCard extends StatelessWidget {
  const BatchCard({super.key, required this.batch});

  final seed.DemoBatch batch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool mobile = constraints.maxWidth < 700;
            final Widget identity = Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: kSage,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: kForest),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        batch.lot,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${batch.sku} · ${batch.supplier}',
                        style: const TextStyle(color: kMuted, fontSize: 7),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final List<Widget> details = <Widget>[
              Fact(label: 'مانده', value: '${batch.remaining} بسته'),
              Fact(
                label: 'بهای واحد',
                value: '${seed.toman(batch.unitCostToman)} تومان',
              ),
              Fact(label: 'مصرف تا', value: batch.bestBefore),
              BatchStateBadge(batch.status),
            ];
            if (mobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  identity,
                  const SizedBox(height: 13),
                  Wrap(
                    spacing: 15,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: details,
                  ),
                ],
              );
            }
            return Row(
              children: <Widget>[
                SizedBox(width: 300, child: identity),
                const SizedBox(width: 20),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 20,
                    runSpacing: 10,
                    children: details,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({
    super.key,
    required this.orders,
    required this.products,
  });

  final List<seed.DemoOrder> orders;
  final List<seed.DemoProduct> products;

  @override
  Widget build(BuildContext context) {
    final Iterable<seed.DemoOrder> valid =
        orders.where((seed.DemoOrder order) => order.state != 'لغوشده');
    final int revenue = valid.fold<int>(
      0,
      (int sum, seed.DemoOrder order) => sum + order.payableToman,
    );
    final int cost = valid.fold<int>(
      0,
      (int sum, seed.DemoOrder order) => sum + order.estimatedCostToman,
    );
    final int profit = revenue - cost;
    final int margin = revenue == 0 ? 0 : (profit / revenue * 100).round();
    final int averageOrder = valid.isEmpty ? 0 : (revenue / valid.length).round();

    return ListView(
      children: <Widget>[
        PageHeading(
          eyebrow: 'تصمیم‌گیری مدیریتی',
          title: 'گزارش فروش و سود',
          subtitle:
              'اعداد این صفحه از سفارش‌ها و بهای تقریبی بچ‌های سناریوی نمایشی محاسبه می‌شوند.',
          action: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('خروجی CSV در نسخه دمو شبیه‌سازی شده است.'),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded),
            label: const Text('خروجی CSV'),
          ),
        ),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 550
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 11,
              crossAxisSpacing: 11,
              childAspectRatio: columns == 1 ? 2.5 : 1.65,
              children: <Widget>[
                DashboardMetric(
                  title: 'فروش ناخالص',
                  value: '${seed.toman(revenue)} تومان',
                  detail: '${valid.length} سفارش معتبر',
                  icon: Icons.trending_up_rounded,
                  tone: kSage,
                  trend: '+۱۲٪',
                ),
                DashboardMetric(
                  title: 'بهای تقریبی کالا',
                  value: '${seed.toman(cost)} تومان',
                  detail: 'بر اساس بچ‌های نمونه',
                  icon: Icons.price_check_outlined,
                  tone: kSand,
                  trend: 'برآورد',
                ),
                DashboardMetric(
                  title: 'سود ناخالص',
                  value: '${seed.toman(profit)} تومان',
                  detail: 'پیش از هزینه عملیاتی',
                  icon: Icons.savings_outlined,
                  tone: kLilac,
                  trend: '$margin٪',
                ),
                DashboardMetric(
                  title: 'میانگین سفارش',
                  value: '${seed.toman(averageOrder)} تومان',
                  detail: 'AOV سناریوی دمو',
                  icon: Icons.shopping_cart_checkout_rounded,
                  tone: kRose,
                  trend: '+۵٪',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 13),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const Widget chart = WeeklySalesChart();
            final Widget mix = CategoryMixCard(products: products);
            if (constraints.maxWidth < 850) {
              return Column(
                children: <Widget>[
                  chart,
                  const SizedBox(height: 12),
                  mix,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Expanded(flex: 3, child: WeeklySalesChart()),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: mix),
              ],
            );
          },
        ),
      ],
    );
  }
}

class WeeklySalesChart extends StatelessWidget {
  const WeeklySalesChart({super.key});

  @override
  Widget build(BuildContext context) {
    const List<ChartPoint> data = <ChartPoint>[
      ChartPoint('ش', .42, '۶.۲'),
      ChartPoint('ی', .58, '۸.۴'),
      ChartPoint('د', .37, '۵.۱'),
      ChartPoint('س', .73, '۱۰.۶'),
      ChartPoint('چ', .64, '۹.۳'),
      ChartPoint('پ', .91, '۱۳.۲'),
      ChartPoint('ج', .79, '۱۱.۵'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const PanelHeader(
              title: 'فروش هفت روز اخیر',
              subtitle: 'میلیون تومان · داده نمایشی',
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 260,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (final ChartPoint item in data)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          children: <Widget>[
                            Text(
                              item.value,
                              style: const TextStyle(color: kMuted, fontSize: 7),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: item.factor,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: <Color>[
                                          Color(0xFF76A06F),
                                          Color(0xFF315F3F),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.day,
                              style: const TextStyle(color: kMuted, fontSize: 8),
                            ),
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

class ChartPoint {
  const ChartPoint(this.day, this.factor, this.value);

  final String day;
  final double factor;
  final String value;
}

class CategoryMixCard extends StatelessWidget {
  const CategoryMixCard({super.key, required this.products});

  final List<seed.DemoProduct> products;

  @override
  Widget build(BuildContext context) {
    const List<CategoryRow> rows = <CategoryRow>[
      CategoryRow('مغزیجات', 52, kForestSoft),
      CategoryRow('میوه خشک', 21, Color(0xFFD58C5B)),
      CategoryRow('هدیه', 17, Color(0xFF9A719D)),
      CategoryRow('سایر', 10, Color(0xFF9CAA8E)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PanelHeader(
              title: 'ترکیب فروش',
              subtitle:
                  '${products.where((seed.DemoProduct item) => item.published).length} محصول منتشرشده',
            ),
            const SizedBox(height: 22),
            Center(
              child: SizedBox(
                width: 138,
                height: 138,
                child: Stack(
                  alignment: Alignment.center,
                  children: const <Widget>[
                    CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 21,
                      color: Color(0xFFE7ECE4),
                    ),
                    CircularProgressIndicator(
                      value: .72,
                      strokeWidth: 21,
                      color: kForestSoft,
                      strokeCap: StrokeCap.round,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '۷۲٪',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'خشکبار',
                          style: TextStyle(color: kMuted, fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            for (final CategoryRow row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: row.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.title,
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                    Text(
                      '${row.percent}٪',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
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

class CategoryRow {
  const CategoryRow(this.title, this.percent, this.color);

  final String title;
  final int percent;
  final Color color;
}

class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: kMuted, fontSize: 7),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 8),
            ),
          ),
      ],
    );
  }
}

class Fact extends StatelessWidget {
  const Fact({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(color: kMuted, fontSize: 7)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class FactBox extends StatelessWidget {
  const FactBox({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: kMuted, fontSize: 7)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class OrderStateBadge extends StatelessWidget {
  const OrderStateBadge(this.state, {super.key});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (Color, Color) colors = switch (state) {
      'پرداخت‌شده' => (const Color(0xFFE1EEE2), const Color(0xFF376944)),
      'در حال آماده‌سازی' =>
        (const Color(0xFFFFE8CB), const Color(0xFF835A2C)),
      'ارسال‌شده' => (const Color(0xFFE9E1F1), const Color(0xFF6E4F77)),
      'تحویل‌شده' => (const Color(0xFFDCEDE7), const Color(0xFF2F6C59)),
      _ => (const Color(0xFFF3E0DB), const Color(0xFF8C5447)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state,
        style: TextStyle(
          color: colors.$2,
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class PublicationBadge extends StatelessWidget {
  const PublicationBadge({super.key, required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: published ? kSage : kSand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        published ? 'منتشر' : 'پیش‌نویس',
        style: TextStyle(
          color: published ? kForestSoft : const Color(0xFF855C32),
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class BatchStateBadge extends StatelessWidget {
  const BatchStateBadge(this.state, {super.key});

  final String state;

  @override
  Widget build(BuildContext context) {
    final Color tone = switch (state) {
      'نزدیک مصرف' => kRose,
      'کم‌موجودی' => kSand,
      'تازه‌وارد' => kLilac,
      _ => kSage,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state,
        style: const TextStyle(
          color: kForest,
          fontSize: 7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: kForest, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 8,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
