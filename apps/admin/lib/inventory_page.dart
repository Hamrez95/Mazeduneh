import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'admin_permissions.dart';
import 'admin_state.dart';
import 'admin_theme.dart';
import 'auth_session.dart';
import 'catalog_api.dart';
import 'formatters.dart';
import 'inventory_pricing_dialog.dart';
import 'inventory_receipt_dialog.dart';
import 'order_api.dart';

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


