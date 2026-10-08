import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_permissions.dart';
import 'admin_state.dart';
import 'admin_theme.dart';
import 'auth_session.dart';
import 'formatters.dart';
import 'order_api.dart';

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
            return constraints.maxWidth < 1120
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

