import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_state.dart';
import 'customer_api.dart';
import 'formatters.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key, this.api});

  final CustomerApiClient? api;

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  late final CustomerApiClient api = widget.api ?? CustomerApiClient();
  final searchController = TextEditingController();
  List<CustomerSummary> customers = const [];
  CustomerSummary? selected;
  Object? error;
  bool loading = true;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => setState(() {}));
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.fetchCustomers();
      if (mounted) {
        setState(() {
          customers = result;
          final previous = selected;
          final matching = previous == null ? const <CustomerSummary>[] : result.where((item) => item.id == previous.id);
          selected = matching.isEmpty ? null : matching.first;
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> exportCsv() async {
    setState(() => exporting = true);
    try {
      final bytes = await api.exportCustomersCsv(query: searchController.text.trim());
      final opened = await launchUrl(
        Uri.dataFromBytes(bytes, mimeType: 'text/csv', parameters: const {'charset': 'utf-8'}),
        webOnlyWindowName: '_blank',
      );
      if (!opened) throw CustomerApiException('بازکردن فایل خروجی ممکن نشد.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خروجی مشتری‌ها آماده شد؛ فیلتر جست‌وجو هم اعمال شد.')),
        );
      }
    } on CustomerApiException catch (exception) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  List<CustomerSummary> get filtered {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return customers;
    return customers
        .where((item) =>
            item.fullName.toLowerCase().contains(query) ||
            item.mobile.contains(query) ||
            item.normalizedMobile.contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);

    final items = filtered;
    return RefreshIndicator(
      onRefresh: load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          return ListView(
            padding: const EdgeInsets.all(28),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 560 ? constraints.maxWidth - 56 : constraints.maxWidth - 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مشتری‌ها',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: _CustomerColors.inkDeep,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${formatPersianInteger(customers.length)} مشتری ثبت‌شده از سفارش‌های مهمان و حساب‌های فعلی.',
                          style: const TextStyle(color: _CustomerColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: exporting ? null : exportCsv,
                        icon: exporting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_rounded),
                        label: const Text('خروجی CSV'),
                      ),
                      IconButton(
                        onPressed: load,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'بارگذاری مجدد',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'جست‌وجو با نام یا شماره موبایل',
                ),
              ),
              const SizedBox(height: 18),
              if (items.isEmpty)
                _EmptyCustomers(hasQuery: searchController.text.trim().isNotEmpty)
              else if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _CustomerList(items: items, selected: selected, onSelect: _select)),
                    const SizedBox(width: 18),
                    SizedBox(
                      width: 320,
                      child: selected == null
                          ? const _SelectCustomerHint()
                          : _CustomerDetails(customer: selected!),
                    ),
                  ],
                )
              else
                _CustomerList(items: items, selected: selected, onSelect: _select),
            ],
          );
        },
      ),
    );
  }

  void _select(CustomerSummary customer) {
    setState(() => selected = customer);
    _loadProfile(customer);
  }

  Future<void> _loadProfile(CustomerSummary customer) async {
    try {
      final profile = await api.fetchCustomer(customer.id);
      if (!mounted) return;
      setState(() => selected = profile);
      if (MediaQuery.sizeOf(context).width < 860) _showMobileDetails(profile);
    } on CustomerApiException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exception.message)));
    }
  }

  void _showMobileDetails(CustomerSummary customer) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: _CustomerDetails(customer: customer),
        ),
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({required this.items, required this.selected, required this.onSelect});

  final List<CustomerSummary> items;
  final CustomerSummary? selected;
  final ValueChanged<CustomerSummary> onSelect;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final customer in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onSelect(customer),
                borderRadius: BorderRadius.circular(18),
                child: Card(
                  color: selected?.id == customer.id ? _CustomerColors.selected : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _CustomerColors.mint,
                          foregroundColor: _CustomerColors.inkDeep,
                          child: Text(customer.fullName.isEmpty ? '؟' : customer.fullName.substring(0, 1)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer.fullName, style: const TextStyle(fontWeight: FontWeight.w800, color: _CustomerColors.inkDeep)),
                              const SizedBox(height: 5),
                              Text(customer.mobile, style: const TextStyle(color: _CustomerColors.muted)),
                              const SizedBox(height: 5),
                              Text(
                                'آخرین فعالیت: ${formatPersianDateTime(customer.updatedAt)}',
                                style: const TextStyle(fontSize: 11, color: _CustomerColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(formatPersianInteger(customer.orderCount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _CustomerColors.ink)),
                            const Text('سفارش', style: TextStyle(fontSize: 11, color: _CustomerColors.muted)),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_left_rounded, color: _CustomerColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _CustomerDetails extends StatelessWidget {
  const _CustomerDetails({required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('خلاصه مشتری', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _CustomerColors.inkDeep)),
              const SizedBox(height: 18),
              _DetailRow('نام', customer.fullName),
              _DetailRow('موبایل ثبت‌شده', customer.mobile),
              _DetailRow('شناسه نرمال‌شده', customer.normalizedMobile),
              _DetailRow('تعداد سفارش', formatPersianInteger(customer.orderCount)),
              _DetailRow('مجموع خرید', '${formatPersianNumber(customer.totalSpend)} ریال'),
              _DetailRow('میانگین سفارش', '${formatPersianNumber(customer.averageOrderValue)} ریال'),
              _DetailRow('آخرین خرید موفق', customer.lastPurchaseAt == null ? 'هنوز ثبت نشده' : formatPersianDateTime(customer.lastPurchaseAt!)),
              _DetailRow('رضایت ارتباطی', customer.marketingConsent ? 'فعال' : 'ثبت نشده'),
              _DetailRow('اولین ثبت', formatPersianDateTime(customer.createdAt)),
              _DetailRow('آخرین فعالیت', formatPersianDateTime(customer.updatedAt)),
              if (customer.addresses.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('آدرس‌های ذخیره‌شده', style: TextStyle(fontWeight: FontWeight.w900, color: _CustomerColors.inkDeep)),
                const SizedBox(height: 10),
                for (final address in customer.addresses) _AddressRow(address: address),
              ],
            ],
          ),
        ),
      );
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address});

  final CustomerAddress address;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _CustomerColors.selected,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${address.province}، ${address.city}${address.isDefault ? ' · پیش‌فرض' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: _CustomerColors.inkDeep),
            ),
            const SizedBox(height: 4),
            Text(address.address, style: const TextStyle(color: _CustomerColors.muted, height: 1.5)),
            const SizedBox(height: 4),
            Text('کدپستی: ${address.postalCode}', style: const TextStyle(fontSize: 12, color: _CustomerColors.muted)),
            Text('آخرین استفاده: ${formatPersianDateTime(address.lastUsedAt)}', style: const TextStyle(fontSize: 11, color: _CustomerColors.muted)),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 112, child: Text(label, style: const TextStyle(color: _CustomerColors.muted))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: _CustomerColors.inkDeep))),
          ],
        ),
      );
}

class _SelectCustomerHint extends StatelessWidget {
  const _SelectCustomerHint();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(Icons.touch_app_rounded, size: 38, color: _CustomerColors.amber),
              SizedBox(height: 12),
              Text('یک مشتری را انتخاب کنید', style: TextStyle(fontWeight: FontWeight.w800, color: _CustomerColors.inkDeep)),
              SizedBox(height: 6),
              Text('برای دیدن خلاصه اطلاعات و سابقهٔ سفارش انتخابش کنید.', textAlign: TextAlign.center, style: TextStyle(color: _CustomerColors.muted, height: 1.6)),
            ],
          ),
        ),
      );
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(hasQuery ? Icons.search_off_rounded : Icons.people_outline_rounded, size: 48, color: _CustomerColors.muted),
              const SizedBox(height: 12),
              Text(hasQuery ? 'مشتری مطابق جست‌وجو پیدا نشد.' : 'هنوز مشتری ثبت نشده است.', style: const TextStyle(fontWeight: FontWeight.w800, color: _CustomerColors.inkDeep)),
              const SizedBox(height: 6),
              Text(hasQuery ? 'نام یا شماره را با شکل دیگری امتحان کنید.' : 'پس از ثبت اولین سفارش مهمان، مشتری در اینجا دیده می‌شود.', style: const TextStyle(color: _CustomerColors.muted)),
            ],
          ),
        ),
      );
}

class _CustomerColors {
  static const ink = Color(0xFF24463A);
  static const inkDeep = Color(0xFF19352C);
  static const mint = Color(0xFFDDEFE5);
  static const selected = Color(0xFFF0F7F2);
  static const amber = Color(0xFFF2B866);
  static const muted = Color(0xFF718078);
}
