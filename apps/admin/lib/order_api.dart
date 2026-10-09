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

  Future<List<AdminOrder>> fetchOrders({String? state, String? query, int limit = 100}) async {
    final params = <String, String>{'limit': '$limit', if (state != null && state.isNotEmpty) 'state': state, if (query != null && query.trim().isNotEmpty) 'q': query.trim()};
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/orders').replace(queryParameters: params), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => AdminOrder.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<AdminOverdueShipment>> fetchOverdueShipments({int days = 3}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/shipping/overdue').replace(queryParameters: {'days': '$days'}),
      headers: _headers(),
    );
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => AdminOverdueShipment.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<int>> exportOrdersCsv({String? state, String? query, int limit = 1000}) async {
    final params = <String, String>{'limit': '$limit', if (state != null && state.isNotEmpty) 'state': state, if (query != null && query.trim().isNotEmpty) 'q': query.trim()};
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/orders/export.csv').replace(queryParameters: params), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return response.bodyBytes;
  }

  Future<AdminDashboard> fetchDashboard({int days = 1, DateTime? fromUtc, DateTime? toUtcExclusive}) async {
    if ((fromUtc == null) != (toUtcExclusive == null)) {
      throw ArgumentError('Both dashboard range boundaries are required.');
    }
    final query = fromUtc == null
        ? {'days': '$days'}
        : {'from': fromUtc.toUtc().toIso8601String(), 'to': toUtcExclusive!.toUtc().toIso8601String()};
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/dashboard').replace(queryParameters: query), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminDashboard.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<DashboardPreferences> fetchDashboardPreferences() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/dashboard/preferences'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return DashboardPreferences.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminDashboardHealth> fetchDashboardHealth() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/dashboard/health'),
      headers: _headers(),
    );
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminDashboardHealth.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<DashboardPreferences> saveDashboardPreferences(DashboardPreferences preferences) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/v1/admin/dashboard/preferences'),
      headers: _headers(json: true),
      body: jsonEncode(preferences.toJson()),
    );
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return DashboardPreferences.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminAnalytics> fetchAnalytics({int days = 30}) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/analytics').replace(queryParameters: {'days': '$days'}), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminAnalytics.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<AdminProductProfitability>> fetchProductProfitability({int days = 30}) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/analytics/products').replace(queryParameters: {'days': '$days'}),
      headers: _headers(),
    );
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => AdminProductProfitability.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<AdminNotifications> fetchNotifications() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/notifications'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminNotifications.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<StockAdjustmentResult> adjustStock(String sku, int quantityDelta, String reason, {required String operationKey}) async {
    final response = await _client.post(Uri.parse('$baseUrl/api/v1/admin/inventory/adjust'), headers: {..._headers(json: true), 'Idempotency-Key': operationKey}, body: jsonEncode({'sku': sku, 'quantityDelta': quantityDelta, 'reason': reason}));
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return StockAdjustmentResult.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<StockAdjustmentResult> writeOffStock(String sku, String batchCode, int quantity, String reason, {required String operationKey}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/inventory/waste'),
      headers: {..._headers(json: true), 'Idempotency-Key': operationKey},
      body: jsonEncode({'sku': sku, 'batchCode': batchCode, 'quantity': quantity, 'reason': reason}),
    );
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

  Future<List<InventoryBatch>> fetchInventoryBatches({String? sku, bool includeExpired = true, int expiryWarningDays = 30, int limit = 100}) async {
    final query = <String, String>{'limit': '$limit', 'includeExpired': '$includeExpired', 'expiryWarningDays': '$expiryWarningDays', if (sku != null && sku.isNotEmpty) 'sku': sku};
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/inventory/batches').replace(queryParameters: query), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => InventoryBatch.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<InventoryPurchasePage> fetchInventoryPurchases({String? sku, String? cursor, int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/inventory/purchases').replace(queryParameters: {
      'limit': '$limit', if (sku != null) 'sku': sku, if (cursor != null) 'cursor': cursor,
    });
    final response = await _client.get(uri, headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return InventoryPurchasePage((json['items'] as List).map((item) => InventoryBatch.fromJson(item as Map<String, dynamic>)).toList(), json['nextCursor'] as String?);
  }

  Future<Map<String, dynamic>> inventoryPricing(String sku, {String? action, Map<String, dynamic>? input}) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/inventory/pricing/${Uri.encodeComponent(sku)}${action == null ? '' : '/$action'}');
    final response = action == null
      ? await _client.get(uri, headers: _headers())
      : await _client.post(uri, headers: _headers(json: true), body: jsonEncode(input));
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<InventoryBatch> receiveInventoryBatch({
    required String sku,
    required String batchCode,
    required int receivedPackages,
    required DateTime producedAt,
    required DateTime expiresAt,
    required num costPrice,
    required num packagingCost,
    required num additionalCost,
    DateTime? purchasedAt,
    String? supplier,
    String? supplierContactName,
    String? supplierPhone,
    String? supplierEmail,
    String? supplierAddress,
    String? supplierNotes,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/inventory/batches'),
      headers: _headers(json: true),
      body: jsonEncode({
        'sku': sku, 'batchCode': batchCode, 'receivedPackages': receivedPackages,
        'producedAt': producedAt.toUtc().toIso8601String(), 'expiresAt': expiresAt.toUtc().toIso8601String(),
        'costPrice': costPrice, 'packagingCost': packagingCost, 'additionalCost': additionalCost,
        if (purchasedAt != null) 'purchasedAt': purchasedAt.toUtc().toIso8601String(),
        if (supplier != null) 'supplier': supplier,
        if (supplierContactName?.trim().isNotEmpty == true) 'supplierContactName': supplierContactName!.trim(),
        if (supplierPhone?.trim().isNotEmpty == true) 'supplierPhone': supplierPhone!.trim(),
        if (supplierEmail?.trim().isNotEmpty == true) 'supplierEmail': supplierEmail!.trim(),
        if (supplierAddress?.trim().isNotEmpty == true) 'supplierAddress': supplierAddress!.trim(),
        if (supplierNotes?.trim().isNotEmpty == true) 'supplierNotes': supplierNotes!.trim(),
      }),
    );
    _guard(response);
    if (response.statusCode != 201) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return InventoryBatch.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminOrder> transition(String orderId, String state, {String? reason}) async {
    final response = await _client.patch(Uri.parse('$baseUrl/api/v1/admin/orders/$orderId/state'), headers: _headers(json: true), body: jsonEncode({'state': state, 'reason': reason}));
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminOrder.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<(int updated, int failed)> bulkTransition(List<String> orderIds, String state, {String? reason}) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/orders/bulk-state'),
      headers: _headers(json: true),
      body: jsonEncode({'orderIds': orderIds, 'state': state, 'reason': reason}),
    );
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (
      (decoded['updated'] as List<dynamic>? ?? const []).length,
      (decoded['failed'] as List<dynamic>? ?? const []).length,
    );
  }

  Future<AdminOrderDetail> fetchOrderDetail(String orderId) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/orders/$orderId'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminOrderDetail.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<String> fetchInvoiceHtml(String orderId) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/orders/$orderId/invoice'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return utf8.decode(response.bodyBytes);
  }

  Future<String> fetchPackingSlipHtml(String orderId) async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/orders/$orderId/packing-slip'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return utf8.decode(response.bodyBytes);
  }

  Future<AdminOrderNote> addOrderNote(String orderId, String note) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/admin/orders/$orderId/notes'),
      headers: _headers(json: true),
      body: jsonEncode({'note': note}),
    );
    _guard(response);
    if (response.statusCode != 201) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminOrderNote.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<AdminOrderDetail> updateShipping(String orderId, {String? carrier, String? trackingCode, num? actualShippingCost, required String reason}) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/api/v1/admin/orders/$orderId/shipping'),
      headers: _headers(json: true),
      body: jsonEncode({'carrier': carrier, 'trackingCode': trackingCode, 'actualShippingCost': actualShippingCost, 'reason': reason}),
    );
    _guard(response);
    if (response.statusCode != 200) throw OrderApiException(_message(response), statusCode: response.statusCode);
    return AdminOrderDetail.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
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

class AdminOverdueShipment {
  const AdminOverdueShipment({
    required this.id,
    required this.customerName,
    required this.mobile,
    required this.province,
    required this.city,
    required this.payable,
    required this.currency,
    required this.state,
    required this.createdAt,
    required this.reservationExpiresAt,
    required this.lineCount,
    required this.shippingCarrier,
    required this.trackingCode,
    required this.shippedAt,
    required this.daysOverdue,
  });

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
  final String? shippingCarrier;
  final String? trackingCode;
  final DateTime shippedAt;
  final int daysOverdue;

  AdminOrder toAdminOrder() => AdminOrder(
        id: id,
        customerName: customerName,
        mobile: mobile,
        province: province,
        city: city,
        payable: payable,
        currency: currency,
        state: state,
        createdAt: createdAt,
        reservationExpiresAt: reservationExpiresAt,
        lineCount: lineCount,
        paymentReference: null,
        paymentState: null,
      );

  factory AdminOverdueShipment.fromJson(Map<String, dynamic> json) => AdminOverdueShipment(
        id: json['id'].toString(),
        customerName: json['customerName'] as String,
        mobile: json['mobile'] as String,
        province: json['province'] as String,
        city: json['city'] as String,
        payable: json['payable'] as num,
        currency: json['currency'] as String,
        state: json['state'].toString(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        reservationExpiresAt: DateTime.parse(json['reservationExpiresAt'] as String),
        lineCount: (json['lineCount'] as num).toInt(),
        shippingCarrier: json['shippingCarrier'] as String?,
        trackingCode: json['trackingCode'] as String?,
        shippedAt: DateTime.parse(json['shippedAt'] as String),
        daysOverdue: (json['daysOverdue'] as num).toInt(),
      );
}

class AdminOrderDetail {
  const AdminOrderDetail({
    required this.order,
    required this.address,
    required this.postalCode,
    required this.subtotal,
    required this.shipping,
    required this.shippingExpense,
    required this.discount,
    required this.tax,
    required this.taxRatePercent,
    required this.shippingMethod,
    required this.shippingCarrier,
    required this.trackingCode,
    required this.shippedAt,
    required this.lines,
    required this.transitions,
    required this.notes,
    this.payment,
  });

  final AdminOrder order;
  final String address;
  final String postalCode;
  final num subtotal;
  final num shipping;
  final num shippingExpense;
  final num discount;
  final num tax;
  final num taxRatePercent;
  final String shippingMethod;
  final String? shippingCarrier;
  final String? trackingCode;
  final DateTime? shippedAt;
  final List<AdminOrderLine> lines;
  final List<AdminOrderTransition> transitions;
  final List<AdminOrderNote> notes;
  final AdminPayment? payment;

  factory AdminOrderDetail.fromJson(Map<String, dynamic> json) => AdminOrderDetail(
        order: AdminOrder.fromJson(json),
        address: json['address'] as String,
        postalCode: json['postalCode'] as String,
        subtotal: json['subtotal'] as num,
        shipping: json['shipping'] as num,
        shippingExpense: json['shippingExpense'] as num,
        discount: json['discount'] as num,
        tax: json['tax'] as num,
        taxRatePercent: json['taxRatePercent'] as num,
        shippingMethod: json['shippingMethod'] as String,
        shippingCarrier: json['shippingCarrier'] as String?,
        trackingCode: json['trackingCode'] as String?,
        shippedAt: json['shippedAt'] == null ? null : DateTime.parse(json['shippedAt'] as String),
        lines: (json['lines'] as List<dynamic>).map((item) => AdminOrderLine.fromJson(item as Map<String, dynamic>)).toList(),
        transitions: (json['transitions'] as List<dynamic>).map((item) => AdminOrderTransition.fromJson(item as Map<String, dynamic>)).toList(),
        notes: (json['notes'] as List<dynamic>? ?? const []).map((item) => AdminOrderNote.fromJson(item as Map<String, dynamic>)).toList(),
        payment: json['payment'] is Map<String, dynamic> ? AdminPayment.fromJson(json['payment'] as Map<String, dynamic>) : null,
      );
}

class AdminOrderLine {
  const AdminOrderLine({required this.productTitle, required this.sku, required this.variantLabel, required this.quantity, required this.unitPrice, required this.lineTotal});
  final String productTitle;
  final String sku;
  final String variantLabel;
  final int quantity;
  final num unitPrice;
  final num lineTotal;

  factory AdminOrderLine.fromJson(Map<String, dynamic> json) => AdminOrderLine(
        productTitle: json['productTitle'] as String,
        sku: json['sku'] as String,
        variantLabel: json['variantLabel'] as String,
        quantity: json['quantity'] as int,
        unitPrice: json['unitPrice'] as num,
        lineTotal: json['lineTotal'] as num,
      );
}

class AdminOrderTransition {
  const AdminOrderTransition({required this.state, required this.actor, required this.occurredAt, required this.reason});
  final String state;
  final String actor;
  final DateTime occurredAt;
  final String reason;

  factory AdminOrderTransition.fromJson(Map<String, dynamic> json) => AdminOrderTransition(
        state: json['state'].toString(),
        actor: json['actor'] as String,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        reason: json['reason'] as String,
      );
}

class AdminOrderNote {
  const AdminOrderNote({required this.id, required this.note, required this.actor, required this.createdAt});
  final String id;
  final String note;
  final String actor;
  final DateTime createdAt;

  factory AdminOrderNote.fromJson(Map<String, dynamic> json) => AdminOrderNote(
        id: json['id'].toString(),
        note: json['note'] as String,
        actor: json['actor'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AdminPayment {
  const AdminPayment({required this.provider, required this.amount, required this.currency, required this.state, this.reference, required this.createdAt, this.completedAt});
  final String provider;
  final num amount;
  final String currency;
  final String state;
  final String? reference;
  final DateTime createdAt;
  final DateTime? completedAt;

  factory AdminPayment.fromJson(Map<String, dynamic> json) => AdminPayment(
        provider: json['provider'] as String,
        amount: json['amount'] as num,
        currency: json['currency'] as String,
        state: json['state'].toString(),
        reference: json['reference'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        completedAt: json['completedAt'] == null ? null : DateTime.parse(json['completedAt'] as String),
      );
}

class InventoryBatch {
  const InventoryBatch({
    required this.id, required this.sku, required this.productTitle, required this.variantLabel,
    required this.batchCode, required this.receivedPackages, required this.remainingPackages,
    required this.producedAt, required this.expiresAt, required this.costPrice,
    required this.packagingCost, required this.additionalCost, required this.isExpired, required this.isExpiringSoon,
    this.purchasedAt, this.supplier, this.supplierContactName, this.supplierPhone, this.supplierEmail,
    this.supplierAddress, this.supplierNotes,
  });
  final String id;
  final String sku;
  final String productTitle;
  final String variantLabel;
  final String batchCode;
  final DateTime? purchasedAt;
  final String? supplier;
  final String? supplierContactName, supplierPhone, supplierEmail, supplierAddress, supplierNotes;
  final int receivedPackages;
  final int remainingPackages;
  final DateTime producedAt;
  final DateTime expiresAt;
  final num costPrice;
  final num packagingCost;
  final num additionalCost;
  final bool isExpired;
  final bool isExpiringSoon;

  factory InventoryBatch.fromJson(Map<String, dynamic> json) => InventoryBatch(
    id: json['id'].toString(), sku: json['sku'] as String, productTitle: json['productTitle'] as String,
    variantLabel: json['variantLabel'] as String, batchCode: json['batchCode'] as String,
    receivedPackages: json['receivedPackages'] as int, remainingPackages: json['remainingPackages'] as int,
    producedAt: DateTime.parse(json['producedAt'] as String), expiresAt: DateTime.parse(json['expiresAt'] as String),
    costPrice: json['costPrice'] as num, packagingCost: json['packagingCost'] as num,
    additionalCost: json['additionalCost'] as num, isExpired: json['isExpired'] as bool,
    isExpiringSoon: json['isExpiringSoon'] as bool? ?? false,
    purchasedAt: DateTime.tryParse(json['purchasedAt']?.toString() ?? ''), supplier: json['supplier'] as String?,
    supplierContactName: json['supplierContactName'] as String?, supplierPhone: json['supplierPhone'] as String?,
    supplierEmail: json['supplierEmail'] as String?, supplierAddress: json['supplierAddress'] as String?,
    supplierNotes: json['supplierNotes'] as String?,
  );
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

class AdminProductProfitability {
  const AdminProductProfitability({
    required this.productTitle,
    required this.sku,
    required this.variantLabel,
    required this.unitsSold,
    required this.revenue,
    required this.cost,
    required this.grossProfit,
  });

  final String productTitle;
  final String sku;
  final String variantLabel;
  final int unitsSold;
  final num revenue;
  final num cost;
  final num grossProfit;

  factory AdminProductProfitability.fromJson(Map<String, dynamic> json) => AdminProductProfitability(
        productTitle: json['productTitle'] as String,
        sku: json['sku'] as String,
        variantLabel: json['variantLabel'] as String,
        unitsSold: (json['unitsSold'] as num).toInt(),
        revenue: json['revenue'] as num,
        cost: json['cost'] as num,
        grossProfit: json['grossProfit'] as num,
      );
}

class AdminAnalytics {
  const AdminAnalytics({required this.days, required this.orderCount, required this.unitsSold, required this.revenue, required this.cost, required this.grossProfit, required this.grossMarginPercent, required this.tax, required this.netProfit, required this.shippingExpense});
  final int days;
  final int orderCount;
  final int unitsSold;
  final num revenue;
  final num cost;
  final num grossProfit;
  final num grossMarginPercent;
  final num tax;
  final num netProfit;
  final num shippingExpense;
  factory AdminAnalytics.fromJson(Map<String, dynamic> json) => AdminAnalytics(
    days: json['days'] as int,
    orderCount: json['orderCount'] as int,
    unitsSold: json['unitsSold'] as int,
    revenue: json['revenue'] as num,
    cost: json['cost'] as num,
    grossProfit: json['grossProfit'] as num,
    grossMarginPercent: json['grossMarginPercent'] as num,
    tax: (json['tax'] as num?) ?? 0,
    netProfit: (json['netProfit'] as num?) ?? ((json['grossProfit'] as num) - ((json['tax'] as num?) ?? 0)),
    shippingExpense: (json['shippingExpense'] as num?) ?? 0,
  );
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
  const AdminDashboard({required this.awaitingPayment, required this.processing, required this.shipped, required this.delivered, required this.paidRevenue, required this.todayRevenue, required this.lowStock, required this.periodDays, required this.periodOrderCount, required this.periodRevenue, required this.averageOrderValue, required this.expiringSoon, required this.newCustomers, required this.corporateNewRequests, required this.problemOrders, this.financialsVisible = true});
  final int awaitingPayment;
  final int processing;
  final int shipped;
  final int delivered;
  final num paidRevenue;
  final num todayRevenue;
  final List<LowStockItem> lowStock;
  final int periodDays;
  final int periodOrderCount;
  final num periodRevenue;
  final num averageOrderValue;
  final List<ExpiringStockItem> expiringSoon;
  final int newCustomers;
  final int corporateNewRequests;
  final int problemOrders;
  final bool financialsVisible;
  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
    awaitingPayment: json['awaitingPayment'] as int, processing: json['processing'] as int, shipped: json['shipped'] as int,
    delivered: json['delivered'] as int, paidRevenue: json['paidRevenue'] as num, todayRevenue: json['todayRevenue'] as num,
    lowStock: (json['lowStock'] as List<dynamic>? ?? const []).map((item) => LowStockItem.fromJson(item as Map<String, dynamic>)).toList(),
    periodDays: (json['periodDays'] as num?)?.toInt() ?? 1,
    periodOrderCount: (json['periodOrderCount'] as num?)?.toInt() ?? 0,
    periodRevenue: json['periodRevenue'] as num? ?? json['todayRevenue'] as num? ?? 0,
    averageOrderValue: json['averageOrderValue'] as num? ?? 0,
    expiringSoon: (json['expiringSoon'] as List<dynamic>? ?? const []).map((item) => ExpiringStockItem.fromJson(item as Map<String, dynamic>)).toList(),
    newCustomers: (json['newCustomers'] as num?)?.toInt() ?? 0,
    corporateNewRequests: (json['corporateNewRequests'] as num?)?.toInt() ?? 0,
    problemOrders: (json['problemOrders'] as num?)?.toInt() ?? 0, financialsVisible: json['financialsVisible'] as bool? ?? true);
}

class AdminDashboardHealth {
  const AdminDashboardHealth({
    required this.api,
    required this.database,
    required this.migrations,
    required this.adminAuthentication,
    required this.ready,
  });

  final String api;
  final String database;
  final String migrations;
  final String adminAuthentication;
  final bool ready;

  factory AdminDashboardHealth.fromJson(Map<String, dynamic> json) => AdminDashboardHealth(
        api: json['api'] as String? ?? 'unknown',
        database: json['database'] as String? ?? 'unknown',
        migrations: json['migrations'] as String? ?? 'unknown',
        adminAuthentication: json['adminAuthentication'] as String? ?? 'unknown',
        ready: json['ready'] as bool? ?? false,
      );
}

class DashboardWidgetPreference {
  const DashboardWidgetPreference({required this.id, required this.visible});
  final String id;
  final bool visible;
  factory DashboardWidgetPreference.fromJson(Map<String, dynamic> json) => DashboardWidgetPreference(
        id: json['id'] as String,
        visible: json['visible'] as bool? ?? true,
      );
  Map<String, dynamic> toJson() => {'id': id, 'visible': visible};
}

class DashboardPreferences {
  const DashboardPreferences(this.widgets);
  static const ids = ['metrics', 'quickActions', 'alerts', 'lowStock', 'expiring'];
  static const defaults = DashboardPreferences([
    DashboardWidgetPreference(id: 'metrics', visible: true),
    DashboardWidgetPreference(id: 'quickActions', visible: true),
    DashboardWidgetPreference(id: 'alerts', visible: true),
    DashboardWidgetPreference(id: 'lowStock', visible: true),
    DashboardWidgetPreference(id: 'expiring', visible: true),
  ]);
  final List<DashboardWidgetPreference> widgets;
  bool isVisible(String id) => widgets.any((item) => item.id == id && item.visible);
  factory DashboardPreferences.fromJson(Map<String, dynamic> json) {
    final parsed = (json['widgets'] as List<dynamic>? ?? const [])
        .map((item) => DashboardWidgetPreference.fromJson(item as Map<String, dynamic>))
        .toList();
    if (parsed.length != ids.length || parsed.map((item) => item.id).toSet().length != ids.length ||
        parsed.any((item) => !ids.contains(item.id))) return defaults;
    return DashboardPreferences(parsed);
  }
  Map<String, dynamic> toJson() => {'widgets': widgets.map((item) => item.toJson()).toList()};
  DashboardPreferences move(int from, int to) {
    final updated = [...widgets];
    final item = updated.removeAt(from);
    updated.insert(to, item);
    return DashboardPreferences(updated);
  }
  DashboardPreferences setVisible(int index, bool visible) {
    final updated = [...widgets];
    final item = updated[index];
    updated[index] = DashboardWidgetPreference(id: item.id, visible: visible);
    return DashboardPreferences(updated);
  }
}

class LowStockItem {
  const LowStockItem({required this.productTitle, required this.sku, required this.variantLabel, required this.availablePackages});
  final String productTitle;
  final String sku;
  final String variantLabel;
  final int availablePackages;
  factory LowStockItem.fromJson(Map<String, dynamic> json) => LowStockItem(productTitle: json['productTitle'] as String, sku: json['sku'] as String, variantLabel: json['variantLabel'] as String, availablePackages: json['availablePackages'] as int);
}

class ExpiringStockItem {
  const ExpiringStockItem({required this.productTitle, required this.sku, required this.variantLabel, required this.expiresAt, required this.remainingPackages});
  final String productTitle;
  final String sku;
  final String variantLabel;
  final DateTime expiresAt;
  final int remainingPackages;
  factory ExpiringStockItem.fromJson(Map<String, dynamic> json) => ExpiringStockItem(
        productTitle: json['productTitle'] as String? ?? '',
        sku: json['sku'] as String? ?? '',
        variantLabel: json['variantLabel'] as String? ?? '',
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        remainingPackages: (json['remainingPackages'] as num?)?.toInt() ?? 0,
      );
}

class InventoryPurchasePage {
  const InventoryPurchasePage(this.items, this.nextCursor);
  final List<InventoryBatch> items;
  final String? nextCursor;
}
