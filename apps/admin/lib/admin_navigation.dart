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
    this.sku,
    this.batchCode,
    this.query,
    this.createdFromUtc,
    this.createdToUtcExclusive,
  });

  final AdminModule module;
  final AdminOrderFilter orderFilter;
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
      other.sku == sku &&
      other.batchCode == batchCode &&
      other.query == query &&
      other.createdFromUtc == createdFromUtc &&
      other.createdToUtcExclusive == createdToUtcExclusive;

  @override
  int get hashCode => Object.hash(module, orderFilter, sku, batchCode, query, createdFromUtc, createdToUtcExclusive);
}

