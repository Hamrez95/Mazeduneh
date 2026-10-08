import 'secure_main.dart' show MazedunehSecureAdminApp;
import 'dart:math';
import 'inventory_pricing_dialog.dart';
import 'inventory_receipt_dialog.dart';
import 'dart:convert';

import 'admin_state.dart';
import 'admin_permissions.dart';
import 'auth_session.dart';
import 'auth_api.dart';
import 'formatters.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'catalog_api.dart';
import 'order_api.dart';
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
  List<AdminOverdueShipment> overdueShipments = const [];
  String selectedState = '';
  bool overdueOnly = false;
  int overdueDays = 3;
  final searchController = TextEditingController();
  String searchQuery = '';
  Object? error;
  bool loading = true;
  bool exporting = false;
  final selectedOrders = <String>{};
  bool bulkBusy = false;
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
      if (overdueOnly) {
        final result = await api.fetchOverdueShipments(days: overdueDays);
        if (mounted) {
          setState(() {
            overdueShipments = result;
            orders = const [];
            selectedOrders.clear();
          });
        }
      } else {
        final result = await api.fetchOrders(state: selectedState.isEmpty ? null : selectedState, query: searchQuery);
        if (mounted) {
          setState(() {
            orders = result;
            overdueShipments = const [];
            selectedOrders.removeWhere((id) => !result.any((order) => order.id == id));
          });
        }
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  Future<void> openDetail(AdminOrder order) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _OrderDetailSheet(api: api, order: order),
      );

  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final bytes = await api.exportOrdersCsv(state: selectedState.isEmpty ? null : selectedState, query: searchQuery);
      final opened = await launchUrl(
        Uri.dataFromBytes(bytes, mimeType: 'text/csv', parameters: {'charset': 'utf-8'}),
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خروجی باز نشد؛ اجازه بازکردن صفحه جدید را بررسی کنید.')));
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> bulkAdvance(String next) async {
    if (selectedOrders.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغییر وضعیت گروهی'),
        content: Text('${formatPersianInteger(selectedOrders.length)} سفارش به «${states[next] ?? next}» منتقل شود؟ سفارش‌هایی که مسیرشان مجاز نباشد، جدا گزارش می‌شوند.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('تأیید عملیات')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => bulkBusy = true);
    try {
      final result = await api.bulkTransition(selectedOrders.toList(), next, reason: 'عملیات گروهی از پنل');
      await load();
      if (mounted) {
        setState(() => selectedOrders.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${formatPersianInteger(result.$1)} سفارش به‌روزرسانی شد${result.$2 == 0 ? '' : ' و ${formatPersianInteger(result.$2)} مورد نیازمند بررسی است.'}')),
        );
      }
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, constraints) {
            final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('سفارش‌ها', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const Text('فرآیند سفارش را از پرداخت تا تحویل کنترل کنید.', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ]);
            final controls = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              FilterChip(
                label: const Text('ارسال‌های تأخیردار'),
                selected: overdueOnly,
                onSelected: (value) {
                  setState(() {
                    overdueOnly = value;
                    selectedOrders.clear();
                  });
                  load();
                },
              ),
              if (overdueOnly)
                DropdownButton<int>(
                  value: overdueDays,
                  items: const [1, 3, 5, 7, 14].map((days) => DropdownMenuItem(value: days, child: Text('بیش از $days روز'))).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => overdueDays = value);
                    load();
                  },
                ),
              DropdownButton<String>(
                value: selectedState,
                items: states.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selectedState = value);
                  load();
                },
              ),
              if (!OwnerSession.instance.isAuthenticated || OwnerSession.instance.can(AdminPermissions.ordersExport))
              FilledButton.tonalIcon(
                onPressed: exporting ? null : exportCsv,
                icon: exporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.file_download_outlined),
                label: const Text('خروجی CSV'),
              ),
              if (selectedOrders.isNotEmpty)
                PopupMenuButton<String>(
                  onSelected: bulkAdvance,
                  itemBuilder: (_) => states.entries
                      .where((entry) => entry.key.isNotEmpty)
                      .map((entry) => PopupMenuItem(value: entry.key, child: Text('انتقال به ${entry.value}')))
                      .toList(),
                  child: FilledButton.tonalIcon(
                    onPressed: null,
                    icon: bulkBusy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.playlist_add_check_rounded),
                    label: Text('عملیات گروهی (${formatPersianInteger(selectedOrders.length)})'),
                  ),
                ),
              IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
            ]);
            return constraints.maxWidth < 560
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heading, const SizedBox(height: 10), controls])
                : Row(children: [Expanded(child: heading), controls]);
          }),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              setState(() => searchQuery = value.trim());
              load();
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'جست‌وجو با شماره سفارش، نام، موبایل یا شهر',
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'پاک‌کردن جست‌وجو',
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchQuery = '');
                        load();
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: _body()),
        ]),
      );

  Widget _overdueBody() {
    if (overdueShipments.isEmpty) {
      return const Center(
        child: AdminEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'ارسال تأخیردار پیدا نشد',
          detail: 'سفارش‌های ارسال‌شدهٔ قدیمی‌تر از بازه انتخابی اینجا نمایش داده می‌شوند.',
        ),
      );
    }
    return ListView.separated(
      itemCount: overdueShipments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final shipment = overdueShipments[index];
        return Card(
          child: InkWell(
            onTap: () => openDetail(shipment.toAdminOrder()),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                spacing: 18,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('سفارش ${shipment.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(shipment.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${shipment.province}، ${shipment.city} · ${formatPersianInteger(shipment.lineCount)} قلم', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ]),
                  ),
                  Chip(
                    label: Text('${formatPersianInteger(shipment.daysOverdue)} روز تأخیر'),
                    backgroundColor: const Color(0xFFFCE6E0),
                  ),
                  Text(
                    shipment.trackingCode?.isNotEmpty == true ? 'رهگیری: ${shipment.trackingCode}' : 'کد رهگیری ثبت نشده',
                    style: const TextStyle(fontSize: 11, color: AdminColors.muted),
                  ),
                  Text(
                    shipment.shippingCarrier?.isNotEmpty == true ? shipment.shippingCarrier! : 'شرکت حمل ثبت نشده',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('ارسال: ${formatPersianDateTime(shipment.shippedAt)}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
                  const Icon(Icons.chevron_left_rounded, color: AdminColors.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    if (overdueOnly) return _overdueBody();
    if (orders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long_rounded, size: 56, color: Color(0xFF9EACA1)),
          const SizedBox(height: 12),
          AdminEmptyState(
            icon: Icons.receipt_long_rounded,
            title: selectedState.isEmpty ? 'هنوز سفارشی ثبت نشده است' : 'سفارشی با این وضعیت وجود ندارد',
            detail: searchQuery.isNotEmpty
                ? 'عبارت جست‌وجو یا فیلتر وضعیت را تغییر دهید.'
                : selectedState.isEmpty
                    ? 'سفارش‌های جدید بعد از ثبت در این فهرست دیده می‌شوند.'
                    : 'فیلتر وضعیت را تغییر دهید یا همه سفارش‌ها را ببینید.',
          ),
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
          child: InkWell(
            onTap: () => openDetail(order),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 14,
              spacing: 20,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Checkbox(
                  value: selectedOrders.contains(order.id),
                  onChanged: bulkBusy ? null : (value) => setState(() => value == true ? selectedOrders.add(order.id) : selectedOrders.remove(order.id)),
                  semanticLabel: 'انتخاب سفارش ${order.id.substring(0, 8)} برای عملیات گروهی',
                ),
                SizedBox(
                  width: 210,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سفارش ${order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${order.province}، ${order.city} · ${formatPersianInteger(order.lineCount)} قلم', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ]),
                ),
                Chip(
                  label: Text(states[order.state] ?? order.state),
                  backgroundColor: const Color(0xFFE7F1E2),
                ),
                Text('${formatPersianNumber(order.payable)} ${order.currency}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                const Icon(Icons.chevron_left_rounded, color: AdminColors.muted),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}


class _OrderDetailSheet extends StatefulWidget {
  const _OrderDetailSheet({required this.api, required this.order});
  final OrderApiClient api;
  final AdminOrder order;

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  AdminOrderDetail? detail;
  Object? error;
  bool loading = true;
  bool savingNote = false;
  bool savingShipping = false;
  bool openingPackingSlip = false;
  final noteController = TextEditingController();
  final carrierController = TextEditingController();
  final trackingController = TextEditingController();
  final shippingExpenseController = TextEditingController();
  final shippingReasonController = TextEditingController();

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
      final result = await widget.api.fetchOrderDetail(widget.order.id);
      if (mounted) {
        carrierController.text = result.shippingCarrier ?? '';
        trackingController.text = result.trackingCode ?? '';
        shippingExpenseController.text = result.shippingExpense == 0 ? '' : formatPersianNumber(result.shippingExpense);
        setState(() => detail = result);
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    carrierController.dispose();
    trackingController.dispose();
    shippingExpenseController.dispose();
    shippingReasonController.dispose();
    super.dispose();
  }

  Future<void> saveNote() async {
    final note = noteController.text.trim();
    if (note.isEmpty) return;
    setState(() => savingNote = true);
    try {
      await widget.api.addOrderNote(widget.order.id, note);
      noteController.clear();
      await load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('یادداشت داخلی ثبت شد.')));
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => savingNote = false);
    }
  }

  Future<void> saveShipping() async {
    final expense = shippingExpenseController.text.trim().isEmpty ? null : parsePersianNumber(shippingExpenseController.text);
    if (shippingExpenseController.text.trim().isNotEmpty && (expense == null || expense < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('هزینه واقعی ارسال را به‌صورت عدد معتبر وارد کنید.')));
      return;
    }
    final reason = shippingReasonController.text.trim();
    if (reason.isEmpty || reason.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دلیل ثبت یا اصلاح اطلاعات ارسال را وارد کنید.')));
      return;
    }
    setState(() => savingShipping = true);
    try {
      final result = await widget.api.updateShipping(widget.order.id, carrier: carrierController.text.trim().isEmpty ? null : carrierController.text.trim(), trackingCode: trackingController.text.trim().isEmpty ? null : trackingController.text.trim(), actualShippingCost: expense, reason: reason);
      if (mounted) {
        setState(() => detail = result);
        shippingReasonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اطلاعات ارسال ذخیره و در سابقه سفارش ثبت شد.')));
      }
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => savingShipping = false);
    }
  }

  Future<void> openPackingSlip() async {
    setState(() => openingPackingSlip = true);
    try {
      final html = await widget.api.fetchPackingSlipHtml(widget.order.id);
      final opened = await launchUrl(
        Uri.dataFromString(html, mimeType: 'text/html', encoding: utf8),
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برگه باز نشد؛ اجازه بازکردن صفحه جدید را بررسی کنید.')));
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => openingPackingSlip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
            ? AdminErrorState(error: error!, onRetry: load)
            : _content(detail!);
    return Material(
      color: AdminColors.canvas,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(children: [
              Expanded(child: Text('جزئیات سفارش', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), tooltip: 'بستن', icon: const Icon(Icons.close_rounded)),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }

  Widget _content(AdminOrderDetail detail) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('سفارش ${detail.order.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Chip(label: Text(_stateLabel(detail.order.state)), backgroundColor: AdminColors.mintSoft),
            if (!OwnerSession.instance.isAuthenticated || (OwnerSession.instance.can(AdminPermissions.ordersDocumentsRead) && OwnerSession.instance.can(AdminPermissions.customersPiiRead)))
            FilledButton.tonalIcon(
              onPressed: openingPackingSlip ? null : openPackingSlip,
              icon: openingPackingSlip ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.inventory_2_outlined),
              label: const Text('برگه بسته‌بندی'),
            ),
          ]),
          const SizedBox(height: 16),
          _detailCard(title: 'مشتری و تحویل', icon: Icons.person_pin_circle_outlined, child: Wrap(spacing: 28, runSpacing: 14, children: [
            _detailValue('مشتری', detail.order.customerName),
            _detailValue('تماس', detail.order.mobile),
            _detailValue('شهر', '${detail.order.province}، ${detail.order.city}'),
            _detailValue('روش ارسال', detail.shippingMethod),
            _detailValue('نشانی', detail.address, width: 320),
            _detailValue('کد پستی', detail.postalCode),
          ])),
          const SizedBox(height: 12),
          _detailCard(title: 'ارسال و هزینه واقعی', icon: Icons.local_shipping_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: 220, child: TextField(controller: carrierController, decoration: const InputDecoration(labelText: 'شرکت حمل'))),
              SizedBox(width: 220, child: TextField(controller: trackingController, decoration: const InputDecoration(labelText: 'کد رهگیری'))),
              SizedBox(width: 220, child: TextField(controller: shippingExpenseController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'هزینه واقعی ارسال', suffixText: 'ریال'))),
              SizedBox(width: 320, child: TextField(controller: shippingReasonController, maxLength: 500, decoration: const InputDecoration(labelText: 'دلیل ثبت یا اصلاح ارسال'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: Text(detail.shippedAt == null ? 'هنوز زمان ارسال ثبت نشده است.' : 'ارسال‌شده در ${formatPersianDateTime(detail.shippedAt!)}', style: const TextStyle(fontSize: 11, color: AdminColors.muted))),
              FilledButton.tonalIcon(onPressed: savingShipping ? null : saveShipping, icon: savingShipping ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('ذخیره ارسال')),
            ]),
          ])),
          const SizedBox(height: 12),
          _detailCard(title: 'اقلام سفارش', icon: Icons.shopping_bag_outlined, child: detail.lines.isEmpty
              ? const AdminEmptyState(icon: Icons.shopping_bag_outlined, title: 'قلمی ثبت نشده است', detail: 'اطلاعات اقلام این سفارش در دسترس نیست.')
              : Column(children: [for (var i = 0; i < detail.lines.length; i++) ...[
                  if (i > 0) const Divider(height: 22),
                  _lineRow(detail.lines[i]),
                ]])),
          const SizedBox(height: 12),
          _detailCard(title: 'جمع سفارش', icon: Icons.receipt_long_outlined, child: Column(children: [
            _moneyRow('جمع کالا', detail.subtotal, detail.order.currency),
            _moneyRow('ارسال', detail.shipping, detail.order.currency),
            if (detail.discount > 0) _moneyRow('تخفیف', -detail.discount, detail.order.currency),
            _moneyRow('مالیات', detail.tax, detail.order.currency),
            const Divider(height: 20),
            _moneyRow('مبلغ نهایی', detail.order.payable, detail.order.currency, strong: true),
            if (detail.shippingExpense > 0) _moneyRow('هزینه واقعی ارسال', detail.shippingExpense, detail.order.currency),
          ])),
          if (detail.payment != null) ...[
            const SizedBox(height: 12),
            _detailCard(title: 'پرداخت', icon: Icons.payments_outlined, child: Wrap(spacing: 28, runSpacing: 14, children: [
              _detailValue('وضعیت', detail.payment!.state),
              _detailValue('درگاه', detail.payment!.provider),
              _detailValue('مبلغ', '${formatPersianNumber(detail.payment!.amount)} ${detail.payment!.currency}'),
              if (detail.payment!.reference != null) _detailValue('شناسه پیگیری', detail.payment!.reference!),
            ])),
          ],
          const SizedBox(height: 12),
          _detailCard(title: 'مسیر سفارش', icon: Icons.route_rounded, child: detail.transitions.isEmpty
              ? const AdminEmptyState(icon: Icons.route_rounded, title: 'تاریخچه‌ای ثبت نشده است', detail: 'تغییرات وضعیت این سفارش هنوز ثبت نشده است.')
              : Column(children: [for (var i = 0; i < detail.transitions.length; i++) _timelineRow(detail.transitions[i], isLast: i == detail.transitions.length - 1)])),
          const SizedBox(height: 12),
          _detailCard(title: 'یادداشت داخلی', icon: Icons.sticky_note_2_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (detail.notes.isEmpty)
              const AdminEmptyState(icon: Icons.sticky_note_2_outlined, title: 'هنوز یادداشتی ثبت نشده است', detail: 'برای هماهنگی با همکاران، نتیجه تماس یا نکته مهم سفارش را اینجا بنویسید.'),
            if (detail.notes.isNotEmpty) ...[
              for (var i = 0; i < detail.notes.length; i++) ...[
                if (i > 0) const Divider(height: 22),
                _noteRow(detail.notes[i]),
              ],
              const SizedBox(height: 14),
            ],
            TextField(controller: noteController, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'یادداشت جدید', hintText: 'مثلاً: مشتری زمان تحویل را تأیید کرد.')),
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(onPressed: savingNote ? null : saveNote, icon: savingNote ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: const Text('ثبت یادداشت'))),
          ])),
        ],
      );

  Widget _detailCard({required String title, required IconData icon, required Widget child}) => Card(
        child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 20, color: AdminColors.ink), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.inkDeep))]),
          const SizedBox(height: 16),
          child,
        ])),
      );

  Widget _detailValue(String label, String value, {double? width}) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: AdminColors.muted)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]),
      );

  Widget _lineRow(AdminOrderLine line) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(line.productTitle, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${line.variantLabel} · ${line.sku}', style: const TextStyle(fontSize: 11, color: AdminColors.muted))])),
        Text('${formatPersianInteger(line.quantity)} × ${formatPersianNumber(line.unitPrice)}', style: const TextStyle(fontSize: 12, color: AdminColors.muted)),
        const SizedBox(width: 12),
        Text('${formatPersianNumber(line.lineTotal)} ریال', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]);

  Widget _moneyRow(String label, num value, String currency, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: strong ? AdminColors.inkDeep : AdminColors.muted, fontWeight: strong ? FontWeight.w900 : FontWeight.w500))), Text('${formatPersianNumber(value)} $currency', style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, color: value < 0 ? AdminColors.coral : AdminColors.inkDeep))]),
      );

  Widget _timelineRow(AdminOrderTransition item, {required bool isLast}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 28, child: Column(children: [Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: AdminColors.ink)), if (!isLast) Container(width: 1, height: 48, color: AdminColors.border)])),
        Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_stateLabel(item.state), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${formatPersianDateTime(item.occurredAt)} · ${item.actor}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)), if (item.reason.isNotEmpty) Text(item.reason, style: const TextStyle(fontSize: 12, color: AdminColors.muted))]))),
      ]);

  Widget _noteRow(AdminOrderNote item) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.note, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
        const SizedBox(height: 4),
        Text('${formatPersianDateTime(item.createdAt)} · ${item.actor}', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
      ]);

  String _stateLabel(String value) => const {
        'AwaitingPayment': 'در انتظار پرداخت', 'Paid': 'پرداخت‌شده', 'Preparing': 'در حال آماده‌سازی',
        'Shipped': 'ارسال‌شده', 'Delivered': 'تحویل‌شده', 'Cancelled': 'لغوشده', 'Expired': 'منقضی‌شده',
      }[value] ?? value;
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
  List<InventoryBatch> batches = const [];
  Object? error;
  bool loading = true;
  String? busySku;
  String? purchaseCursor, purchaseError, purchaseSku;
  bool loadingPurchases = false;
  int purchaseGeneration = 0;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; purchaseGeneration++; loadingPurchases = false; });
    final generation = purchaseGeneration;
    final sku = purchaseSku;
    try {
      final result = await Future.wait([
        catalog.fetchProducts(includeDrafts: true),
        orders.fetchInventoryMovements(limit: 30),
        orders.fetchInventoryPurchases(sku: sku),
      ]);
      if (mounted && generation == purchaseGeneration) setState(() {
        products = result[0] as List<Product>;
        movements = result[1] as List<StockMovement>;
        final purchases = result[2] as InventoryPurchasePage;
        batches = purchases.items; purchaseCursor = purchases.nextCursor; purchaseError = null;
      });
    } catch (exception) {
      if (mounted && generation == purchaseGeneration) setState(() => error = exception);
    } finally {
      if (mounted && generation == purchaseGeneration) setState(() => loading = false);
    }
  }

  Future<void> loadMorePurchases() async {
    if (purchaseCursor == null || loadingPurchases) return;
    final generation = purchaseGeneration;
    setState(() { loadingPurchases = true; purchaseError = null; });
    try {
      final page = await orders.fetchInventoryPurchases(sku: purchaseSku, cursor: purchaseCursor);
      if (mounted && generation == purchaseGeneration) setState(() { batches = [...batches, ...page.items.where((item) => !batches.any((b) => b.id == item.id))]; purchaseCursor = page.nextCursor; });
    } catch (exception) {
      if (mounted && generation == purchaseGeneration) setState(() {
        if (exception is OrderApiException && (exception.statusCode == 401 || exception.statusCode == 403)) {
          batches = []; purchaseCursor = null; error = exception;
        } else { purchaseError = 'خریدهای قدیمی دریافت نشد: $exception. دوباره تلاش کنید.'; }
      });
    } finally { if (mounted && generation == purchaseGeneration) setState(() => loadingPurchases = false); }
  }

  Future<void> adjust(ProductVariant variant) async {
    if (busySku != null) return;
    setState(() => busySku = variant.sku);
    late final List<InventoryBatch> variantBatches;
    try {
      variantBatches = await orders.fetchInventoryBatches(sku: variant.sku, limit: 250);
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('بچ‌های این کالا دریافت نشدند؛ اصلاح انجام نشد. ${requestErrorMessage(exception)}')),
      );
      return;
    } finally {
      if (mounted) setState(() => busySku = null);
    }
    if (!mounted) return;
    final result = await showDialog<AdjustmentCommand>(
      context: context,
      builder: (_) => AdjustmentDialog(
        variant: variant,
        batches: variantBatches,
        onSubmit: (command, operationKey) async {
          if (command.isWaste) {
            await orders.writeOffStock(variant.sku, command.batchCode!, command.delta, command.reason, operationKey: operationKey);
          } else {
            await orders.adjustStock(variant.sku, command.delta, command.reason, operationKey: operationKey);
          }
        },
      ),
    );
    if (result == null) return;
    await load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.isWaste ? 'ضایعات ثبت و از موجودی قابل‌فروش خارج شد.' : 'موجودی با موفقیت ثبت شد.')));
  }

  Future<void> receiveBatch() async {
    final result = await showDialog<InventoryBatch>(context: context, builder: (_) => BatchDialog(products: products,
      onSave: (receipt) => orders.receiveInventoryBatch(sku: receipt.sku, batchCode: receipt.batchCode,
        receivedPackages: receipt.receivedPackages, producedAt: receipt.producedAt, expiresAt: receipt.expiresAt,
        costPrice: receipt.costPrice, packagingCost: receipt.packagingCost, additionalCost: receipt.additionalCost,
        purchasedAt: receipt.purchasedAt, supplier: receipt.supplier,
        supplierContactName: receipt.supplierContactName, supplierPhone: receipt.supplierPhone,
        supplierEmail: receipt.supplierEmail, supplierAddress: receipt.supplierAddress, supplierNotes: receipt.supplierNotes)));
    if (result == null) return;
    await load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خرید و موجودی ثبت شد؛ سابقه در فهرست دریافت‌ها قابل مشاهده است.')));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مدیریت انبار', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
          const Text('موجودی هر SKU، اصلاحات دستی و دفترچه گردش کالا را یکجا کنترل کنید.', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ]);
        final controls = Wrap(spacing: 8, children: [
        OutlinedButton.icon(onPressed: products.isEmpty ? null : () async {
          final applied = await showDialog<bool>(context: context, builder: (_) => InventoryPricingDialog(products: products, orders: orders));
          if (applied == true) {
            await load();
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قیمت فروش اعمال شد؛ فروشگاه قیمت جدید را از API می‌گیرد.')));
          }
        }, icon: const Icon(Icons.calculate_outlined), label: const Text('محاسبه قیمت فروش')),
        OutlinedButton.icon(onPressed: products.isEmpty || !OwnerSession.instance.can(AdminPermissions.inventoryWrite) ? null : receiveBatch, icon: const Icon(Icons.event_available_rounded), label: const Text('ثبت خرید')),
        const SizedBox(width: 8),
        IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد'),
        ]);
        return constraints.maxWidth < 720
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, controls])
          : Row(children: [Expanded(child: heading), controls]);
      }),
      const SizedBox(height: 18),
      Expanded(child: _body()),
    ]),
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100 ? 2 : 1;
      final expiredCount = batches.where((item) => item.isExpired && item.remainingPackages > 0).length;
      final expiringCount = batches.where((item) => item.isExpiringSoon && item.remainingPackages > 0).length;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (expiredCount > 0 || expiringCount > 0) ...[
          _InventoryAttentionBanner(expiredCount: expiredCount, expiringCount: expiringCount),
          const SizedBox(height: 14),
        ],
        Expanded(child: GridView.count(
          key: const ValueKey('inventory-sections'),
          crossAxisCount: columns, mainAxisSpacing: 14, crossAxisSpacing: 14,
          mainAxisExtent: (constraints.maxWidth < 720 ? 340.0 : 380.0) * MediaQuery.textScalerOf(context).scale(14) / 14,
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
                  CircleAvatar(backgroundColor: low ? const Color(0xFFFFE8C8) : const Color(0xFFE7F1E2), child: Text(formatPersianInteger(variant.availablePackages))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(product.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${variant.displayLabel} · ${variant.sku}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ])),
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : () => adjust(variant!),
                    icon: busy ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.tune_rounded),
                    label: const Text('اصلاح'),
                  ),
                ]);
              },
            )),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('آخرین گردش موجودی', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            Expanded(child: movements.isEmpty ? const SingleChildScrollView(child: AdminEmptyState(icon: Icons.swap_vert_rounded, title: 'گردشی ثبت نشده است', detail: 'دریافت، فروش یا اصلاح موجودی در اینجا ثبت می‌شود.')) : ListView.separated(
              itemCount: movements.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (_, index) {
                final item = movements[index];
                final positive = item.quantityDelta >= 0;
                final sign = positive ? '+' : '-';
                return ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: positive ? const Color(0xFFE7F1E2) : const Color(0xFFFFE8C8),
                    child: Icon(positive ? Icons.add_rounded : Icons.remove_rounded, size: 18),
                  ),
                  title: Text('${item.sku} · $sign${formatPersianInteger(item.quantityDelta.abs())}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${item.movementType == 'Waste' ? 'ضایعات' : item.movementType == 'ManualAdjustment' ? 'اصلاح دستی' : item.movementType} · ${item.reason} · مانده ${formatPersianInteger(item.balanceAfter)}', style: const TextStyle(fontSize: 11)),
                );
              },
            )),
          ]))),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('سوابق خرید و تاریخ انقضا', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('purchase-filter-${purchaseSku ?? 'all'}'),
              initialValue: purchaseSku ?? '', isExpanded: true,
              decoration: const InputDecoration(labelText: 'خریدهای کدام کالا؟'),
              items: [
                const DropdownMenuItem(value: '', child: Text('همهٔ کالاها')),
                for (final product in products) for (final variant in product.variants)
                  DropdownMenuItem(value: variant.sku, child: Text('${product.title} · ${variant.displayLabel} · ${variant.sku}')),
                if (purchaseSku != null && !products.any((product) => product.variants.any((variant) => variant.sku == purchaseSku)))
                  DropdownMenuItem(value: purchaseSku, child: Text('کالای حذف‌شده · $purchaseSku')),
              ],
              onChanged: (value) {
                final next = value == '' ? null : value;
                if (next == purchaseSku) return;
                setState(() => purchaseSku = next);
                load();
              },
            ),
            const SizedBox(height: 12),
            Expanded(child: batches.isEmpty ? const SingleChildScrollView(child: AdminEmptyState(icon: Icons.event_available_rounded, title: 'خریدی پیدا نشد', detail: 'همهٔ کالاها را انتخاب کنید یا اولین خرید را ثبت کنید.')) : ListView.separated(
              key: const ValueKey('inventory-purchases'),
              itemCount: batches.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 14),
              itemBuilder: (_, index) {
                if (index == batches.length) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (purchaseError != null) Text(purchaseError!, style: const TextStyle(color: AdminColors.coral)),
                  if (purchaseCursor != null) TextButton(onPressed: loadingPurchases ? null : loadMorePurchases,
                    child: Text(loadingPurchases ? 'در حال دریافت…' : purchaseError == null ? 'مشاهده خریدهای قدیمی‌تر' : 'تلاش دوباره')),
                ]);
                final item = batches[index];
                final supplierDetails = <String>[
                  if (item.supplierContactName?.isNotEmpty == true) 'شخص تماس: ${item.supplierContactName}',
                  if (item.supplierPhone?.isNotEmpty == true) 'تلفن: ${item.supplierPhone}',
                  if (item.supplierEmail?.isNotEmpty == true) 'ایمیل: ${item.supplierEmail}',
                  if (item.supplierAddress?.isNotEmpty == true) 'نشانی: ${item.supplierAddress}',
                  if (item.supplierNotes?.isNotEmpty == true) 'یادداشت: ${item.supplierNotes}',
                ].join(' · ');
                final supplierSummary = [item.supplier ?? 'تأمین‌کننده ثبت نشده', if (supplierDetails.isNotEmpty) supplierDetails].join(' · ');
                final expired = item.isExpired;
                final expiringSoon = item.isExpiringSoon && !expired;
                return ListTile(
                  dense: true, contentPadding: EdgeInsets.zero,
                  leading: Icon(expired || expiringSoon ? Icons.warning_amber_rounded : Icons.event_available_rounded, color: expired ? AdminColors.coral : expiringSoon ? AdminColors.amber : AdminColors.ink),
                  title: Text('${item.productTitle} · ${item.batchCode}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('خرید ${item.purchasedAt == null ? 'تاریخ نامشخص' : formatPersianDateTime(item.purchasedAt!)} · $supplierSummary\n${formatPersianInteger(item.receivedPackages)} بسته · خرید هر بسته ${formatToman(item.costPrice)} تومان · جمع خرید ${formatToman(item.costPrice * item.receivedPackages)} تومان\n${item.sku} · مانده ${formatPersianInteger(item.remainingPackages)} · ${expired ? 'منقضی شده' : expiringSoon ? 'نزدیک انقضا' : 'انقضا'} ${formatPersianDateTime(item.expiresAt)}', style: TextStyle(fontSize: 11, color: expired ? AdminColors.coral : expiringSoon ? const Color(0xFF9A661D) : AdminColors.muted)),
                );
              },
            )),
          ]))),
          ],
        )),
      ]);
    });
  }
}

class _InventoryAttentionBanner extends StatelessWidget {
  const _InventoryAttentionBanner({required this.expiredCount, required this.expiringCount});

  final int expiredCount;
  final int expiringCount;

  @override
  Widget build(BuildContext context) {
    final expiredText = expiredCount == 0 ? '' : '${formatPersianInteger(expiredCount)} بچ منقضی با موجودی باقی‌مانده';
    final expiringText = expiringCount == 0 ? '' : '${formatPersianInteger(expiringCount)} بچ تا ۳۰ روز آینده منقضی می‌شود';
    final detail = [expiredText, expiringText].where((value) => value.isNotEmpty).join(' · ');
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'هشدار موجودی: $detail',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: expiredCount > 0 ? const Color(0xFFFFECE8) : const Color(0xFFFFF5DF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: expiredCount > 0 ? const Color(0xFFF1C5BB) : const Color(0xFFF0D69A)),
        ),
        child: Row(children: [
          Icon(expiredCount > 0 ? Icons.priority_high_rounded : Icons.schedule_rounded, color: expiredCount > 0 ? AdminColors.coral : const Color(0xFF9A661D)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(detail, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4)),
            const SizedBox(height: 3),
            const Text('اولویت با برداشت FEFO', style: TextStyle(fontSize: 11, color: AdminColors.muted)),
          ])),
        ]),
      ),
    );
  }
}

class AdjustmentCommand {
  const AdjustmentCommand(this.delta, this.reason, {this.isWaste = false, this.batchCode});
  final int delta;
  final String reason;
  final bool isWaste;
  final String? batchCode;
}

class AdjustmentDialog extends StatefulWidget {
  const AdjustmentDialog({super.key, required this.variant, this.batches = const [], this.onSubmit});
  final ProductVariant variant;
  final List<InventoryBatch> batches;
  final Future<void> Function(AdjustmentCommand command, String operationKey)? onSubmit;
  @override
  State<AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<AdjustmentDialog> {
  final formKey = GlobalKey<FormState>();
  final delta = TextEditingController();
  final reason = TextEditingController();
  late bool isWaste = widget.batches.isNotEmpty;
  bool busy = false;
  Object? error;
  String? operationKey;
  String? previousPayload;

  String newOperationKey() => List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  Future<void> submit() async {
    if (busy || formKey.currentState?.validate() != true) return;
    final command = AdjustmentCommand(parsePersianInteger(delta.text)!, reason.text.trim(), isWaste: isWaste, batchCode: batchCode);
    final payload = jsonEncode([command.delta, command.reason, command.isWaste, command.batchCode]);
    if (operationKey == null || payload != previousPayload) operationKey = newOperationKey();
    previousPayload = payload;
    setState(() { busy = true; error = null; });
    try {
      await widget.onSubmit?.call(command, operationKey!);
      if (mounted) Navigator.pop(context, command);
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? batchCode;

  InventoryBatch? get selectedBatch {
    for (final batch in widget.batches) {
      if (batch.batchCode == batchCode) return batch;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('انصراف')),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'در حال ثبت…' : isWaste ? 'ثبت ضایعات' : 'ثبت اصلاح'),
      ),
    ];
    final textScale = MediaQuery.textScalerOf(context).scale(14);
    final useStackedActions = MediaQuery.sizeOf(context).width < 480 || textScale > 16;
    return PopScope(canPop: !busy, child: AlertDialog(
      title: Text(isWaste ? 'ثبت ضایعات ${widget.variant.sku}' : 'اصلاح موجودی ${widget.variant.sku}'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.batches.isNotEmpty) const Text('این کالا بچ دارد؛ ورود را با ثبت خرید و خروج را با انتخاب بچ ضایعاتی ثبت کنید.'),
            if (error != null) Semantics(liveRegion: true, child: Text(requestErrorMessage(error!), style: TextStyle(color: Theme.of(context).colorScheme.error))),
            Text('موجودی فعلی: ${formatPersianInteger(widget.variant.availablePackages)} بسته'),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool>(
              initialValue: isWaste,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع عملیات'),
              items: [
                DropdownMenuItem(
                  value: false,
                  enabled: widget.batches.isEmpty,
                  child: const Text('اصلاح دستی موجودی', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const DropdownMenuItem(
                  value: true,
                  child: Text('ثبت ضایعات', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (value) {
                if (value == true && widget.batches.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('برای ثبت ضایعات، ابتدا یک بچ با ماندهٔ موجود انتخاب یا ثبت کنید.')));
                  return;
                }
                setState(() => isWaste = value ?? false);
              },
            ),
            if (isWaste) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: batchCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'بچ ضایعاتی'),
                items: [
                  for (final batch in widget.batches)
                    DropdownMenuItem(value: batch.batchCode, child: Text('${batch.batchCode} · مانده ${formatPersianInteger(batch.remainingPackages)} بسته')),
                ],
                onChanged: (value) => setState(() => batchCode = value),
                validator: (value) => value == null ? 'بچ ضایعاتی را انتخاب کنید.' : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: delta,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isWaste ? 'تعداد بستهٔ ضایعاتی' : 'تغییر موجودی',
                hintText: isWaste ? 'تعداد بسته‌های غیرقابل‌فروش' : 'مثبت برای ورود، منفی برای خروج',
              ),
              validator: (value) {
                final batchRemaining = selectedBatch?.remainingPackages ?? 0;
                final maximum = isWaste && batchRemaining < maxInventoryAdjustment
                    ? batchRemaining
                    : maxInventoryAdjustment;
                final amount = parsePersianInteger(
                  value,
                  min: isWaste ? 1 : -maxInventoryAdjustment,
                  max: maximum,
                );
                if (amount == null) return 'عدد معتبر وارد کنید.';
                if (isWaste && amount <= 0) return 'تعداد ضایعات باید بیشتر از صفر باشد.';
                if (isWaste && selectedBatch == null) return 'بچ ضایعاتی را انتخاب کنید.';
                if (isWaste && selectedBatch != null && amount > selectedBatch!.remainingPackages) return 'تعداد از ماندهٔ بچ بیشتر است.';
                if (!isWaste && amount == 0) return 'مقدار تغییر نمی‌تواند صفر باشد.';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'علت اصلاح یا ضایعات', counterText: ''),
              maxLength: 500,
              validator: (value) => value == null || value.trim().isEmpty ? 'علت را وارد کنید.' : value.trim().length > 500 ? 'علت حداکثر ۵۰۰ نویسه است.' : null,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: reason,
              builder: (context, value, child) => Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  '${formatPersianInteger(value.text.length)} / ۵۰۰ نویسه',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ])),
        ),
      ),
      actions: useStackedActions
          ? [
              SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: actions,
                ),
              ),
            ]
          : actions,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
    ));
  }

  @override
  void dispose() {
    delta.dispose();
    reason.dispose();
    super.dispose();
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
