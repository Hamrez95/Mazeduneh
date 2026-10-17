import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl;
import 'admin_step_up_dialog.dart';
import 'formatters.dart';

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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(28),
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
          Row(
            mainAxisSize: MainAxisSize.min,
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
      for (final raw in rows ?? [])
        Builder(
          builder: (context) {
            final row = raw as Map<String, dynamic>;
            final rule = row['rule'] as Map<String, dynamic>;
            final start = DateTime.parse(rule['startsAt'] as String);
            final end = DateTime.parse(rule['endsAt'] as String);
            final now = DateTime.now();
            final state = rule['active'] != true
                ? 'غیرفعال'
                : now.isBefore(start)
                ? 'زمان‌بندی‌شده'
                : !now.isBefore(end)
                ? 'پایان‌یافته'
                : 'فعال';
            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                title: Text(
                  '${rule['name']} · ${row['code']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
  TextEditingController field(String name) =>
      fields.putIfAbsent(name, () => TextEditingController());
  @override
  void initState() {
    super.initState();
    final rule = widget.item?['rule'] as Map<String, dynamic>?;
    kind = rule?['kind'] as String? ?? 'Percent';
    active = rule?['active'] == true;
    allowLoss = rule?['allowLoss'] == true;
    field('code').text = widget.item?['code'] as String? ?? '';
    field('name').text = rule?['name'] as String? ?? '';
    final promotionValue = (rule?['value'] as num? ?? 10) /
        (kind == 'Fixed' ? 10 : 1);
    field('value').text = kind == 'Fixed'
        ? formatPersianInteger(promotionValue)
        : toPersianDigits(promotionValue);
    field('min').text = formatPersianInteger(
      (rule?['minSubtotal'] as num? ?? 0) / 10,
    );
    field('max').text = rule?['maxDiscount'] == null
        ? ''
        : formatPersianInteger((rule!['maxDiscount'] as num) / 10);
    field('uses').text = toPersianDigits(rule?['maxUses'] ?? '');
    field('skus').text = (rule?['skus'] as List? ?? []).join(', ');
    field('start').text = toPersianDigits(
        (DateTime.tryParse(rule?['startsAt'] as String? ?? '')?.toLocal() ??
                DateTime.now().subtract(const Duration(minutes: 1)))
            .toString()
            .substring(0, 16));
    field('end').text = toPersianDigits(
        (DateTime.tryParse(rule?['endsAt'] as String? ?? '')?.toLocal() ??
                DateTime.now().add(const Duration(days: 30)))
            .toString()
            .substring(0, 16));
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
        : '${(rule!['bundlePrice'] as num) / 10}';
    field('bundleItems').text = (rule?['bundleItems'] as List? ?? [])
        .map((x) => '${x['sku']}:${x['quantity']}')
        .join(', ');
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
  List<Map<String, dynamic>> basket(String key) => csv(key).map((s) {
    final parts = s.split(':');
    final qty = parts.length == 2
        ? int.tryParse(normalizeNumberDigits(parts[1].trim()))
        : null;
    if (parts.length != 2 ||
        parts[0].trim().isEmpty ||
        qty == null ||
        qty < 1 ||
        qty > 50)
      throw Exception(
        'اقلام را به شکل SKU:تعداد وارد کنید؛ مانند A-250:2, B-250:1',
      );
    return <String, dynamic>{'sku': parts[0].trim(), 'quantity': qty};
  }).toList();
  Map<String, dynamic> rule() => {
    'name': field('name').text.trim(),
    'kind': kind,
    'value': !['Percent', 'Fixed'].contains(kind)
        ? 0
        : number('value') * (kind == 'Fixed' ? 10 : 1),
    'active': active,
    'startsAt': DateTime.parse(normalizeNumberDigits(field('start').text)).toUtc().toIso8601String(),
    'endsAt': DateTime.parse(normalizeNumberDigits(field('end').text)).toUtc().toIso8601String(),
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
    'bundleItems': kind == 'Bundle' ? basket('bundleItems') : null,
    'bundlePrice': kind == 'Bundle' ? number('bundlePrice') * 10 : null,
  };
  Future<void> run(bool save) async {
    if (form.currentState?.validate() != true) return;
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
        if (mounted) Navigator.pop(context, true);
      } else {
        final quantity = number('quantity');
        if (field('basket').text.trim().isEmpty &&
                field('sku').text.trim().isEmpty ||
            quantity < 1 ||
            quantity != quantity.toInt())
          throw Exception('برای پیش‌نمایش یک SKU و تعداد صحیح وارد کنید.');
        final result = await widget.api.send(
          'POST',
          '/preview',
          body: {
            'rule': payload,
            'lines': field('basket').text.trim().isNotEmpty
                ? basket('basket')
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
    width: 330,
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
        if (date && DateTime.tryParse(normalizeNumberDigits(value ?? '')) == null)
          return 'مثال: 2026-10-17 14:30';
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'کوپن جدید' : 'ویرایش کوپن'),
    content: SizedBox(
      width: 730,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 18,
                children: [
                  input('code', 'کد انگلیسی؛ مثل WELCOME10', required: true),
                  input('name', 'نام کوپن', required: true),
                  SizedBox(
                    width: 330,
                    child: DropdownButtonFormField<String>(
                      initialValue: kind,
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
                    input('skus', 'SKUهای خرید با کاما؛ خالی یعنی همه'),
                  if (kind == 'BuyGet') ...[
                    input('buy', 'تعداد خرید X', required: true),
                    input('get', 'تعداد هدیه Y', required: true),
                    input('rewardSkus', 'SKUهای هدیه؛ خالی یعنی کالاهای خرید'),
                  ],
                  if (kind == 'Bundle') ...[
                    input(
                      'bundleItems',
                      'اقلام پک؛ A-250:2, B-250:1',
                      required: true,
                    ),
                    input(
                      'bundlePrice',
                      'قیمت نهایی یک پک (تومان)',
                      required: true,
                    ),
                  ],
                  if (['BuyGet', 'Bundle'].contains(kind))
                    input('applications', 'سقف تکرار پیشنهاد در هر سفارش'),
                  input(
                    'start',
                    'شروع به وقت این سیستم؛ YYYY-MM-DD HH:mm',
                    date: true,
                  ),
                  input(
                    'end',
                    'پایان به وقت این سیستم؛ YYYY-MM-DD HH:mm',
                    date: true,
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('فعال یا زمان‌بندی‌شده'),
                value: active,
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        active = v;
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
                        input('categories', 'دسته‌های کالا با کاما؛ اختیاری'),
                      input('cities', 'شهرهای مجاز با کاما؛ اختیاری'),
                      if (OwnerSession.instance.can('customers.pii.read'))
                        input(
                          'customerMobiles',
                          'موبایل مشتری‌های مجاز با کاما',
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
                        }),
                ),
              const Divider(height: 32),
              const Text(
                'پیش‌نمایش یک سبد نمونه',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  input('sku', 'SKU نمونه'),
                  input('quantity', 'تعداد'),
                  input('shipping', 'کد ارسال؛ post یا pickup'),
                  input('basket', 'سبد چندقلمی؛ A-250:2, B-250:1'),
                  if (OwnerSession.instance.can('customers.pii.read'))
                    input('sampleMobile', 'موبایل سبد نمونه'),
                  input('sampleCity', 'شهر سبد نمونه'),
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
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton(
        onPressed: busy ? null : () => run(true),
        child: const Text('ذخیره کوپن'),
      ),
    ],
  );
}
