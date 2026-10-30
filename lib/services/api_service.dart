import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.type = ApiExceptionType.server,
  });

  final String message;
  final int? statusCode;
  final ApiExceptionType type;

  bool get isNetwork => type == ApiExceptionType.network;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

enum ApiExceptionType { network, unauthorized, server, badResponse }

class ApiService {
  ApiService({http.Client? client, this.baseUrl = ApiConfig.baseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  static const _tokenKey = 'wordrise_api_token';

  Future<String?> get token async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, value);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) {
    return _send('GET', path, query: query, timeout: timeout);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) {
    return _send('POST', path, body: body, timeout: timeout);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) {
    return _send('PUT', path, body: body, timeout: timeout);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) {
    return _send('DELETE', path, body: body ?? {}, timeout: timeout);
  }

  Future<Map<String, dynamic>> uploadMultipartBytes(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required Uint8List bytes,
    required String filename,
    String? contentType,
    void Function(double progress)? onProgress,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final currentToken = await token;
    final length = bytes.length;
    var uploaded = 0;
    Stream<List<int>> trackedBytes() async* {
      const chunkSize = 64 * 1024;
      for (var offset = 0; offset < length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, length);
        final chunk = Uint8List.sublistView(bytes, offset, end);
        uploaded = end;
        onProgress?.call(length == 0 ? 0 : uploaded / length);
        yield chunk;
      }
    }

    final mediaType = contentType == null
        ? null
        : _multipartContentType(contentType);
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (currentToken != null) 'Authorization': 'Bearer $currentToken',
      })
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile(
          fileField,
          http.ByteStream(trackedBytes()),
          length,
          filename: filename,
          contentType: mediaType,
        ),
      );

    late final http.Response response;
    try {
      response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout ?? const Duration(seconds: 35));
      onProgress?.call(1);
    } on TimeoutException {
      throw const ApiException(
        'Internet aloqasi sekin yoki server javob bermayapti.',
        type: ApiExceptionType.network,
      );
    } on http.ClientException {
      throw const ApiException(
        'Internet aloqasini tekshiring. Maʼlumotlar yuklanmadi.',
        type: ApiExceptionType.network,
      );
    } on Object catch (error) {
      if (_looksLikeNetworkError(error)) {
        throw const ApiException(
          'Internet aloqasini tekshiring. Maʼlumotlar yuklanmadi.',
          type: ApiExceptionType.network,
        );
      }
      throw const ApiException(
        'Faylni yuborib bo‘lmadi. Keyinroq qayta urinib ko‘ring.',
      );
    }

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final currentToken = await token;
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (currentToken != null) 'Authorization': 'Bearer $currentToken',
    };

    late final http.Response response;
    try {
      response = await switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
        'PUT' => _client.put(uri, headers: headers, body: jsonEncode(body)),
        'DELETE' => _client.delete(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        _ => throw ApiException('Unsupported method $method'),
      }.timeout(timeout ?? const Duration(seconds: 12));
    } on TimeoutException {
      throw const ApiException(
        'Internet aloqasi sekin yoki server javob bermayapti.',
        type: ApiExceptionType.network,
      );
    } on http.ClientException {
      throw const ApiException(
        'Internet aloqasini tekshiring. Maʼlumotlar yuklanmadi.',
        type: ApiExceptionType.network,
      );
    } on Object catch (error) {
      if (_looksLikeNetworkError(error)) {
        throw const ApiException(
          'Internet aloqasini tekshiring. Maʼlumotlar yuklanmadi.',
          type: ApiExceptionType.network,
        );
      }
      throw const ApiException(
        'Kutilmagan xatolik yuz berdi. Keyinroq qayta urinib ko‘ring.',
      );
    }

    return _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException(
        'Serverdan noto‘g‘ri javob keldi. Keyinroq qayta urinib ko‘ring.',
        type: ApiExceptionType.badResponse,
      );
    }
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] == false) {
      throw ApiException(
        payload['message']?.toString() ?? 'API error',
        statusCode: response.statusCode,
        type: response.statusCode == 401 || response.statusCode == 403
            ? ApiExceptionType.unauthorized
            : ApiExceptionType.server,
      );
    }

    return payload['data'] is Map<String, dynamic>
        ? payload['data'] as Map<String, dynamic>
        : <String, dynamic>{};
  }
}

MediaType? _multipartContentType(String value) {
  final parts = value.split('/');
  if (parts.length != 2 || parts.any((part) => part.trim().isEmpty)) {
    return null;
  }
  return MediaType(parts[0].trim(), parts[1].trim());
}

bool _looksLikeNetworkError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('no address associated') ||
      text.contains('network is unreachable') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('connection closed');
}
