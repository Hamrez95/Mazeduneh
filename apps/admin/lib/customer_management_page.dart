import 'package:flutter/material.dart';

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
          selected = selected == null
              ? null
              : result.where((item) => item.id == selected!.id).firstOrNull;
        });
      }
    } catch (exception) {
      if (mounted) setState(() => error = exception);
    } finally {
      if (mounted) setState(() => loading = false);
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
              Row(
                children: [
                  Expanded(
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
                  IconButton(
                    onPressed: load,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'بارگذاری مجدد',
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
    if (MediaQuery.sizeOf(context).width < 860) {
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
                          child: Text(customer.fullName.isEmpty ? '؟' : customer.fullName.characters.first),
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
              _DetailRow('رضایت ارتباطی', customer.marketingConsent ? 'فعال' : 'ثبت نشده'),
              _DetailRow('اولین ثبت', formatPersianDateTime(customer.createdAt)),
              _DetailRow('آخرین فعالیت', formatPersianDateTime(customer.updatedAt)),
            ],
          ),
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
