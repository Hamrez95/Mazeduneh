import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_session.dart';

const defaultApiBaseUrl = String.fromEnvironment(
  'MAZEDUNEH_API_BASE_URL',
  defaultValue: 'http://localhost:5000',
);

class CatalogApiException implements Exception {
  CatalogApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CatalogApiClient {
  CatalogApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final String baseUrl;

  Map<String, String> _headers({bool json = false}) {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) throw CatalogApiException('نشست شما منقضی شده است.', statusCode: 401);
    return {
      'authorization': 'Bearer $token',
      if (json) 'content-type': 'application/json; charset=utf-8',
    };
  }

  Future<List<Product>> fetchProducts({bool includeDrafts = true}) async {
    final path = includeDrafts ? '/api/v1/products/admin' : '/api/v1/products/';
    final response = await _client.get(Uri.parse('$baseUrl$path'), headers: includeDrafts ? _headers() : null);
    _guardUnauthorized(response);
    if (response.statusCode != 200) {
      throw CatalogApiException(_message(response), statusCode: response.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Product> createProduct(CreateProductCommand command) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/products/'),
      headers: _headers(json: true),
      body: jsonEncode(command.toJson()),
    );
    _guardUnauthorized(response);
    if (response.statusCode != 201) {
      throw CatalogApiException(_message(response), statusCode: response.statusCode);
    }
    return Product.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> setPublication(String slug, bool isPublished) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/api/v1/products/$slug/publication'),
      headers: _headers(json: true),
      body: jsonEncode({'isPublished': isPublished}),
    );
    _guardUnauthorized(response);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CatalogApiException(_message(response), statusCode: response.statusCode);
    }
  }

  void _guardUnauthorized(http.Response response) {
    if (response.statusCode == 401) {
      OwnerSession.instance.clear();
      throw CatalogApiException('نشست شما منقضی شده است؛ دوباره وارد شوید.', statusCode: 401);
    }
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic>) {
        if (body['message'] is String) return body['message'] as String;
        if (body['errors'] is Map) {
          final errors = body['errors'] as Map;
          return errors.values.expand((value) => value is List ? value : const []).join('، ');
        }
      }
    } catch (_) {}
    return 'ارتباط با سرور با خطا مواجه شد (${response.statusCode}).';
  }
}

class Product {
  const Product({required this.id, required this.title, required this.slug, required this.category, required this.origin, required this.unitType, required this.isPublished, required this.variants});
  final String id;
  final String title;
  final String slug;
  final String category;
  final String origin;
  final String unitType;
  final bool isPublished;
  final List<ProductVariant> variants;
  int get totalStock => variants.fold(0, (sum, item) => sum + item.availablePackages);
  bool get isWeight => unitType.toLowerCase() == 'weight';

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'].toString(), title: json['title'] as String, slug: json['slug'] as String,
        category: json['category'] as String, origin: json['origin'] as String,
        unitType: json['unitType'].toString(), isPublished: json['isPublished'] as bool? ?? false,
        variants: (json['variants'] as List<dynamic>).map((item) => ProductVariant.fromJson(item as Map<String, dynamic>)).toList(),
      );
}

class ProductVariant {
  const ProductVariant({required this.sku, required this.quantity, required this.displayLabel, required this.price, required this.availablePackages});
  final String sku;
  final num quantity;
  final String displayLabel;
  final num price;
  final int availablePackages;
  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        sku: json['sku'] as String, quantity: json['quantity'] as num, displayLabel: json['displayLabel'] as String,
        price: json['price'] as num, availablePackages: json['availablePackages'] as int,
      );
}

class CreateProductCommand {
  const CreateProductCommand({required this.title, required this.slug, required this.category, required this.origin, required this.unitType, required this.variants, this.isPublished = false});
  final String title;
  final String slug;
  final String category;
  final String origin;
  final String unitType;
  final List<CreateVariantCommand> variants;
  final bool isPublished;
  Map<String, dynamic> toJson() => {
        'title': title, 'slug': slug, 'category': category, 'origin': origin, 'currency': 'IRR',
        'unitType': unitType, 'isPublished': isPublished, 'variants': variants.map((item) => item.toJson()).toList(),
      };
}

class CreateVariantCommand {
  const CreateVariantCommand({required this.sku, required this.quantity, required this.displayLabel, required this.price, required this.availablePackages});
  final String sku;
  final num quantity;
  final String displayLabel;
  final num price;
  final int availablePackages;
  Map<String, dynamic> toJson() => {'sku': sku, 'quantity': quantity, 'displayLabel': displayLabel, 'price': price, 'availablePackages': availablePackages};
}
