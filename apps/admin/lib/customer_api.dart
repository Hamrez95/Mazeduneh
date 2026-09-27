import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl;

class CustomerApiException implements Exception {
  CustomerApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CustomerApiClient {
  CustomerApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;

  Map<String, String> _headers() {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) {
      throw CustomerApiException('نشست شما منقضی شده است.', statusCode: 401);
    }
    return {'authorization': 'Bearer $token'};
  }

  Future<List<CustomerSummary>> fetchCustomers() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/customers/'),
      headers: _headers(),
    );
    _guard(response);
    if (response.statusCode != 200) {
      throw CustomerApiException(_message(response), statusCode: response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded
        .map((item) => CustomerSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerSummary> fetchCustomer(String id) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/admin/customers/$id'),
      headers: _headers(),
    );
    _guard(response);
    if (response.statusCode != 200) {
      throw CustomerApiException(_message(response), statusCode: response.statusCode);
    }
    return CustomerSummary.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  void _guard(http.Response response) {
    if (response.statusCode == 401) {
      OwnerSession.instance.clear();
      throw CustomerApiException(
        'نشست شما منقضی شده است؛ دوباره وارد شوید.',
        statusCode: 401,
      );
    }
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['message'] is String) {
        return body['message'] as String;
      }
    } catch (_) {}
    return 'ارتباط با سرور با خطا مواجه شد (${response.statusCode}).';
  }
}

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.fullName,
    required this.mobile,
    required this.normalizedMobile,
    required this.marketingConsent,
    required this.createdAt,
    required this.updatedAt,
    required this.orderCount,
    this.addresses = const [],
  });

  final String id;
  final String fullName;
  final String mobile;
  final String normalizedMobile;
  final bool marketingConsent;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int orderCount;
  final List<CustomerAddress> addresses;

  factory CustomerSummary.fromJson(Map<String, dynamic> json) => CustomerSummary(
        id: json['id'].toString(),
        fullName: json['fullName'] as String? ?? 'مشتری بدون نام',
        mobile: json['mobile'] as String? ?? '',
        normalizedMobile: json['normalizedMobile'] as String? ?? '',
        marketingConsent: json['marketingConsent'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
        addresses: (json['addresses'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CustomerAddress.fromJson)
            .toList(),
      );
}

class CustomerAddress {
  const CustomerAddress({
    required this.province,
    required this.city,
    required this.address,
    required this.postalCode,
    required this.isDefault,
    required this.lastUsedAt,
  });

  final String province;
  final String city;
  final String address;
  final String postalCode;
  final bool isDefault;
  final DateTime lastUsedAt;

  factory CustomerAddress.fromJson(Map<String, dynamic> json) => CustomerAddress(
        province: json['province'] as String? ?? '',
        city: json['city'] as String? ?? '',
        address: json['address'] as String? ?? '',
        postalCode: json['postalCode'] as String? ?? '',
        isDefault: json['isDefault'] as bool? ?? false,
        lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      );
}
