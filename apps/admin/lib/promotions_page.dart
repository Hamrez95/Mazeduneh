import 'admin_table.dart';
import 'admin_theme.dart';
import 'admin_mobile_list_controls.dart';
import 'localized_calendar.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl, CatalogApiClient, Product;
import 'customer_api.dart' show CustomerApiClient, CustomerSummary;
import 'admin_step_up_dialog.dart';
import 'formatters.dart';
import 'admin_form_guard.dart';
import 'admin_form_drafts.dart';
import 'store_timezone.dart';

class PromotionsApiClient {
  PromotionsApiClient({http.Client? client, String? baseUrl})
    : client = client ?? http.Client(),
      baseUrl = baseUrl ?? defaultApiBaseUrl;
  final http.Client client;
  final String baseUrl;
  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    String? proof,
  }) async {
    final token = OwnerSession.instance.bearerToken;
    if (token == null)
      throw Exception('نشست شما منقضی شده است. دوباره وارد شوید.');
    final req = http.Request(
      method,
      Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/v1/admin/promotions$path',
      ),
    );
    req.headers.addAll({
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      if (proof != null) 'X-Admin-Step-Up': proof,
    });
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(await client.send(req));
    final result = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode == 401) OwnerSession.instance.clear();
    if (response.statusCode >= 400) {
      final errors = result is Map ? result['errors'] as Map? : null;
      throw Exception(
        errors != null
            ? errors.values.expand((v) => v as List).join(' ')
            : result['message'] ??
                  result['title'] ??
                  'درخواست انجام نشد؛ دوباره تلاش کنید.',
      );
    }
    return result;
  }
}

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key, this.api});
  final PromotionsApiClient? api;
  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  late final api = widget.api ?? PromotionsApiClient();
  List<dynamic>? rows;
  String? error;
  String promotionQuery = '';
  int promotionPage = 0;
  int promotionPageSize = 10;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      error = null;
    });
    try {
      final data = await api.send('GET', '');
      if (mounted)
        setState(() {
          rows = data as List;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
        });
    }
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PromotionEditor(api: api, item: item),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('کوپن ذخیره شد.')));
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    final allRows = (rows ?? const []).cast<Map<String, dynamic>>();
    final query = normalizeNumberDigits(promotionQuery.trim().toLowerCase());
    final filteredRows = allRows.where((row) {
      if (query.isEmpty) return true;
      final rule = row['rule'] as Map;
      return normalizeNumberDigits(
        '${row['code']} ${rule['name']}'.toLowerCase(),
      ).contains(query);
    }).toList();
    final lastPage = filteredRows.isEmpty
        ? 0
        : (filteredRows.length - 1) ~/ promotionPageSize;
    final currentPage = promotionPage.clamp(0, lastPage);
    final pageRows = filteredRows
        .skip(currentPage * promotionPageSize)
        .take(promotionPageSize)
        .toList();
    return ListView(
      padding: MediaQuery.sizeOf(context).width < 600
          ? const EdgeInsets.all(16)
          : const EdgeInsets.all(28),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 12,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'کوپن و تخفیف',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                Text('قیمت نهایی و محدودیت مصرف در سرور کنترل می‌شوند.'),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 8,
              children: [
                IconButton(
                  tooltip: 'تازه‌سازی کوپن‌ها',
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                ),
                if (OwnerSession.instance.can('pricing.write'))
                  FilledButton.icon(
                    onPressed: () => edit(),
                    icon: const Icon(Icons.add),
                    label: const Text('کوپن جدید'),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'درصدی، مبلغ ثابت یا ارسال رایگان بسازید؛ زمان و سقف مصرف را مشخص کنید و با یک SKU نمونه اثر تخفیف بر سود را ببینید. پک، خرید و هدیه، دامنهٔ مشتری/شهر/دسته و کمپین خودکار هم قابل تنظیم‌اند. هر سفارش یک تخفیف دارد. مبالغ فرم به تومان هستند.',
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error!,
              semanticsLabel: 'خطا: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        if (rows == null && error == null)
          const Center(child: CircularProgressIndicator()),
        if (rows?.isEmpty == true)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Text(
              'هنوز کوپنی نساخته‌اید. با «کوپن جدید» اولین تخفیف را آماده کنید.',
            ),
          ),
        if (rows?.isNotEmpty == true && !wide)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminMobileListControls(
              totalItems: filteredRows.length,
              page: currentPage,
              pageSize: promotionPageSize,
              searchText: promotionQuery,
              searchHint: 'جست‌وجوی نام کمپین یا کد',
              onSearchChanged: (value) => setState(() {
                promotionQuery = value;
                promotionPage = 0;
              }),
              onPageChanged: (value) => setState(() => promotionPage = value),
              onPageSizeChanged: (value) => setState(() {
                promotionPageSize = value;
                promotionPage = 0;
              }),
            ),
          ),
        if (rows?.isNotEmpty == true && wide)
          AdminRecordTable<Map<String, dynamic>>(
            records: rows!.cast<Map<String, dynamic>>(),
            searchText: (r) => "${r['code']} ${(r['rule'] as Map)['name']}",
            searchHint: 'جست‌وجوی کمپین یا کوپن…',
            columns: [
              AdminColumn(
                'کمپین',
                (r) => AdminIdentityCell(
                  title: (r['rule'] as Map)['name'] as String,
                  subtitle: r['code'] as String,
                  leading: const CircleAvatar(
                    backgroundColor: AdminColors.primarySoft,
                    child: Icon(
                      Icons.local_offer_outlined,
                      color: AdminColors.primaryLight,
                      size: 20,
                    ),
                  ),
                ),
              ),
              AdminColumn(
                'نوع',
                (r) => Text(_kindLabel((r['rule'] as Map)['kind'] as String)),
              ),
              AdminColumn(
                'اجرا',
                (r) => AdminStatusBadge(
                  (r['rule'] as Map)['automatic'] == true
                      ? 'خودکار'
                      : 'کد تخفیف',
                ),
              ),
              AdminColumn(
                'وضعیت',
                (r) => AdminStatusBadge(
                  _promotionState(r),
                  color: _promotionState(r) == 'فعال'
                      ? AdminColors.success
                      : AdminColors.amber,
                  background: _promotionState(r) == 'فعال'
                      ? AdminColors.successSoft
                      : AdminColors.warningSoft,
                ),
              ),
              AdminColumn(
                'مصرف',
                (r) => Text(formatPersianInteger(r['uses'] as num)),
                compare: (a, b) =>
                    (a['uses'] as num).compareTo(b['uses'] as num),
              ),
              AdminColumn(
                'تخفیف (تومان)',
                (r) => Text(formatToman(r['discountTotal'] as num)),
                compare: (a, b) => (a['discountTotal'] as num).compareTo(
                  b['discountTotal'] as num,
                ),
              ),
              AdminColumn(
                'فروش (تومان)',
                (r) => Text(formatToman(r['revenue'] as num? ?? 0)),
              ),
              AdminColumn(
                'عملیات',
                (r) => IconButton(
                  tooltip: "ویرایش ${r['code']}",
                  onPressed:
                      OwnerSession.instance.can('pricing.write') &&
                          r['customerScopeHidden'] != true
                      ? () => edit(r)
                      : null,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
              ),
            ],
          )
        else if (filteredRows.isEmpty && allRows.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('کمپینی با این جست‌وجو پیدا نشد.'),
          )
        else if (!wide)
          for (final row in pageRows)
            Builder(
              builder: (context) {
                final rule = row['rule'] as Map<String, dynamic>;
                final start = storeUtcToWallTime(DateTime.parse(rule['startsAt'] as String));
                final end = storeUtcToWallTime(DateTime.parse(rule['endsAt'] as String));
                final now = storeWallTimeNow();
                final state = rule['active'] != true
                    ? 'غیرفعال'
                    : now.isBefore(start)
                    ? 'زمان‌بندی‌شده'
                    : !now.isBefore(end)
                    ? 'پایان‌یافته'
                    : 'فعال';
                return Card(
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.sizeOf(context).width < 380
                          ? 12
                          : 20,
                      vertical: 12,
                    ),
                    title: Text(
                      '${rule['name']} · ${row['code']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$state • مصرف: ${formatPersianInteger(row['uses'] as num)} از ${rule['maxUses'] == null ? 'نامحدود' : formatPersianInteger(rule['maxUses'] as num)}\nپرداخت‌شده: ${formatPersianInteger(row['paidOrders'] as num? ?? 0)} سفارش • تخفیف: ${formatToman(row['discountTotal'] as num)} تومان\nفروش پرداخت‌شده: ${formatToman(row['revenue'] as num? ?? 0)} تومان${rule['automatic'] == true ? ' • خودکار' : ''}',
                    ),
                    isThreeLine: true,
                    trailing:
                        OwnerSession.instance.can('pricing.write') &&
                            row['customerScopeHidden'] != true
                        ? IconButton(
                            tooltip: 'ویرایش ${row['code']}',
                            onPressed: () => edit(row),
                            icon: const Icon(Icons.edit_outlined),
                          )
                        : null,
                  ),
                );
              },
            ),
      ],
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
  'Percent' => 'درصدی',
  'Fixed' => 'مبلغ ثابت',
  'FreeShipping' => 'ارسال رایگان',
  'Bundle' => 'پک',
  'BuyGet' => 'خرید و هدیه',
  _ => kind,
};
String _promotionState(Map<String, dynamic> row) {
  final rule = row['rule'] as Map;
  final now = storeWallTimeNow();
  if (rule['active'] != true) return 'غیرفعال';
  if (now.isBefore(storeUtcToWallTime(DateTime.parse(rule['startsAt'] as String))))
    return 'زمان‌بندی‌شده';
  if (!now.isBefore(storeUtcToWallTime(DateTime.parse(rule['endsAt'] as String))))
    return 'پایان‌یافته';
  return 'فعال';
}

class _PromotionEditor extends StatefulWidget {
  const _PromotionEditor({required this.api, this.item});
  final PromotionsApiClient api;
  final Map<String, dynamic>? item;
  @override
  State<_PromotionEditor> createState() => _PromotionEditorState();
}

class _PromotionEditorState extends State<_PromotionEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  var kind = 'Percent';
  var active = false;
  var allowLoss = false;
  var automatic = false;
  var firstOrderOnly = false;
  var busy = false;
  String? error;
  Map<String, dynamic>? preview;
  List<Product> products = const [];
  List<CustomerSummary> customers = const [];
  final sampleBasket = <Map<String, dynamic>>[];
  final bundleBasket = <Map<String, dynamic>>[];
  bool loadingChoices = false;
  bool _dirty = false;
  bool _closing = false;
  bool _initializing = true;
  bool _restoredDraft = false;
  String get _draftId => widget.item?['code'] as String? ?? 'new';
  late DateTime startsAt;
  late DateTime endsAt;
  TextEditingController field(String name) => fields.putIfAbsent(name, () {
    final controller = TextEditingController()..addListener(_markDirty);
    return controller;
  });

  void _markDirty() {
    if (!mounted || _initializing || _closing) return;
    if (!_dirty) setState(() => _dirty = true);
    _persistDraft();
  }

  void _persistDraft() => writeAdminFormDraft('promotion', _draftId, {
    for (final entry in fields.entries) entry.key: entry.value.text,
    'kind': kind,
    'active': active,
    'allowLoss': allowLoss,
    'automatic': automatic,
    'firstOrderOnly': firstOrderOnly,
    'startsAt': startsAt.toIso8601String(),
    'endsAt': endsAt.toIso8601String(),
    'bundleBasket': bundleBasket,
  });

  Future<void> _requestClose() async {
    if (_dirty && !await confirmDiscardAdminChanges(context)) return;
    if (!mounted) return;
    clearAdminFormDraft('promotion', _draftId);
    setState(() => _closing = true);
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _loadChoices();
    final rule = widget.item?['rule'] as Map<String, dynamic>?;
    kind = rule?['kind'] as String? ?? 'Percent';
    active = rule?['active'] == true;
    allowLoss = rule?['allowLoss'] == true;
    field('code').text = widget.item?['code'] as String? ?? '';
    field('name').text = rule?['name'] as String? ?? '';
    final promotionValue =
        (rule?['value'] as num? ?? 10) / (kind == 'Fixed' ? 10 : 1);
    field('value').text = kind == 'Fixed'
        ? formatToman(rule?['value'] as num? ?? 0)
        : toPersianDigits(promotionValue);
    field('min').text = formatToman(rule?['minSubtotal'] as num? ?? 0);
    field('max').text = rule?['maxDiscount'] == null
        ? ''
        : formatToman(rule!['maxDiscount'] as num);
    field('uses').text = toPersianDigits(rule?['maxUses'] ?? '');
    field('skus').text = (rule?['skus'] as List? ?? []).join(', ');
    final parsedStart = DateTime.tryParse(rule?['startsAt'] as String? ?? '');
    final parsedEnd = DateTime.tryParse(rule?['endsAt'] as String? ?? '');
    startsAt = parsedStart == null
        ? storeWallTimeNow().subtract(const Duration(minutes: 1))
        : storeUtcToWallTime(parsedStart);
    endsAt = parsedEnd == null
        ? storeWallTimeNow().add(const Duration(days: 30))
        : storeUtcToWallTime(parsedEnd);
    field('quantity').text = '۱';
    field('shipping').text = 'post';
    automatic = rule?['automatic'] == true;
    firstOrderOnly = rule?['firstOrderOnly'] == true;
    for (final key in [
      'categories',
      'cities',
      'customerMobiles',
      'rewardSkus',
    ]) {
      field(key).text = (rule?[key] as List? ?? []).join(', ');
    }
    field('perCustomer').text = '${rule?['maxUsesPerCustomer'] ?? ''}';
    field('priority').text = '${rule?['priority'] ?? 0}';
    field('buy').text = '${rule?['buyQuantity'] ?? 1}';
    field('get').text = '${rule?['getQuantity'] ?? 1}';
    field('applications').text = '${rule?['maxApplications'] ?? ''}';
    field('bundlePrice').text = rule?['bundlePrice'] == null
        ? ''
        : formatToman(rule!['bundlePrice'] as num);
    bundleBasket.addAll(
      (rule?['bundleItems'] as List? ?? []).map(
        (item) => {
          'sku': item['sku'] as String,
          'quantity': (item['quantity'] as num).toInt(),
        },
      ),
    );
    field('bundleQuantity').text = '۱';
    final draft = readAdminFormDraft('promotion', _draftId);
    if (draft != null) {
      _restoredDraft = true;
      _dirty = true;
      for (final entry in draft.entries) {
        if (entry.value is String) field(entry.key).text = entry.value as String;
      }
      const kinds = {'Percent', 'Fixed', 'FreeShipping', 'BuyGet', 'Bundle'};
      if (draft['kind'] is String && kinds.contains(draft['kind'])) kind = draft['kind'] as String;
      if (draft['active'] is bool) active = draft['active'] as bool;
      if (draft['allowLoss'] is bool) allowLoss = draft['allowLoss'] as bool;
      if (draft['automatic'] is bool) automatic = draft['automatic'] as bool;
      if (draft['firstOrderOnly'] is bool) firstOrderOnly = draft['firstOrderOnly'] as bool;
      startsAt = DateTime.tryParse(draft['startsAt'] as String? ?? '') ?? startsAt;
      endsAt = DateTime.tryParse(draft['endsAt'] as String? ?? '') ?? endsAt;
      final savedBundle = draft['bundleBasket'];
      if (savedBundle is List) {
        bundleBasket.addAll(savedBundle.whereType<Map>().where((line) => line['sku'] is String && line['quantity'] is int).map((line) => {'sku': line['sku'] as String, 'quantity': line['quantity'] as int}));
      }
    }
    _initializing = false;
  }

  Future<void> _loadChoices() async {
    loadingChoices = true;
    try {
      final requests = <Future<dynamic>>[
        CatalogApiClient(
          client: widget.api.client,
          baseUrl: widget.api.baseUrl,
        ).fetchProducts(includeDrafts: true),
        if (OwnerSession.instance.can('customers.pii.read'))
          CustomerApiClient(
            client: widget.api.client,
            baseUrl: widget.api.baseUrl,
          ).fetchCustomers(limit: 200),
      ];
      final result = await Future.wait(requests);
      if (!mounted) return;
      setState(() {
        products = result[0] as List<Product>;
        customers = result.length > 1
            ? result[1] as List<CustomerSummary>
            : const [];
      });
    } catch (_) {
      // Keep current saved values editable if choice data is temporarily unavailable.
    } finally {
      if (mounted) setState(() => loadingChoices = false);
    }
  }

  List<({String value, String label})> get skuChoices => [
    for (final product in products)
      for (final variant in product.variants)
        (
          value: variant.sku,
          label: '${product.title} · ${variant.displayLabel} · ${variant.sku}',
        ),
  ];

  List<({String value, String label})> get categoryChoices => [
    for (final value
        in products.map((product) => product.category).toSet().toList()..sort())
      (value: value, label: value),
  ];

  List<({String value, String label})> get cityChoices {
    final cities = <String>{};
    for (final customer in customers) {
      for (final address in customer.addresses) {
        if (address.city.trim().isNotEmpty) cities.add(address.city.trim());
      }
    }
    return [
      for (final city in cities.toList()..sort()) (value: city, label: city),
    ];
  }

  List<({String value, String label})> get customerChoices => [
    for (final customer in customers.where(
      (customer) => customer.mobile.trim().isNotEmpty,
    ))
      (
        value: customer.mobile,
        label: '${customer.fullName} · ${customer.mobile}',
      ),
  ];

  double get editorFieldWidth =>
      math.min(330, math.max(160, MediaQuery.sizeOf(context).width - 150));

  Widget selection(
    String key,
    String label,
    List<({String value, String label})> choices,
  ) => SizedBox(
    width: editorFieldWidth,
    child: _MultiSelectField(
      label: label,
      choices: choices,
      selected: csv(key),
      loading: loadingChoices,
      onChanged: (values) => setState(() {
        field(key).text = values.join(', ');
        preview = null;
      }),
    ),
  );

  void addSampleLine() {
    final sku = field('sku').text.trim();
    final count = number('quantity');
    if (sku.isEmpty || count < 1 || count != count.toInt()) return;
    setState(() {
      final index = sampleBasket.indexWhere((line) => line['sku'] == sku);
      if (index >= 0) {
        sampleBasket[index] = {
          ...sampleBasket[index],
          'quantity': (sampleBasket[index]['quantity'] as int) + count.toInt(),
        };
      } else {
        sampleBasket.add({'sku': sku, 'quantity': count.toInt()});
      }
      preview = null;
    });
    _markDirty();
  }

  void addBundleLine() {
    final sku = field('bundleSku').text.trim();
    final count = number('bundleQuantity');
    if (sku.isEmpty || count < 1 || count != count.toInt()) return;
    setState(() {
      final index = bundleBasket.indexWhere((line) => line['sku'] == sku);
      if (index >= 0) {
        bundleBasket[index] = {
          ...bundleBasket[index],
          'quantity': (bundleBasket[index]['quantity'] as int) + count.toInt(),
        };
      } else {
        bundleBasket.add({'sku': sku, 'quantity': count.toInt()});
      }
      preview = null;
    });
    _markDirty();
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  num number(String key) =>
      num.tryParse(normalizeNumberDigits(field(key).text)) ?? 0;
  List<String> csv(String key) => field(key).text
      .replaceAll('،', ',')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  Map<String, dynamic> rule() => {
    'name': field('name').text.trim(),
    'kind': kind,
    'value': !['Percent', 'Fixed'].contains(kind)
        ? 0
        : number('value') * (kind == 'Fixed' ? 10 : 1),
    'active': active,
    'startsAt': storeWallTimeToUtc(startsAt).toIso8601String(),
    'endsAt': storeWallTimeToUtc(endsAt).toIso8601String(),
    'minSubtotal': number('min') * 10,
    'maxDiscount': field('max').text.trim().isEmpty ? null : number('max') * 10,
    'maxUses': field('uses').text.trim().isEmpty
        ? null
        : number('uses').toInt(),
    'skus': kind == 'Bundle' ? [] : csv('skus'),
    'allowLoss': allowLoss,
    'automatic': automatic,
    'priority': number('priority').toInt(),
    'combinationPolicy': 'Exclusive',
    'categories': kind == 'Bundle' ? [] : csv('categories'),
    'cities': csv('cities'),
    'customerMobiles': csv('customerMobiles'),
    'firstOrderOnly': firstOrderOnly,
    'maxUsesPerCustomer': field('perCustomer').text.trim().isEmpty
        ? null
        : number('perCustomer').toInt(),
    'buyQuantity': number('buy').toInt(),
    'getQuantity': number('get').toInt(),
    'rewardSkus': csv('rewardSkus'),
    'maxApplications': field('applications').text.trim().isEmpty
        ? null
        : number('applications').toInt(),
    'bundleItems': kind == 'Bundle' ? bundleBasket : null,
    'bundlePrice': kind == 'Bundle' ? number('bundlePrice') * 10 : null,
  };
  Future<void> run(bool save) async {
    if (form.currentState?.validate() != true) return;
    if (!endsAt.isAfter(startsAt)) {
      setState(() => error = 'زمان پایان باید بعد از زمان شروع باشد.');
      return;
    }
    if (save && kind == 'Bundle' && bundleBasket.isEmpty) {
      setState(() => error = 'برای این پک حداقل یک کالا انتخاب کنید.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final payload = rule();
      if (save) {
        final proof = await showAdminStepUpDialog(context);
        if (proof == null) return;
        await widget.api.send(
          'PUT',
          '/${Uri.encodeComponent(field('code').text.trim().toUpperCase())}',
          body: payload,
          proof: proof,
        );
        if (mounted) {
          clearAdminFormDraft('promotion', _draftId);
          _closing = true;
          Navigator.pop(context, true);
        }
      } else {
        final quantity = number('quantity');
        if ((sampleBasket.isEmpty && field('sku').text.trim().isEmpty) ||
            quantity < 1 ||
            quantity != quantity.toInt())
          throw Exception('یک کالا و تعداد را به سبد نمونه اضافه کنید.');
        final result = await widget.api.send(
          'POST',
          '/preview',
          body: {
            'rule': payload,
            'lines': sampleBasket.isNotEmpty
                ? sampleBasket
                : [
                    {
                      'sku': field('sku').text.trim(),
                      'quantity': quantity.toInt(),
                    },
                  ],
            'mobile': field('sampleMobile').text.trim(),
            'city': field('sampleCity').text.trim(),
            'shippingMethod': field('shipping').text.trim(),
          },
        );
        if (mounted)
          setState(() {
            preview = result as Map<String, dynamic>;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
        });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
        });
    }
  }

  Widget input(
    String key,
    String label, {
    bool required = false,
    bool date = false,
  }) => SizedBox(
    width: editorFieldWidth,
    child: TextFormField(
      controller: field(key),
      onChanged: (_) {
        if (preview != null)
          setState(() {
            preview = null;
          });
      },
      enabled: !busy && !(key == 'code' && widget.item != null),
      inputFormatters: [
        if (date)
          const PersianDigitsInputFormatter()
        else if ([
          'value',
          'min',
          'max',
          'uses',
          'quantity',
          'perCustomer',
          'priority',
          'buy',
          'get',
          'applications',
          'bundlePrice',
        ].contains(key))
          if (key == 'value' && kind == 'Fixed' ||
              ['min', 'max', 'bundlePrice'].contains(key))
            const PersianGroupedIntegerInputFormatter()
          else
            const PersianDigitsInputFormatter(),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (required && (value?.trim().isEmpty ?? true))
          return 'این فیلد را کامل کنید.';
        if ([
              'value',
              'min',
              'max',
              'uses',
              'quantity',
              'perCustomer',
              'priority',
              'buy',
              'get',
              'applications',
              'bundlePrice',
            ].contains(key) &&
            (value?.trim().isNotEmpty ?? false)) {
          final n = num.tryParse(normalizeNumberDigits(value!));
          if (n == null ||
              !n.isFinite ||
              n < 0 ||
              ([
                    'uses',
                    'quantity',
                    'perCustomer',
                    'priority',
                    'buy',
                    'get',
                    'applications',
                  ].contains(key) &&
                  n != n.toInt()))
            return 'عدد معتبر وارد کنید.';
        }
        if (date &&
            DateTime.tryParse(normalizeNumberDigits(value ?? '')) == null)
          return 'مثال: 2026-10-17 14:30';
        return null;
      },
    ),
  );

  Future<void> _pickPromotionDateTime({required bool isStart}) async {
    final current = isStart ? startsAt : endsAt;
    final selectedDate = await showLocalizedDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart ? 'تاریخ شروع کمپین' : 'تاریخ پایان کمپین',
    );
    if (selectedDate == null || !mounted) return;
    final selectedTime = await showLocalizedTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      helpText: isStart ? 'ساعت شروع کمپین' : 'ساعت پایان کمپین',
    );
    if (selectedTime == null || !mounted) return;
    final value = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    setState(() {
      if (isStart) {
        startsAt = value;
      } else {
        endsAt = value;
      }
      preview = null;
      error = null;
    });
    _markDirty();
  }

  Widget _dateTimeField({required bool isStart}) => SizedBox(
    width: editorFieldWidth,
    child: OutlinedButton.icon(
      key: ValueKey(isStart ? 'promotion-start-date' : 'promotion-end-date'),
      onPressed: busy ? null : () => _pickPromotionDateTime(isStart: isStart),
      icon: const Icon(Icons.calendar_month_outlined),
      label: Text(
        '${isStart ? 'شروع کمپین' : 'پایان کمپین'}\n${formatLocalizedStoreWallDateTime(context, isStart ? startsAt : endsAt)}',
        textAlign: TextAlign.start,
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        alignment: AlignmentDirectional.centerStart,
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_dirty || _closing,
    onPopInvokedWithResult: (didPop, _) { if (!didPop) _requestClose(); },
    child: AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    title: Text(widget.item == null ? 'کوپن جدید' : 'ویرایش کوپن'),
    content: SizedBox(
      width: math.min(730, MediaQuery.sizeOf(context).width - 80),
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_restoredDraft)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.restore_rounded),
                    title: Text('پیش‌نویس قبلی بازیابی شد.'),
                    subtitle: Text('شماره تماس و شهر سبد نمونه یا اطلاعات مشتری در مرورگر ذخیره نمی‌شود.'),
                  ),
                ),
              Wrap(
                spacing: 16,
                runSpacing: 18,
                children: [
                  input('code', 'کد انگلیسی؛ مثل WELCOME10', required: true),
                  input('name', 'نام کوپن', required: true),
                  SizedBox(
                    width: editorFieldWidth,
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('promotion-kind'),
                      initialValue: kind,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'نوع تخفیف'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Percent',
                          child: Text('درصدی'),
                        ),
                        DropdownMenuItem(
                          value: 'Fixed',
                          child: Text('مبلغ ثابت'),
                        ),
                        DropdownMenuItem(
                          value: 'FreeShipping',
                          child: Text('ارسال رایگان'),
                        ),
                        DropdownMenuItem(
                          value: 'BuyGet',
                          child: Text('خرید X و هدیه Y'),
                        ),
                        DropdownMenuItem(
                          value: 'Bundle',
                          child: Text('پک با قیمت مشخص'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              kind = v!;
                              preview = null;
                              _dirty = true;
                              _persistDraft();
                            }),
                    ),
                  ),
                  if (['Percent', 'Fixed'].contains(kind))
                    input(
                      'value',
                      kind == 'Percent' ? 'درصد تخفیف' : 'مبلغ تخفیف (تومان)',
                      required: true,
                    ),
                  input('min', 'حداقل سبد (تومان)'),
                  input('max', 'سقف تخفیف (تومان؛ اختیاری)'),
                  input('uses', 'سقف تعداد مصرف (اختیاری)'),
                  if (kind != 'Bundle')
                    selection('skus', 'کالاهای مشمول', skuChoices),
                  if (kind == 'BuyGet') ...[
                    input('buy', 'تعداد خرید X', required: true),
                    input('get', 'تعداد هدیه Y', required: true),
                    selection(
                      'rewardSkus',
                      'کالاهای هدیه؛ خالی یعنی کالاهای خرید',
                      skuChoices,
                    ),
                  ],
                  if (kind == 'Bundle') ...[
                    SizedBox(
                      width: editorFieldWidth,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('bundle-sku-${field('bundleSku').text}'),
                        initialValue:
                            skuChoices.any(
                              (item) => item.value == field('bundleSku').text,
                            )
                            ? field('bundleSku').text
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'کالای داخل پک',
                        ),
                        items: [
                          for (final option in skuChoices)
                            DropdownMenuItem(
                              value: option.value,
                              child: Text(
                                option.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(() {
                                field('bundleSku').text = value ?? '';
                                preview = null;
                                _dirty = true;
                                _persistDraft();
                              }),
                      ),
                    ),
                    input(
                      'bundleQuantity',
                      'تعداد این کالا در پک',
                      required: true,
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : addBundleLine,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('افزودن کالا به پک'),
                    ),
                    if (bundleBasket.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final line in bundleBasket)
                            InputChip(
                              label: Text(
                                '${_choiceLabel(skuChoices, line['sku'] as String)} · ${formatPersianInteger(line['quantity'] as int)} بسته',
                              ),
                              onDeleted: busy
                                  ? null
                                  : () => setState(() {
                                      bundleBasket.remove(line);
                                      preview = null;
                                      _dirty = true;
                                      _persistDraft();
                                    }),
                            ),
                        ],
                      ),
                    input(
                      'bundlePrice',
                      'قیمت نهایی یک پک (تومان)',
                      required: true,
                    ),
                  ],
                  if (['BuyGet', 'Bundle'].contains(kind))
                    input('applications', 'سقف تکرار پیشنهاد در هر سفارش'),
                  _dateTimeField(isStart: true),
                  _dateTimeField(isStart: false),
                ],
              ),
              SwitchListTile(
                title: const Text('فعال یا زمان‌بندی‌شده'),
                value: active,
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        active = v;
                        _dirty = true;
                        _persistDraft();
                      }),
              ),
              ExpansionTile(
                title: const Text('دامنه، مشتری و انتخاب کمپین'),
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'هر سفارش یک تخفیف دارد. کد واردشده مقدم است؛ بدون کد، بالاترین اولویت و سپس بیشترین تخفیف انتخاب می‌شود. هدیه باید در سبد باشد و موجودی آن رزرو می‌شود. محدودیت مشتری بر اساس شمارهٔ تماس سفارش مهمان است و جای تأیید هویت نیست.',
                    ),
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      if (kind != 'Bundle')
                        selection(
                          'categories',
                          'دسته‌های کالا؛ اختیاری',
                          categoryChoices,
                        ),
                      selection('cities', 'شهرهای مجاز؛ اختیاری', cityChoices),
                      if (OwnerSession.instance.can('customers.pii.read'))
                        selection(
                          'customerMobiles',
                          'مشتری‌های مجاز',
                          customerChoices,
                        ),
                      input('perCustomer', 'سقف مصرف هر مشتری؛ اختیاری'),
                      input('priority', 'اولویت کمپین؛ ۰ تا ۱۰۰۰'),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('اعمال خودکار بدون نیاز به کد'),
                    value: automatic,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            automatic = v;
                            preview = null;
                            _dirty = true;
                            _persistDraft();
                          }),
                  ),
                  SwitchListTile(
                    title: const Text('فقط اولین سفارش این شماره تماس'),
                    value: firstOrderOnly,
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            firstOrderOnly = v;
                            preview = null;
                            _dirty = true;
                            _persistDraft();
                          }),
                  ),
                ],
              ),
              if (OwnerSession.instance.role == 'Owner')
                CheckboxListTile(
                  title: const Text(
                    'به‌عنوان مدیر اصلی، احتمال فروش با سود منفی را برای این کوپن تأیید می‌کنم.',
                  ),
                  value: allowLoss,
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          allowLoss = v!;
                          _dirty = true;
                          _persistDraft();
                        }),
                ),
              const Divider(height: 32),
              const Text(
                'محاسبهٔ آزمایشی سبد خرید',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'اینجا کالاها و تعدادشان را برای محاسبه انتخاب کنید؛ این پیش‌نمایش سفارش نمی‌سازد و موجودی را رزرو نمی‌کند.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: editorFieldWidth,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('sample-sku-${field('sku').text}'),
                      initialValue:
                          skuChoices.any(
                            (item) => item.value == field('sku').text,
                          )
                          ? field('sku').text
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'کالا / بستهٔ نمونه',
                      ),
                      items: [
                        for (final option in skuChoices)
                          DropdownMenuItem(
                            value: option.value,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              field('sku').text = value ?? '';
                              preview = null;
                            }),
                    ),
                  ),
                  input('quantity', 'تعداد'),
                  input('shipping', 'کد ارسال؛ post یا pickup'),
                  if (OwnerSession.instance.can('customers.pii.read'))
                    input('sampleMobile', 'موبایل سبد نمونه'),
                  input('sampleCity', 'شهر سبد نمونه'),
                ],
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : addSampleLine,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('افزودن کالا به سبد نمونه'),
              ),
              if (sampleBasket.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final line in sampleBasket)
                      InputChip(
                        label: Text(
                          '${_choiceLabel(skuChoices, line['sku'] as String)} · ${formatPersianInteger(line['quantity'] as int)} بسته',
                        ),
                        onDeleted: busy
                            ? null
                            : () => setState(() {
                                sampleBasket.remove(line);
                                preview = null;
                              }),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: busy ? null : () => run(false),
                child: const Text('محاسبه مبلغ و سود'),
              ),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'جمع: ${formatToman(preview!['subtotal'] as num)} • تخفیف: ${formatToman(preview!['discount'] as num)} • ارسال: ${formatToman(preview!['shipping'] as num)} • مالیات: ${formatToman(preview!['tax'] as num)} • قابل پرداخت: ${formatToman(preview!['payable'] as num)}\nبهای کالا: ${formatToman(preview!['cost'] as num)} • هزینه ارسال: ${formatToman(preview!['shippingExpense'] as num)} • سود پس از هزینه‌ها: ${formatToman(preview!['netProfit'] as num)} تومان${(preview!['netProfit'] as num) < 0 ? '\nهشدار: سود منفی است؛ تأیید مدیر اصلی لازم است.' : ''}${preview!['error'] == null ? '' : '\n${preview!['error']}'}',
                    style: TextStyle(
                      color: (preview!['netProfit'] as num) < 0
                          ? Colors.red
                          : null,
                    ),
                  ),
                ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : _requestClose,
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: busy ? null : () => run(true),
        child: const Text('ذخیره کوپن'),
      ),
    ],
  ));
}

String _choiceLabel(
  List<({String value, String label})> choices,
  String value,
) {
  for (final choice in choices) {
    if (choice.value == value) return choice.label;
  }
  return value;
}

class _MultiSelectField extends StatelessWidget {
  const _MultiSelectField({
    required this.label,
    required this.choices,
    required this.selected,
    required this.loading,
    required this.onChanged,
  });

  final String label;
  final List<({String value, String label})> choices;
  final List<String> selected;
  final bool loading;
  final ValueChanged<List<String>> onChanged;

  Future<void> _select(BuildContext context) async {
    final available = <String, String>{
      for (final choice in choices) choice.value: choice.label,
      for (final value in selected)
        if (!choices.any((choice) => choice.value == value)) value: value,
    };
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final query = ValueNotifier('');
        final checked = selected.toSet();
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          title: Text(label),
          content: SizedBox(
            width: math.min(520, MediaQuery.sizeOf(context).width - 80),
            height: math.min(460, MediaQuery.sizeOf(context).height - 200),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) =>
                      query.value = value.trim().toLowerCase(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'جست‌وجو',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: query,
                    builder: (context, text, _) {
                      final entries = available.entries
                          .where(
                            (entry) =>
                                entry.value.toLowerCase().contains(text) ||
                                entry.key.toLowerCase().contains(text),
                          )
                          .toList();
                      if (entries.isEmpty) {
                        return Center(
                          child: Text(
                            loading
                                ? 'در حال بارگذاری گزینه‌ها…'
                                : 'موردی پیدا نشد.',
                          ),
                        );
                      }
                      return StatefulBuilder(
                        builder: (context, setDialogState) => ListView.builder(
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return CheckboxListTile(
                              value: checked.contains(entry.key),
                              title: Text(entry.value),
                              subtitle: entry.value == entry.key
                                  ? null
                                  : Text(
                                      entry.key,
                                      textDirection: TextDirection.ltr,
                                    ),
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: (value) => setDialogState(() {
                                if (value == true) {
                                  checked.add(entry.key);
                                } else {
                                  checked.remove(entry.key);
                                }
                              }),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, <String>[]),
              child: const Text('پاک‌کردن انتخاب‌ها'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, checked.toList()),
              child: const Text('اعمال انتخاب'),
            ),
          ],
        );
      },
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final shown = selected
        .map((value) => _choiceLabel(choices, value))
        .toList();
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => _select(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(
            loading
                ? Icons.hourglass_top_rounded
                : Icons.arrow_drop_down_rounded,
          ),
        ),
        child: Text(
          selected.isEmpty
              ? 'انتخاب از فهرست'
              : '${selected.length} مورد: ${shown.take(2).join('، ')}${shown.length > 2 ? ' و …' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

