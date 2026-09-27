import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_session.dart';
import 'catalog_api.dart' show defaultApiBaseUrl;

class MediaApiException implements Exception {
  MediaApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class MediaAsset {
  const MediaAsset({required this.fileName, required this.url, required this.contentType, required this.sizeBytes});
  final String fileName;
  final String url;
  final String contentType;
  final int sizeBytes;
  factory MediaAsset.fromJson(Map<String, dynamic> json) => MediaAsset(
    fileName: json['fileName'] as String,
    url: json['url'] as String,
    contentType: json['contentType'] as String,
    sizeBytes: (json['sizeBytes'] as num).toInt(),
  );
}

class MediaApiClient {
  MediaApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceFirst(RegExp(r'/$'), '');
  final http.Client _client;
  final String baseUrl;

  Future<MediaAsset> uploadImage({
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    final token = OwnerSession.instance.bearerToken;
    if (token == null) throw MediaApiException('نشست شما منقضی شده است.', statusCode: 401);
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/v1/admin/media'))
      ..headers['authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName, contentType: _contentType(contentType)));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 401) {
      OwnerSession.instance.clear();
      throw MediaApiException('نشست شما منقضی شده است؛ دوباره وارد شوید.', statusCode: 401);
    }
    if (response.statusCode != 201) {
      try {
        final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        throw MediaApiException(body['message'] as String? ?? 'آپلود تصویر انجام نشد.', statusCode: response.statusCode);
      } catch (exception) {
        if (exception is MediaApiException) rethrow;
        throw MediaApiException('آپلود تصویر انجام نشد.', statusCode: response.statusCode);
      }
    }
    return MediaAsset.fromJson(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  }

  MediaType? _contentType(String value) {
    final parts = value.split('/');
    return parts.length == 2 ? MediaType(parts[0], parts[1]) : null;
  }
}
