import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl;

class OrderApiException implements Exception {
  OrderApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class OrderApiClient {
  OrderApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), '');
  final http.Client _client;
  final String baseUrl;

  Map<String, String> _headers({bool json = false}) {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) throw OrderApiException('نشست شما منقضی شده است.', statusCode: 401);
    return {'authorization': 'Bearer $token', if (json) 'content-type': 'application/json; charset=utf-8'};
  }

  Future<List<AdminOrder>> fetchOrders({String? state, int limit = 100}) async {
    final query = <String, String>{'limit': '$limit', if (state != null && state.isNotEmpty) 'state': state};
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/orders').replace(queryParameters: query), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => AdminOrder.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<AdminDashboard> fetchDashboard() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/dashboard'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminDashboard.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminAnalytics> fetchAnalytics({int days = 30}) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/analytics').replace(queryParameters: {'days': '$days'}), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminAnalytics.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminNotifications> fetchNotifications() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/notifications'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminNotifications.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<StockAdjustmentResult> adjustStock(String sku, int quantityDelta, String reason) async {
    final response = await _client.post(Uri.parse('$baseUrl/api/v1/admin/inventory/adjust'), headers: _headers(json: true), body: jsonEncode({'sku': sku, 'quantityDelta': quantityDelta, 'reason': reason}));
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return StockAdjustmentResult.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<StockMovement>> fetchInventoryMovements({String? sku, int limit = 100}) async {
    final query = <String, String>{'limit': '$limit', if (sku != null && sku.isNotEmpty) 'sku': sku};
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/inventory/movements').replace(queryParameters: query),
      headers: _headers(),
    );
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => StockMovement.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<AdminOrder> transition(String orderId, String state, {String? reason}) async {
    final response = await _client.patch(Uri.parse('$baseUrl/api/v1/admin/orders/$orderId/state'), headers: _headers(json: true), body: jsonEncode({'state': state, 'reason': reason}));
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminOrder.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  void _guard(http.Response response) {
    if (response.statusCode == 401) {
      OwnerSession.instance.clear();
      throw OrderApiException('نشست شما منقضی شده است؛ دوباره وارد شوید.', statusCode: 401);
    }
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['message'] is String) return body['message'] as String;
    } catch (_) {}
    return 'ارتباط با سرور با خطا مواجه شد (${response.statusCode}).';
  }
}

class AdminOrder {
  const AdminOrder({required this.id, required this.customerName, required this.mobile, required this.province, required this.city, required this.payable, required this.currency, required this.state, required this.createdAt, required this.reservationExpiresAt, required this.lineCount, this.paymentReference, this.paymentState});
  final String id;
  final String customerName;
  final String mobile;
  final String province;
  final String city;
  final num payable;
  final String currency;
  final String state;
  final DateTime createdAt;
  final DateTime reservationExpiresAt;
  final int lineCount;
  final String? paymentReference;
  final String? paymentState;

  String? get nextState => switch (state) {'Paid' => 'Preparing', 'Preparing' => 'Shipped', 'Shipped' => 'Delivered', _ => null};

  factory AdminOrder.fromJson(Map<String, dynamic> json) => AdminOrder(
    id: json['id'].toString(), customerName: json['customerName'] as String, mobile: json['mobile'] as String,
    province: json['province'] as String, city: json['city'] as String, payable: json['payable'] as num,
    currency: json['currency'] as String, state: json['state'].toString(), createdAt: DateTime.parse(json['createdAt'] as String),
    reservationExpiresAt: DateTime.parse(json['reservationExpiresAt'] as String), lineCount: json['lineCount'] as int,
    paymentReference: json['paymentReference'] as String?, paymentState: json['paymentState'] as String?);
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.sku,
    required this.quantityDelta,
    required this.movementType,
    required this.balanceAfter,
    required this.orderId,
    required this.actor,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String sku;
  final int quantityDelta;
  final String movementType;
  final int balanceAfter;
  final String? orderId;
  final String actor;
  final String reason;
  final DateTime createdAt;

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'].toString(),
        sku: json['sku'] as String,
        quantityDelta: json['quantityDelta'] as int,
        movementType: json['movementType'] as String,
        balanceAfter: json['balanceAfter'] as int,
        orderId: json['orderId'] as String?,
        actor: json['actor'] as String,
        reason: json['reason'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AdminAnalytics {
  const AdminAnalytics({required this.days, required this.orderCount, required this.unitsSold, required this.revenue, required this.cost, required this.grossProfit, required this.grossMarginPercent});
  final int days;
  final int orderCount;
  final int unitsSold;
  final num revenue;
  final num cost;
  final num grossProfit;
  final num grossMarginPercent;
  factory AdminAnalytics.fromJson(Map<String, dynamic> json) => AdminAnalytics(days: json['days'] as int, orderCount: json['orderCount'] as int, unitsSold: json['unitsSold'] as int, revenue: json['revenue'] as num, cost: json['cost'] as num, grossProfit: json['grossProfit'] as num, grossMarginPercent: json['grossMarginPercent'] as num);
}

class AdminNotification {
  const AdminNotification({required this.type, required this.title, required this.detail});
  final String type;
  final String title;
  final String detail;
  factory AdminNotification.fromJson(Map<String, dynamic> json) => AdminNotification(type: json['type'] as String, title: json['title'] as String, detail: json['detail'] as String);
}

class AdminNotifications {
  const AdminNotifications({required this.awaitingPayment, required this.lowStockItems, required this.items});
  final int awaitingPayment;
  final int lowStockItems;
  final List<AdminNotification> items;
  int get count => items.length;
  factory AdminNotifications.fromJson(Map<String, dynamic> json) => AdminNotifications(awaitingPayment: json['awaitingPayment'] as int, lowStockItems: json['lowStockItems'] as int, items: (json['items'] as List<dynamic>).map((item) => AdminNotification.fromJson(item as Map<String, dynamic>)).toList());
}

class StockAdjustmentResult {
  const StockAdjustmentResult({required this.isSuccess, this.sku, this.balanceAfter, this.message});
  final bool isSuccess;
  final String? sku;
  final int? balanceAfter;
  final String? message;
  factory StockAdjustmentResult.fromJson(Map<String, dynamic> json) => StockAdjustmentResult(isSuccess: json['isSuccess'] as bool? ?? false, sku: json['sku'] as String?, balanceAfter: (json['balanceAfter'] as num?)?.toInt(), message: json['message'] as String?);
}

class AdminDashboard {
  const AdminDashboard({required this.awaitingPayment, required this.processing, required this.shipped, required this.delivered, required this.paidRevenue, required this.todayRevenue, required this.lowStock});
  final int awaitingPayment;
  final int processing;
  final int shipped;
  final int delivered;
  final num paidRevenue;
  final num todayRevenue;
  final List<LowStockItem> lowStock;
  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
    awaitingPayment: json['awaitingPayment'] as int, processing: json['processing'] as int, shipped: json['shipped'] as int,
    delivered: json['delivered'] as int, paidRevenue: json['paidRevenue'] as num, todayRevenue: json['todayRevenue'] as num,
    lowStock: (json['lowStock'] as List<dynamic>).map((item) => LowStockItem.fromJson(item as Map<String, dynamic>)).toList());
}

class LowStockItem {
  const LowStockItem({required this.productTitle, required this.sku, required this.variantLabel, required this.availablePackages});
  final String productTitle;
  final String sku;
  final String variantLabel;
  final int availablePackages;
  factory LowStockItem.fromJson(Map<String, dynamic> json) => LowStockItem(productTitle: json['productTitle'] as String, sku: json['sku'] as String, variantLabel: json['variantLabel'] as String, availablePackages: json['availablePackages'] as int);
}
