import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yalla_cash_core/src/config/yalla_cash_environment.dart';
import 'package:yalla_cash_core/src/data/auth_token_store.dart';
import 'package:yalla_cash_core/src/data/yalla_cash_api_client.dart';

void main() {
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
