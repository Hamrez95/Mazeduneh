import 'package:flutter/material.dart';

import 'admin_permissions.dart';

enum AdminModule {
  dashboard('dashboard', AdminPermissions.dashboardRead, 'داشبورد', Icons.space_dashboard_rounded),
  orders('orders', AdminPermissions.ordersRead, 'سفارش‌ها', Icons.receipt_long_rounded),
  products('products', AdminPermissions.productsRead, 'محصولات', Icons.inventory_2_rounded),
  inventory('inventory', AdminPermissions.inventoryRead, 'انبار', Icons.warehouse_rounded),
  reports('reports', AdminPermissions.reportsRead, 'گزارش‌ها', Icons.query_stats_rounded),
  notifications('notifications', AdminPermissions.dashboardRead, 'اعلان‌ها', Icons.notifications_active_rounded),
  customers('customers', AdminPermissions.customersRead, 'مشتری‌ها', Icons.people_alt_rounded),
  pricing('pricing', AdminPermissions.settingsRead, 'قیمت و ارسال', Icons.percent_rounded),
  corporate('corporate', AdminPermissions.corporateRead, 'فروش سازمانی', Icons.business_center_rounded),
  audit('audit', AdminPermissions.auditRead, 'امنیت', Icons.shield_outlined),
  users('users', AdminPermissions.usersRead, 'کاربران', Icons.manage_accounts_outlined),
  promotions('promotions', AdminPermissions.pricingRead, 'کوپن و تخفیف', Icons.local_offer_outlined);

  const AdminModule(this.apiValue, this.permission, this.label, this.icon);

  final String apiValue;
  final String permission;
  final String label;
  final IconData icon;

  static AdminModule? fromApiValue(String? value) => switch (value) {
        'dashboard' => dashboard,
        'orders' => orders,
        'products' => products,
        'inventory' => inventory,
        'reports' => reports,
        'notifications' => notifications,
        'customers' => customers,
        'pricing' => pricing,
        'corporate' => corporate,
        'audit' => audit,
        'users' => users,
        'promotions' => promotions,
        _ => null,
      };
}

enum AdminOrderFilter {
  all(''),
  awaitingPayment('AwaitingPayment'),
  processing('Processing'),
  paid('Paid'),
  preparing('Preparing'),
  shipped('Shipped'),
  delivered('Delivered'),
  cancelled('Cancelled'),
  expired('Expired'),
  problem('Problem');

  const AdminOrderFilter(this.apiValue);

  final String apiValue;

  static AdminOrderFilter? fromApiValue(String? value) => switch (value) {
        null || '' => all,
        'AwaitingPayment' => awaitingPayment,
        'Processing' => processing,
        'Paid' => paid,
        'Preparing' => preparing,
        'Shipped' => shipped,
        'Delivered' => delivered,
        'Cancelled' => cancelled,
        'Expired' => expired,
        'Problem' => problem,
        _ => null,
      };
}

@immutable
class AdminNavigationIntent {
  const AdminNavigationIntent({
    required this.module,
    this.orderFilter = AdminOrderFilter.all,
    this.orderId,
    this.productSlug,
    this.sku,
    this.batchCode,
    this.query,
    this.createdFromUtc,
    this.createdToUtcExclusive,
  });

  final AdminModule module;
  final AdminOrderFilter orderFilter;
  final String? orderId;
  final String? productSlug;
  final String? sku;
  final String? batchCode;
  final String? query;
  final DateTime? createdFromUtc;
  final DateTime? createdToUtcExclusive;

  @override
  bool operator ==(Object other) =>
      other is AdminNavigationIntent &&
      other.module == module &&
      other.orderFilter == orderFilter &&
      other.orderId == orderId &&
      other.productSlug == productSlug &&
      other.sku == sku &&
      other.batchCode == batchCode &&
      other.query == query &&
      other.createdFromUtc == createdFromUtc &&
      other.createdToUtcExclusive == createdToUtcExclusive;

  @override
  int get hashCode => Object.hash(module, orderFilter, orderId, productSlug, sku, batchCode, query, createdFromUtc, createdToUtcExclusive);

  factory AdminNavigationIntent.fromUri(Uri? uri) {
    final params = uri?.queryParameters ?? const <String, String>{};
    final module = AdminModule.fromApiValue(params['module']) ?? AdminModule.dashboard;
    final filter = module == AdminModule.orders
        ? AdminOrderFilter.fromApiValue(params['status']) ?? AdminOrderFilter.all
        : AdminOrderFilter.all;
    final orderId = _safeRouteToken(params['order']);
    final productSlug = _safeRouteToken(params['product']);
    final query = _safeSearchToken(params['q']);
    final sku = _safeRouteToken(params['sku']);
    final batchCode = _safeRouteToken(params['batch']);
    final from = DateTime.tryParse(params['from'] ?? '')?.toUtc();
    final to = DateTime.tryParse(params['to'] ?? '')?.toUtc();
    final hasRange = from != null && to != null && to.isAfter(from);
    return AdminNavigationIntent(
      module: module,
      orderFilter: filter,
      orderId: module == AdminModule.orders ? orderId : null,
      productSlug: module == AdminModule.products ? productSlug : null,
      query: module == AdminModule.orders ? query : null,
      sku: module == AdminModule.inventory ? sku : null,
      batchCode: module == AdminModule.inventory ? batchCode : null,
      createdFromUtc: hasRange ? from : null,
      createdToUtcExclusive: hasRange ? to : null,
    );
  }

  Uri toUri(Uri current) {
    final params = <String, String>{'module': module.apiValue};
    if (module == AdminModule.orders && orderFilter != AdminOrderFilter.all) {
      params['status'] = orderFilter.apiValue;
    }
    final safeOrderId = _safeRouteToken(orderId);
    final safeProductSlug = _safeRouteToken(productSlug);
    final safeQuery = _safeSearchToken(query);
    final safeSku = _safeRouteToken(sku);
    final safeBatch = _safeRouteToken(batchCode);
    if (module == AdminModule.orders && safeOrderId != null) params['order'] = safeOrderId;
    if (module == AdminModule.orders && safeQuery != null) params['q'] = safeQuery;
    if (module == AdminModule.products && safeProductSlug != null) params['product'] = safeProductSlug;
    if (module == AdminModule.inventory && safeSku != null) params['sku'] = safeSku;
    if (module == AdminModule.inventory && safeBatch != null) params['batch'] = safeBatch;
    if (createdFromUtc != null && createdToUtcExclusive != null &&
        createdToUtcExclusive!.isAfter(createdFromUtc!)) {
      params['from'] = createdFromUtc!.toUtc().toIso8601String();
      params['to'] = createdToUtcExclusive!.toUtc().toIso8601String();
    }
    return current.replace(queryParameters: params, fragment: '');
  }
}

String? _safeRouteToken(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty || normalized.length > 80) return null;
  return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalized) ? normalized : null;
}

/// Order searches can contain customer names and phone numbers. Only retain
/// SKU-like tokens containing letters, digits, and a separator.
String? _safeSearchToken(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.length > 40) return null;
  return RegExp(r'^(?=.*[A-Za-z])(?=.*[0-9])[A-Za-z0-9]+(?:[-_][A-Za-z0-9]+)+$')
          .hasMatch(normalized)
      ? normalized
      : null;
}

