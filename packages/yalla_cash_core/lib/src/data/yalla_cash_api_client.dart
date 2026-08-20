import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yalla_cash_core/src/config/yalla_cash_environment.dart';
import 'package:yalla_cash_core/src/core/failure.dart';
import 'package:yalla_cash_core/src/data/auth_token_store.dart';

class YallaCashApiClient {
  YallaCashApiClient({
    required YallaCashEnvironment environment,
    required AuthTokenStore tokenStore,
    http.Client? httpClient,
  })  : _environment = environment,
        _tokenStore = tokenStore,
        _httpClient = httpClient ?? http.Client();

  final YallaCashEnvironment _environment;
  final AuthTokenStore _tokenStore;
  final http.Client _httpClient;
  AuthTokens? _memoryTokens;

  Future<AuthTokens?> get tokens async {
    if (_memoryTokens != null) return _memoryTokens;
    _memoryTokens = await _tokenStore.read();
    return _memoryTokens;
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    _memoryTokens = tokens;
    await _tokenStore.write(tokens);
  }

  Future<void> clearTokens() async {
    _memoryTokens = null;
    await _tokenStore.clear();
  }

  Future<Object?> get(
    String path, {
    Map<String, Object?>? query,
    bool authenticated = true,
  }) =>
      _send(
        'GET',
        path,
        query: query,
        authenticated: authenticated,
      );

  Future<Object?> post(
    String path, {
    Map<String, Object?>? body,
    Map<String, Object?>? query,
    bool authenticated = true,
  }) =>
      _send(
        'POST',
        path,
        body: body,
        query: query,
        authenticated: authenticated,
      );

  Future<Object?> patch(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) =>
      _send(
        'PATCH',
        path,
        body: body,
        authenticated: authenticated,
      );

  Future<Object?> delete(String path) => _send('DELETE', path);

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    Map<String, Object?>? query,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['accept'] = 'application/json';
    request.headers['content-type'] = 'application/json';

    if (authenticated) {
      final saved = await tokens;
      if (saved?.accessToken case final token?) {
        request.headers['authorization'] = 'Bearer $token';
      }
    }

    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed =
          await _httpClient.send(request).timeout(_environment.apiTimeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 401 && authenticated && retryOnUnauthorized) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          return await _send(
            method,
            path,
            body: body,
            query: query,
            authenticated: authenticated,
            retryOnUnauthorized: false,
          );
        }
      }
      return _decodeResponse(response);
    } on TimeoutException {
      throw const YallaCashFailure(
        code: 'request_timeout',
        message: 'انتهت مهلة الاتصال بالخادم.',
      );
    } on SocketException {
      throw const YallaCashFailure(
        code: 'network_unavailable',
        message: 'تعذر الاتصال بالخادم. تحقق من اتصال الإنترنت.',
      );
    } on http.ClientException catch (error) {
      throw YallaCashFailure(
        code: 'network_error',
        message: error.message,
        details: error,
      );
    }
  }

  Future<bool> _refreshToken() async {
    final saved = await tokens;
    if (saved == null) return false;
    try {
      final response = await post(
        '/auth/refresh',
        body: {'refreshToken': saved.refreshToken},
        authenticated: false,
      );
      final json = apiMap(response);
      final tokens = _tokensFromAuthResponse(json);
      await saveTokens(tokens);
      return true;
    } on YallaCashFailure {
      await clearTokens();
      return false;
    }
  }

  Object? _decodeResponse(http.Response response) {
    final raw =
        response.bodyBytes.isEmpty ? '' : utf8.decode(response.bodyBytes);
    final decoded = raw.isEmpty ? null : jsonDecode(raw);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    if (decoded is Map<String, Object?>) {
      throw YallaCashFailure(
        statusCode: response.statusCode,
        code: decoded['code']?.toString() ?? 'request_failed',
        message: decoded['message']?.toString() ?? 'فشل الطلب.',
        details: decoded['details'],
      );
    }

    throw YallaCashFailure(
      statusCode: response.statusCode,
      code: 'request_failed',
      message: 'فشل الطلب.',
      details: raw,
    );
  }

  Uri _uri(String path, Map<String, Object?>? query) {
    final base = _environment.apiBaseUrl;
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final childPath = path.startsWith('/') ? path : '/$path';
    final queryParameters = <String, String>{};
    query?.forEach((key, value) {
      if (value != null) queryParameters[key] = value.toString();
    });
    return base.replace(
      path: '$basePath$childPath',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }
}

Map<String, Object?> apiMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw const YallaCashFailure(
    code: 'invalid_response',
    message: 'استجابة الخادم غير متوقعة.',
  );
}

List<Map<String, Object?>> apiItems(Object? value) {
  final map = apiMap(value);
  final items = map['items'];
  if (items is List) {
    return items.map((item) => apiMap(item)).toList(growable: false);
  }
  throw const YallaCashFailure(
    code: 'invalid_response',
    message: 'استجابة الخادم لا تحتوي على قائمة صالحة.',
  );
}

AuthTokens authTokensFromResponse(Map<String, Object?> json) =>
    _tokensFromAuthResponse(json);

AuthTokens _tokensFromAuthResponse(Map<String, Object?> json) {
  final expires = json['expiresInSeconds'] as int? ?? 900;
  return AuthTokens(
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
    expiresAt: DateTime.now().add(Duration(seconds: expires)),
  );
}
