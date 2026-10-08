import 'secure_main.dart' show MazedunehSecureAdminApp;

import 'admin_state.dart';
import 'admin_permissions.dart';
import 'auth_session.dart';
import 'auth_api.dart';
import 'formatters.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';

import 'catalog_api.dart';
import 'order_api.dart';
import 'inventory_page.dart';
import 'orders_page.dart';
import 'media_api.dart';
import 'customer_management_page.dart';
import 'commerce_settings_page.dart';
import 'corporate_requests_page.dart';
import 'audit_log_page.dart';
import 'admin_users_page.dart';
import 'reports_page.dart';
import 'dashboard_page.dart';
import 'notifications_page.dart';
import 'package:file_picker/file_picker.dart';

export 'admin_theme.dart' show AdminColors;
export 'reports_page.dart' show ReportsPage;
export 'dashboard_page.dart' show DashboardPage, MetricCard;
export 'orders_page.dart' show OrdersPage;
export 'inventory_page.dart' show InventoryPage, AdjustmentDialog, AdjustmentCommand;
export 'notifications_page.dart' show NotificationsPage;

void main() => runApp(const MazedunehAdminApp());

// Compatibility name for existing launchers. Demo entry points are separate.
class MazedunehAdminApp extends MazedunehSecureAdminApp {
  const MazedunehAdminApp({super.key});
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
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF7C58B),
                  child: Text((OwnerSession.instance.email ?? 'م').substring(0, 1).toUpperCase()),
                ),
                title: Text(OwnerSession.instance.email ?? 'کاربر فروشگاه', style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  OwnerSession.instance.role == 'Owner' ? 'مدیر اصلی' : 'عضو فروشگاه · ${OwnerSession.instance.role ?? ''}',
                  style: const TextStyle(color: Color(0xFF9EACA1)),
                ),
                trailing: IconButton(
                  tooltip: 'خروج از حساب',
                  onPressed: () async {
                    try {
                      await AuthApiClient().logout();
                    } catch (_) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('از این دستگاه خارج شدید؛ ارتباط با سرور قطع بود.')));
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFD5DFD6)),
                ),
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
                  validator: stockRequired,
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
  String? stockRequired(String? value) => parsePersianInteger(value, min: 0, max: maxApiInteger) == null
      ? 'تعداد صحیح صفر یا بیشتر وارد کنید.'
      : null;

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
            TextFormField(
              controller: sortOrder,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ترتیب نمایش'),
              validator: (value) => parsePersianInteger(value, min: 0, max: maxApiInteger) == null
                  ? 'عدد صحیح بین صفر و حد مجاز وارد کنید.'
                  : null,
            ),
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
