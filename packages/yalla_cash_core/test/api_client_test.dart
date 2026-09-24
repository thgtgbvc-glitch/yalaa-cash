import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_cash_core/src/config/yalla_cash_environment.dart';
import 'package:yalla_cash_core/src/data/auth_token_store.dart';
import 'package:yalla_cash_core/src/data/yalla_cash_api_client.dart';

void main() {
  test('reports no saved session without local tokens', () async {
    final client = YallaCashApiClient(
      environment: YallaCashEnvironment(
        apiBaseUrl: Uri.parse('http://localhost:3000'),
        useRemoteBackend: true,
      ),
      tokenStore: _ReadNullTokenStore(),
      httpClient: MockClient((_) async => http.Response('', 500)),
    );

    expect(await client.hasSavedSession(), isFalse);
  });

  test('uses just-saved tokens for the next authenticated request', () async {
    final tokenStore = _ReadNullTokenStore();
    String? authorization;
    final client = YallaCashApiClient(
      environment: YallaCashEnvironment(
        apiBaseUrl: Uri.parse('http://localhost:3000'),
        useRemoteBackend: true,
      ),
      tokenStore: tokenStore,
      httpClient: MockClient((request) async {
        authorization = request.headers['authorization'];
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final tokens = AuthTokens(
      accessToken: 'fresh-access',
      refreshToken: 'fresh-refresh',
      expiresAt: DateTime.utc(2030),
    );

    await client.saveTokens(tokens);
    await client.get('/merchant/me');

    expect(authorization, 'Bearer fresh-access');
    expect(tokenStore.written, same(tokens));
  });

  test('refreshes an expired access token and retries the request', () async {
    final tokenStore = _ReadNullTokenStore();
    final paths = <String>[];
    final client = YallaCashApiClient(
      environment: YallaCashEnvironment(
        apiBaseUrl: Uri.parse('http://localhost:3000'),
        useRemoteBackend: true,
      ),
      tokenStore: tokenStore,
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/auth/refresh') {
          return http.Response(
            jsonEncode({
              'accessToken': 'rotated-access',
              'refreshToken': 'rotated-refresh',
              'expiresInSeconds': 900,
            }),
            200,
          );
        }
        if (request.headers['authorization'] == 'Bearer expired-access') {
          return http.Response('{}', 401);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
    await client.saveTokens(
      AuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'usable-refresh',
        expiresAt: DateTime.utc(2020),
      ),
    );

    await client.get('/customer/profile');

    expect(paths, [
      '/customer/profile',
      '/auth/refresh',
      '/customer/profile',
    ]);
    expect(tokenStore.written?.accessToken, 'rotated-access');
  });
}

class _ReadNullTokenStore implements AuthTokenStore {
  AuthTokens? written;

  @override
  Future<void> clear() async {
    written = null;
  }

  @override
  Future<AuthTokens?> read() async => null;

  @override
  Future<void> write(AuthTokens tokens) async {
    written = tokens;
  }
}
