import 'package:flutter/foundation.dart';

import 'admin_permissions.dart';

enum AdminModule {
  dashboard('dashboard', AdminPermissions.dashboardRead),
  orders('orders', AdminPermissions.ordersRead),
  products('products', AdminPermissions.productsRead),
  inventory('inventory', AdminPermissions.inventoryRead),
  reports('reports', AdminPermissions.reportsRead),
  notifications('notifications', AdminPermissions.dashboardRead),
  customers('customers', AdminPermissions.customersRead),
  pricing('pricing', AdminPermissions.pricingRead),
  corporate('corporate', AdminPermissions.corporateRead),
  audit('audit', AdminPermissions.auditRead),
  users('users', AdminPermissions.usersRead);

  const AdminModule(this.apiValue, this.permission);

  final String apiValue;
  final String permission;

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
        _ => null,
      };
}

enum AdminOrderFilter {
  all(''),
  awaitingPayment('AwaitingPayment'),
  paid('Paid'),
  preparing('Preparing'),
  shipped('Shipped'),
  delivered('Delivered'),
  cancelled('Cancelled'),
  expired('Expired');

  const AdminOrderFilter(this.apiValue);

  final String apiValue;

  static AdminOrderFilter? fromApiValue(String? value) => switch (value) {
        null || '' => all,
        'AwaitingPayment' => awaitingPayment,
        'Paid' => paid,
        'Preparing' => preparing,
        'Shipped' => shipped,
        'Delivered' => delivered,
        'Cancelled' => cancelled,
        'Expired' => expired,
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
  });

  final AdminModule module;
  final AdminOrderFilter orderFilter;
  final String? sku;
  final String? batchCode;

  @override
  bool operator ==(Object other) =>
      other is AdminNavigationIntent &&
      other.module == module &&
      other.orderFilter == orderFilter &&
      other.sku == sku &&
      other.batchCode == batchCode;

  @override
  int get hashCode => Object.hash(module, orderFilter, sku, batchCode);
}

