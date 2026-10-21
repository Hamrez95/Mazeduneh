import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_permissions.dart';
import 'admin_navigation.dart';
import 'admin_state.dart';
import 'admin_theme.dart';
import 'admin_table.dart';
import 'admin_mobile_list_controls.dart';
import 'admin_step_up_dialog.dart';
import 'auth_session.dart';
import 'formatters.dart';
import 'localized_calendar.dart';
import 'order_api.dart';

String _paymentStateLabel(String state) => switch (state) {
  'Pending' => 'در انتظار تأیید',
  'Succeeded' => 'موفق',
  'Failed' => 'ناموفق',
  _ => state,
};

String _paymentProviderLabel(String provider) => switch (provider) {
  'Zibal' => 'زیبال',
  'Sandbox' => 'آزمایشی',
  _ => provider,
};

AdminStatusBadge _orderStatusBadge(String state, String label) {
  final (color, background) = switch (state) {
    'Delivered' => (AdminColors.success, AdminColors.successSoft),
    'Cancelled' => (AdminColors.coral, AdminColors.dangerSoft),
    'Expired' => (AdminColors.amber, AdminColors.warningSoft),
    'AwaitingPayment' => (AdminColors.amber, AdminColors.warningSoft),
    'Paid' ||
    'Preparing' ||
    'Shipped' => (AdminColors.primaryLight, AdminColors.primarySoft),
    _ => (AdminColors.muted, AdminColors.surfaceRaised),
  };
  return AdminStatusBadge(label, color: color, background: background);
}

String _orderTerminalMessage(String state) => switch (state) {
  'Delivered' => 'سفارش تحویل شده است',
  'Cancelled' => 'سفارش لغو شده است',
  'Expired' => 'مهلت پرداخت سفارش پایان یافته است',
  _ => 'برای این وضعیت اقدام بعدی ثبت نشده است',
};

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    super.key,
    this.api,
    this.onNavigationChanged,
    this.initialFilter = AdminOrderFilter.all,
    this.initialQuery = '',
    this.initialOrderId,
    this.initialCreatedFromUtc,
    this.initialCreatedToUtcExclusive,
  });
  final OrderApiClient? api;
  final ValueChanged<AdminNavigationIntent>? onNavigationChanged;
  final AdminOrderFilter initialFilter;
  final String initialQuery;
  final String? initialOrderId;
  final DateTime? initialCreatedFromUtc;
  final DateTime? initialCreatedToUtcExclusive;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _PrivateOrderDialog extends StatefulWidget {
  const _PrivateOrderDialog();

  @override
  State<_PrivateOrderDialog> createState() => _PrivateOrderDialogState();
}

class _PrivateOrderDialogState extends State<_PrivateOrderDialog> {
  final name = TextEditingController();
  final mobile = TextEditingController();
  final province = TextEditingController();
  final city = TextEditingController();
  final address = TextEditingController();
  final postalCode = TextEditingController();
  final lines = <_PrivateOrderLineInput>[_PrivateOrderLineInput()];
  String? error;

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    province.dispose();
    city.dispose();
    address.dispose();
    postalCode.dispose();
    for (final line in lines) line.dispose();
    super.dispose();
  }

  void submit() {
    final normalizedLines = <Map<String, dynamic>>[];
    for (final line in lines) {
      if (line.sku.text.trim().isEmpty && line.quantity.text.trim().isEmpty)
        continue;
      final quantity = parsePersianInteger(line.quantity.text);
      if (line.sku.text.trim().isEmpty || quantity == null || quantity < 1) {
        setState(() => error = 'برای هر ردیف، SKU و تعداد معتبر وارد کنید.');
        return;
      }
      normalizedLines.add({'sku': line.sku.text.trim(), 'quantity': quantity});
    }
    if ([
          name,
          mobile,
          province,
          city,
          address,
          postalCode,
        ].any((controller) => controller.text.trim().isEmpty) ||
        normalizedLines.isEmpty) {
      setState(
        () => error = 'اطلاعات مشتری، نشانی و حداقل یک قلم کالا لازم است.',
      );
      return;
    }
    Navigator.pop(context, {
      'customerName': name.text.trim(),
      'mobile': toLatinDigits(mobile.text.trim()),
      'province': province.text.trim(),
      'city': city.text.trim(),
      'address': address.text.trim(),
      'postalCode': toLatinDigits(postalCode.text.trim()),
      'shippingMethod': 'post',
      'lines': normalizedLines,
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('ثبت سفارش سفارشی خصوصی'),
    content: SizedBox(
      width: MediaQuery.sizeOf(context).width.clamp(320.0, 680.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'این سفارش فقط در پنل و گزارش‌های داخلی دیده می‌شود و در سایت یا حساب مشتری نمایش داده نمی‌شود.',
              style: TextStyle(color: AdminColors.muted, height: 1.6),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 310,
                  child: TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'نام مشتری'),
                  ),
                ),
                SizedBox(
                  width: 310,
                  child: TextField(
                    controller: mobile,
                    keyboardType: TextInputType.phone,
                    inputFormatters: const [PersianDigitsInputFormatter()],
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'شماره تماس'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: province,
                    decoration: const InputDecoration(labelText: 'استان'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'شهر'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: postalCode,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [PersianDigitsOnlyInputFormatter()],
                    textDirection: TextDirection.ltr,
                    maxLength: 10,
                    decoration: const InputDecoration(labelText: 'کد پستی'),
                  ),
                ),
                SizedBox(
                  width:
                      MediaQuery.sizeOf(context).width.clamp(320.0, 680.0) - 40,
                  child: TextField(
                    controller: address,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'نشانی تحویل'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'اقلام سفارش با قیمت ثبت‌شدهٔ هر SKU',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => lines.add(_PrivateOrderLineInput())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('افزودن قلم'),
                ),
              ],
            ),
            for (var i = 0; i < lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: lines[i].sku,
                        decoration: const InputDecoration(labelText: 'SKU'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: lines[i].quantity,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [
                          PersianGroupedIntegerInputFormatter(),
                        ],
                        decoration: const InputDecoration(labelText: 'تعداد'),
                      ),
                    ),
                    if (lines.length > 1)
                      IconButton(
                        tooltip: 'حذف ردیف',
                        onPressed: () {
                          final removed = lines.removeAt(i);
                          removed.dispose();
                          setState(() {});
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: AdminColors.coral)),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('انصراف'),
      ),
      FilledButton.icon(
        onPressed: submit,
        icon: const Icon(Icons.save_outlined),
        label: const Text('ثبت سفارش خصوصی'),
      ),
    ],
  );
}

class _PrivateOrderLineInput {
  final sku = TextEditingController();
  final quantity = TextEditingController(text: '1');
  void dispose() {
    sku.dispose();
    quantity.dispose();
  }
}

class _OrdersPageState extends State<OrdersPage> {
  late final OrderApiClient api = widget.api ?? OrderApiClient();
  final states = const <String, String>{
    '': 'همه سفارش‌ها',
    'AwaitingPayment': 'در انتظار پرداخت',
    'Processing': 'در حال پردازش',
    'Paid': 'پرداخت‌شده',
    'Preparing': 'در حال آماده‌سازی',
    'Shipped': 'ارسال‌شده',
    'Delivered': 'تحویل‌شده',
    'Cancelled': 'لغوشده',
    'Expired': 'منقضی‌شده',
    'Problem': 'لغوشده یا منقضی‌شده',
  };
  List<AdminOrder> orders = const [];
  List<AdminOverdueShipment> overdueShipments = const [];
  late String selectedState = widget.initialFilter.apiValue;
  bool overdueOnly = false;
  int overdueDays = 3;
  final searchController = TextEditingController();
  String searchQuery = '';
  int orderPage = 0;
  int orderPageSize = 10;
  int overduePage = 0;
  Object? error;
  bool loading = true;
  bool exporting = false;
  final selectedOrders = <String>{};
  bool bulkBusy = false;
  String? busyOrder;
  bool openedInitialOrder = false;

  @override
  void initState() {
    super.initState();
    searchController.text = widget.initialOrderId ?? widget.initialQuery;
    searchQuery = widget.initialOrderId ?? widget.initialQuery;
    load();
  }

  @override
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery &&
        searchQuery != widget.initialQuery) {
      searchController.text = widget.initialQuery;
      searchQuery = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
    if (oldWidget.initialFilter != widget.initialFilter &&
        selectedState != widget.initialFilter.apiValue) {
      selectedState = widget.initialFilter.apiValue;
      overdueOnly = false;
      selectedOrders.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
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
        final result = await api.fetchOrders(
          state: selectedState.isEmpty ? null : selectedState,
          query: searchQuery,
          createdFromUtc: widget.initialCreatedFromUtc,
          createdToUtcExclusive: widget.initialCreatedToUtcExclusive,
        );
        if (mounted) {
          setState(() {
            orders = result;
            overdueShipments = const [];
            selectedOrders.removeWhere(
              (id) => !result.any((order) => order.id == id),
            );
          });
          final requestedId = widget.initialOrderId;
          if (!openedInitialOrder && requestedId != null) {
            final matching = result.where((item) => item.id == requestedId);
            if (matching.isNotEmpty) {
              openedInitialOrder = true;
              final requestedOrder = matching.first;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) unawaited(openDetail(requestedOrder));
              });
            }
          }
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
        content: Text(
          order.isPrivate && next == 'Paid'
              ? 'دریافت پرداخت سفارش خصوصی ${order.id.substring(0, 8)} را تأیید می‌کنید؟ این تأیید در سابقه مدیریتی ثبت می‌شود.'
              : 'وضعیت سفارش ${order.id.substring(0, 8)} به «${states[next] ?? next}» تغییر کند؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأیید'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busyOrder = order.id);
    try {
      await api.transition(
        order.id,
        next,
        reason: order.isPrivate && next == 'Paid'
            ? 'دریافت پرداخت سفارش خصوصی توسط مدیر تأیید شد.'
            : null,
      );
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'وضعیت سفارش به «${states[next] ?? next}» تغییر کرد.',
            ),
          ),
        );
      }
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(exception.toString())));
    } finally {
      if (mounted) setState(() => busyOrder = null);
    }
  }

  Future<void> openDetail(AdminOrder order) async {
    _persistNavigation(orderId: order.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(api: api, order: order),
    );
    if (mounted) _persistNavigation();
  }

  void _persistNavigation({String? orderId}) {
    widget.onNavigationChanged?.call(
      AdminNavigationIntent(
        module: AdminModule.orders,
        orderFilter:
            AdminOrderFilter.fromApiValue(selectedState) ??
            AdminOrderFilter.all,
        orderId: orderId,
        query: searchQuery,
        createdFromUtc: widget.initialCreatedFromUtc,
        createdToUtcExclusive: widget.initialCreatedToUtcExclusive,
      ),
    );
  }

  Future<void> createPrivateOrder() async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PrivateOrderDialog(),
    );
    if (request == null || !mounted) return;
    setState(() => loading = true);
    try {
      final id = await api.createPrivateOrder(request);
      await load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'سفارش خصوصی ${id.substring(0, 8)} ثبت شد و در سایت مشتری نمایش داده نمی‌شود.',
            ),
          ),
        );
    } catch (exception) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
      }
    }
  }

  Future<void> exportCsv() async {
    final stepUpToken = await showAdminStepUpDialog(context);
    if (stepUpToken == null || !mounted) return;
    setState(() => exporting = true);
    try {
      final bytes = await api.exportOrdersCsv(
        stepUpToken: stepUpToken,
        state: selectedState.isEmpty ? null : selectedState,
        query: searchQuery,
        createdFromUtc: widget.initialCreatedFromUtc,
        createdToUtcExclusive: widget.initialCreatedToUtcExclusive,
      );
      final opened = await launchUrl(
        Uri.dataFromBytes(
          bytes,
          mimeType: 'text/csv',
          parameters: {'charset': 'utf-8'},
        ),
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'خروجی باز نشد؛ اجازه بازکردن صفحه جدید را بررسی کنید.',
            ),
          ),
        );
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
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
        content: Text(
          '${formatPersianInteger(selectedOrders.length)} سفارش به «${states[next] ?? next}» منتقل شود؟ سفارش‌هایی که مسیرشان مجاز نباشد، جدا گزارش می‌شوند.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأیید عملیات'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => bulkBusy = true);
    try {
      final result = await api.bulkTransition(
        selectedOrders.toList(),
        next,
        reason: 'عملیات گروهی از پنل',
      );
      await load();
      if (mounted) {
        setState(() => selectedOrders.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${formatPersianInteger(result.$1)} سفارش به‌روزرسانی شد${result.$2 == 0 ? '' : ' و ${formatPersianInteger(result.$2)} مورد نیازمند بررسی است.'}',
            ),
          ),
        );
      }
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, pageConstraints) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: pageConstraints.maxHeight.isFinite
                  ? pageConstraints.maxHeight * 0.55
                  : double.infinity,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compactControls = constraints.maxWidth < 560;
                      Widget filterWidth(
                        Widget child, {
                        double desktopWidth = 240,
                      }) => SizedBox(
                        width: compactControls
                            ? constraints.maxWidth
                            : desktopWidth,
                        child: child,
                      );
                      final heading = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سفارش‌ها',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const Text(
                            'فرآیند سفارش را از پرداخت تا تحویل کنترل کنید.',
                            style: TextStyle(
                              color: AdminColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          if (widget.initialCreatedFromUtc != null &&
                              widget.initialCreatedToUtcExclusive != null)
                            const Text(
                              'فهرست بر اساس بازهٔ انتخاب‌شده در داشبورد فیلتر شده است.',
                              style: TextStyle(
                                color: AdminColors.muted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      );
                      final controls = Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilterChip(
                            label: const Text('ارسال‌های تأخیردار'),
                            selected: overdueOnly,
                            onSelected: (value) {
                              setState(() {
                                overdueOnly = value;
                                overduePage = 0;
                                selectedOrders.clear();
                              });
                              load();
                            },
                          ),
                          if (overdueOnly)
                            filterWidth(
                              DropdownButton<int>(
                                isExpanded: true,
                                value: overdueDays,
                                items: const [1, 3, 5, 7, 14]
                                    .map(
                                      (days) => DropdownMenuItem(
                                        value: days,
                                        child: Text(
                                          'بیش از $days روز',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => overdueDays = value);
                                  load();
                                },
                              ),
                              desktopWidth: 180,
                            ),
                          filterWidth(
                            DropdownButton<String>(
                              isExpanded: true,
                              value: selectedState,
                              items: states.entries
                                  .map(
                                    (entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(
                                        entry.value,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  selectedState = value;
                                  orderPage = 0;
                                });
                                _persistNavigation();
                                load();
                              },
                            ),
                          ),
                          if (!OwnerSession.instance.isAuthenticated ||
                              OwnerSession.instance.can(
                                AdminPermissions.ordersExport,
                              ))
                            FilledButton.tonalIcon(
                              onPressed: exporting ? null : exportCsv,
                              icon: exporting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.file_download_outlined),
                              label: const Text('خروجی CSV'),
                            ),
                          if (!OwnerSession.instance.isAuthenticated ||
                              OwnerSession.instance.can(
                                AdminPermissions.ordersWrite,
                              ))
                            FilledButton.tonalIcon(
                              onPressed: createPrivateOrder,
                              icon: const Icon(Icons.add_shopping_cart_rounded),
                              label: const Text('سفارش سفارشی خصوصی'),
                            ),
                          if (selectedOrders.isNotEmpty)
                            PopupMenuButton<String>(
                              onSelected: bulkAdvance,
                              itemBuilder: (_) => states.entries
                                  .where((entry) => entry.key.isNotEmpty)
                                  .map(
                                    (entry) => PopupMenuItem(
                                      value: entry.key,
                                      child: Text('انتقال به ${entry.value}'),
                                    ),
                                  )
                                  .toList(),
                              child: FilledButton.tonalIcon(
                                onPressed: null,
                                icon: bulkBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.playlist_add_check_rounded,
                                      ),
                                label: Text(
                                  'عملیات گروهی (${formatPersianInteger(selectedOrders.length)})',
                                ),
                              ),
                            ),
                          IconButton(
                            onPressed: load,
                            icon: const Icon(Icons.refresh_rounded),
                            tooltip: 'بارگذاری مجدد',
                          ),
                        ],
                      );
                      return constraints.maxWidth < 1120
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                heading,
                                const SizedBox(height: 10),
                                controls,
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(child: heading),
                                Flexible(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: controls,
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      setState(() {
                        searchQuery = value.trim();
                        orderPage = 0;
                      });
                      _persistNavigation();
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
                                setState(() {
                                  searchQuery = '';
                                  orderPage = 0;
                                });
                                _persistNavigation();
                                load();
                              },
                              icon: const Icon(Icons.clear_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _body()),
        ],
      ),
    ),
  );

  Widget _overdueBody() {
    if (overdueShipments.isEmpty) {
      return const Center(
        child: AdminEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'ارسال تأخیردار پیدا نشد',
          detail:
              'سفارش‌های ارسال‌شدهٔ قدیمی‌تر از بازه انتخابی اینجا نمایش داده می‌شوند.',
        ),
      );
    }
    final responsive = MediaQuery.sizeOf(context).width < 1200 ||
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final lastPage = overdueShipments.isEmpty
        ? 0
        : (overdueShipments.length - 1) ~/ orderPageSize;
    final page = overduePage.clamp(0, lastPage);
    final visibleShipments = responsive
        ? overdueShipments.skip(page * orderPageSize).take(orderPageSize).toList()
        : overdueShipments;
    final list = ListView.separated(
      itemCount: visibleShipments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final shipment = visibleShipments[index];
        return Card(
          child: InkWell(
            onTap: () => openDetail(shipment.toAdminOrder()),
            borderRadius: BorderRadius.circular(6),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سفارش ${shipment.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          shipment.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${shipment.province}، ${shipment.city} · ${formatPersianInteger(shipment.lineCount)} قلم',
                          style: const TextStyle(
                            color: AdminColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${formatPersianInteger(shipment.daysOverdue)} روز تأخیر',
                    ),
                    backgroundColor: AdminColors.dangerSoft,
                  ),
                  Text(
                    shipment.trackingCode?.isNotEmpty == true
                        ? 'رهگیری: ${shipment.trackingCode}'
                        : 'کد رهگیری ثبت نشده',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.muted,
                    ),
                  ),
                  Text(
                    shipment.shippingCarrier?.isNotEmpty == true
                        ? shipment.shippingCarrier!
                        : 'شرکت حمل ثبت نشده',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'ارسال: ${formatLocalizedDateTime(context, shipment.shippedAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.muted,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AdminColors.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!responsive) return list;
    return Column(
      children: [
        AdminMobileListControls(
          totalItems: overdueShipments.length,
          page: page,
          pageSize: orderPageSize,
          searchText: '',
          searchHint: '',
          showSearch: false,
          onSearchChanged: (_) {},
          onPageChanged: (value) => setState(() => overduePage = value),
          onPageSizeChanged: (value) => setState(() {
            orderPageSize = value;
            overduePage = 0;
          }),
        ),
        const SizedBox(height: 8),
        Expanded(child: list),
      ],
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return AdminErrorState(error: error!, onRetry: load);
    if (overdueOnly) return _overdueBody();
    if (orders.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AdminEmptyState(
                icon: Icons.receipt_long_rounded,
                title: selectedState.isEmpty
                    ? 'هنوز سفارشی ثبت نشده است'
                    : 'سفارشی با این وضعیت وجود ندارد',
                detail: searchQuery.isNotEmpty
                    ? 'عبارت جست‌وجو یا فیلتر وضعیت را تغییر دهید.'
                    : selectedState.isEmpty
                    ? 'سفارش‌های جدید بعد از ثبت در این فهرست دیده می‌شوند.'
                    : 'فیلتر وضعیت را تغییر دهید یا همه سفارش‌ها را ببینید.',
              ),
            ),
          ),
        ),
      );
    }
    if (MediaQuery.sizeOf(context).width >= 1200 &&
        MediaQuery.textScalerOf(context).scale(1) < 1.5) {
      return SingleChildScrollView(
        child: AdminRecordTable<AdminOrder>(
          records: orders,
          pageIndex: orderPage,
          pageSizeValue: orderPageSize,
          onPageChanged: (value) => setState(() => orderPage = value),
          onPageSizeChanged: (value) => setState(() {
            orderPageSize = value;
            orderPage = 0;
          }),
          onOpen: openDetail,
          isSelected: (order) => selectedOrders.contains(order.id),
          onSelectionChanged: bulkBusy
              ? null
              : (order, selected) => setState(
                  () => selected
                      ? selectedOrders.add(order.id)
                      : selectedOrders.remove(order.id),
                ),
          columns: [
            AdminColumn(
              'سفارش',
              (o) => Text(
                '#${o.id.substring(0, 8)}',
                style: const TextStyle(color: AdminColors.primaryLight),
              ),
              compare: (a, b) => a.id.compareTo(b.id),
            ),
            AdminColumn(
              'مشتری',
              (o) => AdminIdentityCell(
                title: o.customerName,
                subtitle: '${o.province}، ${o.city}',
              ),
              compare: (a, b) => a.customerName.compareTo(b.customerName),
            ),
            AdminColumn(
              'تاریخ ثبت',
              (o) => Text(
                formatLocalizedDateTime(context, o.createdAt),
                style: const TextStyle(fontSize: 11),
              ),
              compare: (a, b) => a.createdAt.compareTo(b.createdAt),
            ),
            AdminColumn(
              'پرداخت',
              (o) => AdminStatusBadge(
                _paymentStateLabel(o.paymentState ?? 'Pending'),
                color: o.paymentState == 'Succeeded'
                    ? AdminColors.success
                    : AdminColors.amber,
                background: o.paymentState == 'Succeeded'
                    ? AdminColors.successSoft
                    : AdminColors.warningSoft,
              ),
            ),
            AdminColumn(
              'وضعیت',
              (o) => _orderStatusBadge(o.state, states[o.state] ?? o.state),
            ),
            AdminColumn(
              'مبلغ',
              (o) => Text(formatAdminMoney(o.payable, currency: o.currency)),
              compare: (a, b) => a.payable.compareTo(b.payable),
            ),
            AdminColumn(
              'عملیات',
              (o) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'جزئیات سفارش',
                    onPressed: () => openDetail(o),
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                  ),
                  if (o.nextState != null)
                    IconButton(
                      tooltip: states[o.nextState] ?? 'مرحلهٔ بعد',
                      onPressed: busyOrder == o.id ? null : () => advance(o),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final lastPage = orders.isEmpty ? 0 : (orders.length - 1) ~/ orderPageSize;
    final currentPage = orderPage.clamp(0, lastPage);
    final visibleOrders = orders
        .skip(currentPage * orderPageSize)
        .take(orderPageSize)
        .toList();
    final list = ListView.separated(
      itemCount: visibleOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final order = visibleOrders[index];
        final next = order.nextState;
        final busy = busyOrder == order.id;
        return Card(
          child: InkWell(
            onTap: () => openDetail(order),
            borderRadius: BorderRadius.circular(6),
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
                    onChanged: bulkBusy
                        ? null
                        : (value) => setState(
                            () => value == true
                                ? selectedOrders.add(order.id)
                                : selectedOrders.remove(order.id),
                          ),
                    semanticLabel:
                        'انتخاب سفارش ${order.id.substring(0, 8)} برای عملیات گروهی',
                  ),
                  SizedBox(
                    width: 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سفارش ${order.id.substring(0, 8)}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          order.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${order.province}، ${order.city} · ${formatPersianInteger(order.lineCount)} قلم',
                          style: const TextStyle(
                            color: AdminColors.muted,
                            fontSize: 11,
                          ),
                        ),
                        if (order.isPrivate)
                          const Padding(
                            padding: EdgeInsets.only(top: 5),
                            child: Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text('فقط داخلی'),
                              backgroundColor: AdminColors.warningSoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _orderStatusBadge(
                    order.state,
                    states[order.state] ?? order.state,
                  ),
                  Text(
                    formatAdminMoney(order.payable, currency: order.currency),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (next != null)
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : () => advance(order),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_rounded),
                      label: Text('مرحله بعد: ${states[next] ?? next}'),
                    )
                  else
                    Text(
                      _orderTerminalMessage(order.state),
                      style: TextStyle(
                        color: order.state == 'Delivered'
                            ? AdminColors.success
                            : order.state == 'Cancelled'
                            ? AdminColors.coral
                            : order.state == 'Expired'
                            ? AdminColors.amber
                            : AdminColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: AdminColors.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return Column(
      children: [
        AdminMobileListControls(
          totalItems: orders.length,
          page: currentPage,
          pageSize: orderPageSize,
          searchText: '',
          searchHint: '',
          showSearch: false,
          onSearchChanged: (_) {},
          onPageChanged: (value) => setState(() => orderPage = value),
          onPageSizeChanged: (value) => setState(() {
            orderPageSize = value;
            orderPage = 0;
          }),
        ),
        const SizedBox(height: 8),
        Expanded(child: list),
      ],
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
  bool savingInternalCost = false;
  bool openingPackingSlip = false;
  final noteController = TextEditingController();
  final internalCostTitleController = TextEditingController();
  final internalCostAmountController = TextEditingController();
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
        shippingExpenseController.text = result.shippingExpense == 0
            ? ''
            : formatToman(result.shippingExpense);
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
    internalCostTitleController.dispose();
    internalCostAmountController.dispose();
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('یادداشت داخلی ثبت شد.')));
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => savingNote = false);
    }
  }

  Future<void> addInternalCost() async {
    final title = internalCostTitleController.text.trim();
    final amount = parseTomanToRial(internalCostAmountController.text);
    if (title.isEmpty || title.length > 160 || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عنوان و مبلغ معتبر هزینه داخلی را وارد کنید.'),
        ),
      );
      return;
    }
    setState(() => savingInternalCost = true);
    try {
      await widget.api.addInternalCost(widget.order.id, title, amount);
      internalCostTitleController.clear();
      internalCostAmountController.clear();
      await load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هزینه فقط برای محاسبات داخلی ثبت شد.')),
        );
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    } finally {
      if (mounted) setState(() => savingInternalCost = false);
    }
  }

  Future<void> removeInternalCost(AdminOrderInternalCost cost) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف هزینه داخلی'),
        content: Text(
          '«${cost.title}» از محاسبه سود حذف شود؟ این تغییر در سابقه مدیریتی ثبت می‌شود.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف هزینه'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.removeInternalCost(widget.order.id, cost.id);
      await load();
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
    }
  }

  Future<void> saveShipping() async {
    final expense = shippingExpenseController.text.trim().isEmpty
        ? null
        : parseTomanToRial(shippingExpenseController.text);
    if (shippingExpenseController.text.trim().isNotEmpty &&
        (expense == null || expense < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هزینه واقعی ارسال را به‌صورت عدد معتبر وارد کنید.'),
        ),
      );
      return;
    }
    final reason = shippingReasonController.text.trim();
    if (reason.isEmpty || reason.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('دلیل ثبت یا اصلاح اطلاعات ارسال را وارد کنید.'),
        ),
      );
      return;
    }
    final currentExpense = detail?.shippingExpense ?? 0;
    final nextExpense = expense ?? 0;
    final updateActualShippingCost = nextExpense != currentExpense;
    final stepUpToken = updateActualShippingCost
        ? await showAdminStepUpDialog(context)
        : null;
    if (updateActualShippingCost && (stepUpToken == null || !mounted)) return;
    setState(() => savingShipping = true);
    try {
      final result = await widget.api.updateShipping(
        widget.order.id,
        carrier: carrierController.text.trim().isEmpty
            ? null
            : carrierController.text.trim(),
        trackingCode: trackingController.text.trim().isEmpty
            ? null
            : trackingController.text.trim(),
        actualShippingCost: expense,
        updateActualShippingCost: updateActualShippingCost,
        stepUpToken: stepUpToken,
        reason: reason,
      );
      if (mounted) {
        setState(() => detail = result);
        shippingReasonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('اطلاعات ارسال ذخیره و در سابقه سفارش ثبت شد.'),
          ),
        );
      }
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
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
      if (!opened && mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'برگه باز نشد؛ اجازه بازکردن صفحه جدید را بررسی کنید.',
            ),
          ),
        );
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(requestErrorMessage(exception))));
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'جزئیات سفارش',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'بستن',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  Widget _content(AdminOrderDetail detail) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'سفارش ${detail.order.id.substring(0, 8)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          Chip(
            label: Text(_stateLabel(detail.order.state)),
            backgroundColor: AdminColors.mintSoft,
          ),
          if (detail.order.isPrivate)
            const Chip(
              label: Text('سفارش خصوصی؛ فقط پنل'),
              backgroundColor: AdminColors.warningSoft,
            ),
          if (!OwnerSession.instance.isAuthenticated ||
              (OwnerSession.instance.can(
                    AdminPermissions.ordersDocumentsRead,
                  ) &&
                  OwnerSession.instance.can(AdminPermissions.customersPiiRead)))
            FilledButton.tonalIcon(
              onPressed: openingPackingSlip ? null : openPackingSlip,
              icon: openingPackingSlip
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              label: const Text('برگه بسته‌بندی'),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _detailCard(
        title: 'مشتری و تحویل',
        icon: Icons.person_pin_circle_outlined,
        child: Wrap(
          spacing: 28,
          runSpacing: 14,
          children: [
            _detailValue('مشتری', detail.order.customerName),
            _detailValue('تماس', toPersianDigits(detail.order.mobile)),
            _detailValue(
              'شهر',
              '${detail.order.province}، ${detail.order.city}',
            ),
            _detailValue('روش ارسال', detail.shippingMethod),
            _detailValue('نشانی', detail.address, width: 320),
            _detailValue('کد پستی', toPersianDigits(detail.postalCode)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _detailCard(
        title: 'ارسال و هزینه واقعی',
        icon: Icons.local_shipping_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اطلاعات ثبت‌شده: شرکت حمل ${detail.shippingCarrier?.trim().isNotEmpty == true ? detail.shippingCarrier : 'ثبت نشده'} · کد رهگیری ${detail.trackingCode?.trim().isNotEmpty == true ? toPersianDigits(detail.trackingCode) : 'ثبت نشده'}',
              style: const TextStyle(fontSize: 12, color: AdminColors.muted),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: carrierController,
                    decoration: const InputDecoration(labelText: 'شرکت حمل'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: trackingController,
                    decoration: const InputDecoration(labelText: 'کد رهگیری'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: shippingExpenseController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [
                      PersianGroupedIntegerInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'هزینه واقعی ارسال',
                      suffixText: 'تومان',
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: shippingReasonController,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'دلیل ثبت یا اصلاح ارسال',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    detail.shippedAt == null
                        ? 'هنوز زمان ارسال ثبت نشده است.'
                        : 'ارسال‌شده در ${formatLocalizedDateTime(context, detail.shippedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AdminColors.muted,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: savingShipping ? null : saveShipping,
                  icon: savingShipping
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('ذخیره ارسال'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _detailCard(
        title: 'اقلام سفارش',
        icon: Icons.shopping_bag_outlined,
        child: detail.lines.isEmpty
            ? const AdminEmptyState(
                icon: Icons.shopping_bag_outlined,
                title: 'قلمی ثبت نشده است',
                detail: 'اطلاعات اقلام این سفارش در دسترس نیست.',
              )
            : Column(
                children: [
                  for (var i = 0; i < detail.lines.length; i++) ...[
                    if (i > 0) const Divider(height: 22),
                    _lineRow(detail.lines[i]),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 12),
      _detailCard(
        title: 'جمع سفارش',
        icon: Icons.receipt_long_outlined,
        child: Column(
          children: [
            _moneyRow('جمع کالا', detail.subtotal, detail.order.currency),
            _moneyRow('ارسال', detail.shipping, detail.order.currency),
            if (detail.discount > 0)
              _moneyRow('تخفیف', -detail.discount, detail.order.currency),
            _moneyRow('مالیات', detail.tax, detail.order.currency),
            const Divider(height: 20),
            _moneyRow(
              'مبلغ نهایی',
              detail.order.payable,
              detail.order.currency,
              strong: true,
            ),
            if (detail.shippingExpense > 0)
              _moneyRow(
                'هزینه واقعی ارسال',
                detail.shippingExpense,
                detail.order.currency,
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _detailCard(
        title: 'هزینه‌های داخلی حسابداری',
        icon: Icons.calculate_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'این هزینه‌ها به مبلغ مشتری و فاکتور اضافه نمی‌شوند؛ فقط از سود واقعی سفارش کم می‌شوند.',
              style: TextStyle(fontSize: 12, color: AdminColors.muted),
            ),
            const SizedBox(height: 12),
            if (detail.internalCosts.isEmpty)
              const AdminEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'هزینه اضافه‌ای ثبت نشده',
                detail:
                    'مثلاً بسته‌بندی ویژه، نمونه رایگان یا هدیه را اینجا ثبت کنید.',
              ),
            for (final cost in detail.internalCosts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  cost.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${cost.actor} · ${formatLocalizedDateTime(context, cost.createdAt)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatAdminMoney(cost.amount, currency: detail.order.currency),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    IconButton(
                      tooltip: 'حذف از محاسبه سود',
                      onPressed: () => removeInternalCost(cost),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            if (detail.internalCosts.isNotEmpty) ...[
              const Divider(),
              _moneyRow(
                'جمع هزینه‌های داخلی',
                detail.internalCosts.fold<num>(
                  0,
                  (sum, cost) => sum + cost.amount,
                ),
                detail.order.currency,
                strong: true,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: internalCostTitleController,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'عنوان هزینه',
                      hintText: 'مثلاً بسته‌بندی اضافه یا سمپل',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: internalCostAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: const [
                      PersianGroupedIntegerInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'مبلغ هزینه',
                      suffixText: 'تومان',
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: savingInternalCost ? null : addInternalCost,
                  icon: savingInternalCost
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('ثبت هزینه داخلی'),
                ),
              ],
            ),
          ],
        ),
      ),
      if (detail.payment != null) ...[
        const SizedBox(height: 12),
        _detailCard(
          title: 'پرداخت',
          icon: Icons.payments_outlined,
          child: Wrap(
            spacing: 28,
            runSpacing: 14,
            children: [
              _detailValue('وضعیت', _paymentStateLabel(detail.payment!.state)),
              _detailValue(
                'درگاه',
                _paymentProviderLabel(detail.payment!.provider),
              ),
              _detailValue(
                'مبلغ',
                formatAdminMoney(detail.payment!.amount, currency: detail.payment!.currency),
              ),
              if (detail.payment!.reference != null)
                _detailValue('شناسه پیگیری', detail.payment!.reference!),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      _detailCard(
        title: 'مسیر سفارش',
        icon: Icons.route_rounded,
        child: detail.transitions.isEmpty
            ? const AdminEmptyState(
                icon: Icons.route_rounded,
                title: 'تاریخچه‌ای ثبت نشده است',
                detail: 'تغییرات وضعیت این سفارش هنوز ثبت نشده است.',
              )
            : Column(
                children: [
                  for (var i = 0; i < detail.transitions.length; i++)
                    _timelineRow(
                      detail.transitions[i],
                      isLast: i == detail.transitions.length - 1,
                    ),
                ],
              ),
      ),
      const SizedBox(height: 12),
      _detailCard(
        title: 'یادداشت داخلی',
        icon: Icons.sticky_note_2_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (detail.notes.isEmpty)
              const AdminEmptyState(
                icon: Icons.sticky_note_2_outlined,
                title: 'هنوز یادداشتی ثبت نشده است',
                detail:
                    'برای هماهنگی با همکاران، نتیجه تماس یا نکته مهم سفارش را اینجا بنویسید.',
              ),
            if (detail.notes.isNotEmpty) ...[
              for (var i = 0; i < detail.notes.length; i++) ...[
                if (i > 0) const Divider(height: 22),
                _noteRow(detail.notes[i]),
              ],
              const SizedBox(height: 14),
            ],
            TextField(
              controller: noteController,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'یادداشت جدید',
                hintText: 'مثلاً: مشتری زمان تحویل را تأیید کرد.',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: savingNote ? null : saveNote,
                icon: savingNote
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('ثبت یادداشت'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _detailCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AdminColors.ink),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AdminColors.inkDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );

  Widget _detailValue(String label, String value, {double? width}) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AdminColors.muted),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _lineRow(AdminOrderLine line) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.productTitle,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${line.variantLabel} · ${line.sku}',
              style: const TextStyle(fontSize: 11, color: AdminColors.muted),
            ),
          ],
        ),
      ),
      Text(
        '${formatPersianInteger(line.quantity)} × ${formatAdminMoney(line.unitPrice, currency: detail!.order.currency)}',
        style: const TextStyle(fontSize: 12, color: AdminColors.muted),
      ),
      const SizedBox(width: 12),
      Text(
        formatAdminMoney(line.lineTotal, currency: detail!.order.currency),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ],
  );

  Widget _moneyRow(
    String label,
    num value,
    String currency, {
    bool strong = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: strong ? AdminColors.inkDeep : AdminColors.muted,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          formatAdminMoney(value, currency: currency),
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            color: value < 0 ? AdminColors.coral : AdminColors.inkDeep,
          ),
        ),
      ],
    ),
  );

  Widget _timelineRow(AdminOrderTransition item, {required bool isLast}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 28,
        child: Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AdminColors.ink,
              ),
            ),
            if (!isLast)
              Container(width: 1, height: 48, color: AdminColors.border),
          ],
        ),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stateLabel(item.state),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                '${formatLocalizedDateTime(context, item.occurredAt)} · ${item.actor}',
                style: const TextStyle(fontSize: 11, color: AdminColors.muted),
              ),
              if (item.reason.isNotEmpty)
                Text(
                  item.reason,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _noteRow(AdminOrderNote item) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        item.note,
        style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5),
      ),
      const SizedBox(height: 4),
      Text(
        '${formatLocalizedDateTime(context, item.createdAt)} · ${item.actor}',
        style: const TextStyle(fontSize: 11, color: AdminColors.muted),
      ),
    ],
  );

  String _stateLabel(String value) =>
      const {
        'AwaitingPayment': 'در انتظار پرداخت',
        'Paid': 'پرداخت‌شده',
        'Preparing': 'در حال آماده‌سازی',
        'Shipped': 'ارسال‌شده',
        'Delivered': 'تحویل‌شده',
        'Cancelled': 'لغوشده',
        'Expired': 'منقضی‌شده',
      }[value] ??
      value;
}



