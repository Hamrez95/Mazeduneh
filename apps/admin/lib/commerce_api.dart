import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl;

class CommerceApiException implements Exception {
  CommerceApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class ShippingMethod {
  ShippingMethod({required this.code, required this.title, required this.price, required this.freeAbove, required this.isActive, required this.internalCost});
  String code;
  String title;
  num price;
  num freeAbove;
  bool isActive;
  num internalCost;

  factory ShippingMethod.fromJson(Map<String, dynamic> json) => ShippingMethod(
    code: json['code'] as String? ?? '',
    title: json['title'] as String? ?? '',
    price: json['price'] as num? ?? 0,
    freeAbove: json['freeAbove'] as num? ?? 0,
    isActive: json['isActive'] as bool? ?? true,
    internalCost: json['internalCost'] as num? ?? 0,
  );

  Map<String, dynamic> toJson() => {'code': code, 'title': title, 'price': price, 'freeAbove': freeAbove, 'isActive': isActive, 'internalCost': internalCost};
}

class CommerceSettings {
  CommerceSettings({required this.taxRatePercent, required this.shippingMethods, this.updatedAt});
  num taxRatePercent;
  List<ShippingMethod> shippingMethods;
  DateTime? updatedAt;

  factory CommerceSettings.fromJson(Map<String, dynamic> json) => CommerceSettings(
    taxRatePercent: json['taxRatePercent'] as num? ?? 0,
    shippingMethods: (json['shippingMethods'] as List<dynamic>? ?? const [])
      .map((item) => ShippingMethod.fromJson(item as Map<String, dynamic>)).toList(),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'taxRatePercent': taxRatePercent,
    'shippingMethods': shippingMethods.map((item) => item.toJson()).toList(),
  };
}

class CommerceApiClient {
  CommerceApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), '');
  final http.Client _client;
  final String baseUrl;

  Map<String, String> _headers() {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) throw CommerceApiException('نشست شما منقضی شده است.', statusCode: 401);
    return {'authorization': 'Bearer $token'};
  }

  Future<CommerceSettings> fetchSettings() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/admin/commerce/settings'), headers: _headers());
    _guard(response);
    if (response.statusCode != 200) throw CommerceApiException(_message(response), statusCode: response.statusCode);
    return CommerceSettings.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<CommerceSettings> updateSettings(CommerceSettings settings, {required String stepUpToken}) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/v1/admin/commerce/settings'),
      headers: {..._headers(), 'content-type': 'application/json; charset=utf-8', 'x-admin-step-up': stepUpToken},
      body: jsonEncode(settings.toJson()),
    );
    _guard(response);
    if (response.statusCode != 200) throw CommerceApiException(_message(response), statusCode: response.statusCode);
    return CommerceSettings.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  void _guard(http.Response response) {
    if (response.statusCode == 401) {
      OwnerSession.instance.clear();
      throw CommerceApiException('نشست شما منقضی شده است؛ دوباره وارد شوید.', statusCode: 401);
    }
  }

  String _message(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic> && value['message'] is String) return value['message'] as String;
    } catch (_) {}
    return 'ارتباط با سرور با خطا مواجه شد (${response.statusCode}).';
  }
}
