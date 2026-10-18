import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'admin_state.dart';
import 'admin_step_up_dialog.dart';
import 'admin_theme.dart';
import 'admin_table.dart';
import 'admin_permissions.dart';
import 'admin_navigation.dart';
import 'auth_session.dart';
import 'catalog_api.dart';
import 'edit_product_dialog.dart';
import 'formatters.dart';
import 'media_api.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, this.api, this.onNavigate});
  final CatalogApiClient? api;
  final ValueChanged<AdminNavigationIntent>? onNavigate;

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
    final session = OwnerSession.instance;
    if (!session.can(AdminPermissions.productsWrite)) return;
    if (!session.can(AdminPermissions.pricingWrite)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('برای ثبت محصول و قیمت اولیه، دسترسی قیمت‌گذاری لازم است.'),
      ));
      return;
    }
    final command = await showDialog<CreateProductCommand>(context: context, builder: (_) => ProductDialog(
      mediaApi: MediaApiClient(),
      categories: categories,
      canWriteCosts: OwnerSession.instance.can(AdminPermissions.pricingWrite),
    ));
    if (command == null || !mounted) return;
    final stepUpToken = await showAdminStepUpDialog(context);
    if (stepUpToken == null || !mounted) return;
    try {
      await api.createProduct(command, stepUpToken: stepUpToken);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('محصول به‌صورت پیش‌نویس ثبت شد.')));
      }
    } catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.toString())));
    }
  }

  Future<void> editProduct(Product product) async {
    if (!OwnerSession.instance.can(AdminPermissions.productsWrite)) return;
    final command = await showDialog<UpdateProductCommand>(
      context: context,
      builder: (_) => ProductEditDialog(
        product: product,
        categories: categories,
      ),
    );
    if (command == null || !mounted) return;

    try {
      await api.updateProduct(product.slug, command);
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تغییرات محصول ذخیره شد.')),
        );
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(exception.toString())),
        );
      }
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
          LayoutBuilder(builder: (context, constraints) {
            final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('محصولات', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const Text('پیش‌نویس‌ها فقط در پنل دیده می‌شوند.', style: TextStyle(color: AdminColors.muted, fontSize: 11)),
            ]);
            final categoriesButton = OutlinedButton.icon(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => CategoryManagerDialog(api: api, initial: categories, onChanged: load),
                );
              },
              icon: const Icon(Icons.category_rounded),
              label: Text('دسته‌ها (${formatPersianInteger(categories.length)})'),
            );
            final draftsFilter = FilterChip(
              label: const Text('نمایش پیش‌نویس‌ها'),
              selected: showDrafts,
              onSelected: (value) => setState(() => showDrafts = value),
            );
            final refreshButton = IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'بارگذاری مجدد');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: title), refreshButton]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (OwnerSession.instance.can(AdminPermissions.productsWrite)) FilledButton.icon(onPressed: openCreateDialog, icon: const Icon(Icons.add_rounded), label: const Text('افزودن محصول')),
                categoriesButton, draftsFilter,
              ]),
            ]);
          }),
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
      if (constraints.maxWidth >= 900 && MediaQuery.textScalerOf(context).scale(1) < 1.5) {
        num minPrice(Product product) => product.variants.isEmpty ? 0 : product.variants.map((v) => v.price).reduce((a, b) => a < b ? a : b);
        return SingleChildScrollView(child: AdminRecordTable<Product>(
          records: visible, searchText: (p) => '${p.title} ${p.category} ${p.origin} ${p.variants.map((v) => v.sku).join(' ')}', searchHint: 'جست‌وجوی محصول…',
          columns: [
            AdminColumn('محصول', (p) => AdminIdentityCell(title: p.title, subtitle: p.origin,
              leading: ClipRRect(borderRadius: BorderRadius.circular(4), child: p.primaryImage.trim().isEmpty
                ? const SizedBox(width: 38, height: 38, child: Icon(Icons.inventory_2_outlined))
                : Image.network(resolveMediaUri(p.primaryImage).toString(), width: 38, height: 38, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 38, height: 38, child: Icon(Icons.image_not_supported_outlined))))), compare: (a, b) => a.title.compareTo(b.title)),
            AdminColumn('دسته‌بندی', (p) => Text(p.category), compare: (a, b) => a.category.compareTo(b.category)),
            AdminColumn('بسته‌ها', (p) => PopupMenuButton<String>(tooltip: 'نمایش سفارش‌های بسته', onSelected: (sku) => widget.onNavigate?.call(AdminNavigationIntent(module: AdminModule.orders, query: sku)),
              enabled: OwnerSession.instance.can(AdminPermissions.ordersRead), itemBuilder: (_) => [for (final v in p.variants) PopupMenuItem(value: v.sku, child: Text('${v.displayLabel} · ${v.sku}'))],
              child: Text('${formatPersianInteger(p.variants.length)} بسته', style: const TextStyle(color: AdminColors.primaryLight)))),
            AdminColumn('موجودی', (p) => AdminStatusBadge('${formatPersianInteger(p.totalStock)} بسته', color: p.totalStock > 0 ? AdminColors.success : AdminColors.coral, background: p.totalStock > 0 ? AdminColors.successSoft : AdminColors.dangerSoft), compare: (a, b) => a.totalStock.compareTo(b.totalStock)),
            AdminColumn('قیمت از (تومان)', (p) => Text(formatToman(minPrice(p))), compare: (a, b) => minPrice(a).compareTo(minPrice(b))),
            AdminColumn('وضعیت', (p) => _PublicationBadge(p.isPublished)),
            AdminColumn('عملیات', (p) => Row(mainAxisSize: MainAxisSize.min, children: [
              if (OwnerSession.instance.can(AdminPermissions.productsWrite)) IconButton(tooltip: 'ویرایش ${p.title}', onPressed: () => editProduct(p), icon: const Icon(Icons.edit_outlined, size: 20)),
              if (OwnerSession.instance.can(AdminPermissions.productsWrite)) IconButton(tooltip: p.isPublished ? 'خروج از فروش' : 'انتشار', onPressed: changingPublication.contains(p.slug) ? null : () => changePublication(p), icon: Icon(p.isPublished ? Icons.visibility_off_outlined : Icons.public_rounded, size: 20)),
            ])),
          ],
        ));
      }
      final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 650 ? 2 : 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: constraints.maxWidth < 1100 ? 350 : 285,
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
            onEdit: OwnerSession.instance.can(AdminPermissions.productsWrite)
                ? () => editProduct(product)
                : null,
            onVariantOrders: OwnerSession.instance.can(AdminPermissions.ordersRead)
                ? (sku) => widget.onNavigate?.call(AdminNavigationIntent(module: AdminModule.orders, query: sku))
                : null,
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
    this.onEdit,
    this.onVariantOrders,
  });

  final Product product;
  final bool publicationBusy;
  final VoidCallback onPublicationPressed;
  final VoidCallback? onEdit;
  final ValueChanged<String>? onVariantOrders;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: product.primaryImage.trim().isEmpty
                    ? Container(width: 58, height: 58, color: AdminColors.mintSoft, alignment: Alignment.center, child: Text(product.isWeight ? '⚖' : '●'))
                    : Image.network(resolveMediaUri(product.primaryImage).toString(), width: 58, height: 58, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Container(width: 58, height: 58, color: AdminColors.warningSoft, alignment: Alignment.center, child: const Icon(Icons.broken_image_outlined)))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(product.galleryImages.isEmpty ? 'یک تصویر ثبت شده' : '${formatPersianInteger(product.galleryImages.length + 1)} تصویر ثبت شده', style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
              ])),
              _PublicationBadge(product.isPublished),
            ]),
            const SizedBox(height: 8),
            Text('${product.category} · ${product.origin}', style: const TextStyle(color: AdminColors.muted, fontSize: 11)),
            const Spacer(),
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (final variant in product.variants)
                if (onVariantOrders != null)
                  ActionChip(
                    tooltip: 'نمایش سفارش‌های ${variant.displayLabel}',
                    onPressed: () => onVariantOrders!(variant.sku),
                    label: Text('${variant.displayLabel} · ${formatPersianInteger(variant.availablePackages)} بسته', style: const TextStyle(fontSize: 10)),
                  )
                else
                  Chip(label: Text('${variant.displayLabel} · ${formatPersianInteger(variant.availablePackages)} بسته', style: const TextStyle(fontSize: 10))),
            ]),
            const SizedBox(height: 8),
            Text(
              'موجودی کل: ${formatPersianInteger(product.totalStock)} بسته',
              style: const TextStyle(color: AdminColors.success, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('ویرایش'),
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
          color: isPublished ? AdminColors.successSoft : AdminColors.warningSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isPublished ? 'منتشرشده' : 'پیش‌نویس',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
}

class ProductDialog extends StatefulWidget {
  const ProductDialog({
    super.key,
    this.mediaApi,
    this.categories = const [],
    this.canWriteCosts = false,
  });
  final MediaApiClient? mediaApi;
  final List<Category> categories;
  final bool canWriteCosts;

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
  final quantity = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();
  String unitType = 'Weight';
  String category = 'آجیل و مغزها';
  bool uploadingImage = false;
  bool uploadingGallery = false;
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
      width: MediaQuery.sizeOf(context).width < 920
          ? MediaQuery.sizeOf(context).width - 64
          : 820,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('محصول ابتدا به‌صورت پیش‌نویس ذخیره می‌شود.'),
                  subtitle: Text(
                    'بعد از تکمیل اطلاعات، آن را جداگانه منتشر کنید.',
                  ),
                ),
                TextFormField(
                  controller: title,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'نام محصول'),
                  validator: required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: slug,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'شناسهٔ انگلیسی آدرس',
                    helperText:
                        'برای پیوند صفحهٔ محصول استفاده می‌شود؛ مثل premium-cookie.',
                  ),
                  validator: required,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                  items:
                      (widget.categories.isEmpty
                              ? const [
                                  'آجیل و مغزها',
                                  'میوه خشک',
                                  'لواشک و ترش‌مزه',
                                  'کوکی و شیرینی',
                                  'کم‌شکر و پروتئینی',
                                  'هدیه',
                                ]
                              : widget.categories
                                    .map((item) => item.name)
                                    .toList())
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => setState(() {
                    if (value != null) category = value;
                  }),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: origin,
                  decoration: const InputDecoration(labelText: 'مبدأ یا برند'),
                  validator: required,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: shortDescription,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'توضیح کوتاه',
                    helperText: 'یک جمله‌ی روشن برای کارت محصول و جست‌وجو.',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'توضیحات کامل',
                    helperText: 'مواد، طعم، روش نگهداری و نکات مهم مشتری.',
                  ),
                ),
                const SizedBox(height: 14),
                _formSection('تصاویر محصول', Icons.photo_library_outlined, [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: primaryImage,
                          keyboardType: TextInputType.url,
                          textDirection: TextDirection.ltr,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'تصویر اصلی',
                            hintText: 'پیوند تصویر یا بارگذاری فایل',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: uploadingImage ? null : pickImage,
                        icon: uploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.upload_file_rounded),
                        label: Text(
                          uploadingImage ? 'در حال آپلود' : 'انتخاب تصویر',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (mediaError != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        mediaError!,
                        style: const TextStyle(
                          color: AdminColors.coral,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  _productPreview(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: galleryImages,
                    minLines: 2,
                    maxLines: 4,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'پیوند تصاویر گالری (اختیاری)',
                      hintText: 'هر پیوند را در یک خط وارد کنید',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: uploadingGallery ? null : pickGalleryImages,
                      icon: uploadingGallery
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        uploadingGallery
                            ? 'در حال بارگذاری تصاویر…'
                            : 'بارگذاری تصاویر گالری',
                      ),
                    ),
                  ),
                  if (galleryImages.text.trim().isNotEmpty) _galleryPreview(),
                ]),
                const SizedBox(height: 14),
                _formSection('قیمت و موجودی', Icons.sell_outlined, [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Weight', label: Text('وزنی')),
                      ButtonSegment(value: 'Count', label: Text('عددی')),
                    ],
                    selected: {unitType},
                    onSelectionChanged: (value) => setState(() {
                      unitType = value.first;
                    }),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: const [PersianDigitsInputFormatter()],
                    decoration: InputDecoration(
                      labelText: unitType == 'Weight'
                          ? 'وزن هر بسته (گرم)'
                          : 'تعداد هر بسته',
                    ),
                    validator: quantityRequired,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: sku,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'کد انبار (SKU)',
                      helperText:
                          'کد یکتای بسته برای انبار و سفارش‌ها؛ مشتری آن را نمی‌بیند. نمونه: KOO-250',
                    ),
                    validator: required,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      PersianGroupedIntegerInputFormatter(),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'قیمت فروش (ریال)',
                    ),
                    validator: numberRequired,
                  ),
                  if (widget.canWriteCosts) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: costPrice,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [
                        PersianGroupedIntegerInputFormatter(),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'قیمت تمام‌شده (ریال)',
                        helperText:
                            'برای محاسبه سود و حاشیهٔ سود استفاده می‌شود.',
                      ),
                      validator: numberRequired,
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [
                      PersianGroupedIntegerInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'تعداد بستهٔ موجود',
                    ),
                    validator: stockRequired,
                  ),
                ]),
                const SizedBox(height: 12),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'اطلاعات SEO و مشخصات',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'اختیاری، اما برای دیده‌شدن محصول پیشنهاد می‌شود.',
                    style: TextStyle(fontSize: 11, color: AdminColors.muted),
                  ),
                  children: [
                    TextFormField(
                      controller: seoTitle,
                      decoration: const InputDecoration(labelText: 'عنوان SEO'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: seoDescription,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'توضیح SEO'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: seoKeywords,
                      decoration: const InputDecoration(
                        labelText: 'کلمات کلیدی',
                        hintText: 'مثلاً پسته، رفسنجان، شور',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: specifications,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'مشخصات ساختاریافته',
                        hintText: 'هر خط: کلید=مقدار',
                        helperText: 'مثلاً وزن خالص=۲۵۰ گرم',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(onPressed: submit, child: const Text('ذخیره پیش‌نویس')),
    ],
  );

  String? required(String? value) =>
      value == null || value.trim().isEmpty ? 'این فیلد الزامی است.' : null;
  String? numberRequired(String? value) =>
      parsePersianNumber(value) == null ? 'عدد معتبر وارد کنید.' : null;
  String? quantityRequired(String? value) {
    final parsed = parsePersianNumber(value);
    if (parsed == null || !parsed.isFinite || parsed <= 0)
      return 'مقدار هر بسته را وارد کنید.';
    if (unitType == 'Count' && parsed != parsed.roundToDouble())
      return 'تعداد هر بسته باید عدد صحیح باشد.';
    return null;
  }

  String? stockRequired(String? value) =>
      parsePersianInteger(value, min: 0, max: maxApiInteger) == null
      ? 'تعداد صحیح صفر یا بیشتر وارد کنید.'
      : null;

  Widget _formSection(String title, IconData icon, List<Widget> children) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: AdminColors.ink),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      );

  Widget _productPreview() {
    final image = primaryImage.text.trim();
    final parsedPrice = parsePersianInteger(price.text);
    return Card(
      color: AdminColors.canvas,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 96,
                child: image.isEmpty
                    ? const ColoredBox(
                        color: AdminColors.surface,
                        child: Icon(
                          Icons.image_outlined,
                          size: 34,
                          color: AdminColors.muted,
                        ),
                      )
                    : Image.network(
                        resolveMediaUri(image).toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: AdminColors.warningSoft,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AdminColors.muted,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'پیش‌نمایش کارت محصول',
                    style: TextStyle(fontSize: 11, color: AdminColors.muted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title.text.trim().isEmpty ? 'نام محصول' : title.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    parsedPrice == null
                        ? 'قیمت پس از ورود نمایش داده می‌شود'
                        : '${formatPersianInteger(parsedPrice)} ریال',
                    style: const TextStyle(
                      color: AdminColors.ink,
                      fontWeight: FontWeight.w700,
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

  Widget _galleryPreview() {
    final primary = primaryImage.text.trim().isEmpty
        ? null
        : resolveMediaUri(primaryImage.text).toString();
    final urls = galleryImages.text
        .split('\n')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty);
    final uniqueUrls = urls
        .map((value) => resolveMediaUri(value).toString())
        .where((value) => value != primary)
        .toSet();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
        for (final url in uniqueUrls)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                resolveMediaUri(url).toString(),
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72,
                  height: 72,
                  color: AdminColors.canvas,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, size: 20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    setState(() {
      uploadingImage = true;
      mediaError = null;
    });
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

  Future<void> pickGalleryImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      uploadingGallery = true;
      mediaError = null;
    });
    try {
      final uploadedUrls = <String>[];
      for (final file in result.files) {
        if (file.bytes == null)
          throw Exception('خواندن فایل ${file.name} ممکن نشد.');
        if (file.size > 8 * 1024 * 1024)
          throw Exception('حجم هر تصویر باید کمتر از ۸ مگابایت باشد.');
        final uploaded = await media.uploadImage(
          fileName: file.name,
          bytes: file.bytes!,
          contentType: _mimeFor(file.name),
        );
        uploadedUrls.add(uploaded.url);
      }
      if (mounted)
        setState(() {
          final existing = galleryImages.text
              .split('\n')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty);
          galleryImages.text = [...existing, ...uploadedUrls].join('\n');
        });
    } catch (exception) {
      if (mounted) setState(() => mediaError = exception.toString());
    } finally {
      if (mounted) setState(() => uploadingGallery = false);
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
    quantity.dispose();
    price.dispose();
    stock.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    final packageQuantity = parsePersianNumber(quantity.text)!;
    final label = unitType == 'Weight'
        ? '${formatPersianNumber(packageQuantity)} گرم'
        : '${formatPersianInteger(packageQuantity)} عدد';
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
            if (line.contains('='))
              line.split('=').first.trim(): line
                  .substring(line.indexOf('=') + 1)
                  .trim(),
        },
        unitType: unitType,
        isPublished: false,
        primaryImage: primaryImage.text.trim(),
        galleryImages: galleryImages.text
            .split('\n')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        variants: [
          CreateVariantCommand(
            sku: sku.text,
            quantity: packageQuantity,
            displayLabel: label,
            price: parsePersianNumber(price.text)!,
            costPrice: widget.canWriteCosts
                ? parsePersianNumber(costPrice.text)!
                : 0,
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
              inputFormatters: const [PersianGroupedIntegerInputFormatter()],
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

