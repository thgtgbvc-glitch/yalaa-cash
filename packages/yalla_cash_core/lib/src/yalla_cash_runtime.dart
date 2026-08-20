import 'package:http/http.dart' as http;
import 'package:yalla_cash_core/src/config/yalla_cash_environment.dart';
import 'package:yalla_cash_core/src/data/auth_token_store.dart';
import 'package:yalla_cash_core/src/data/in_memory_yalla_cash_repository.dart';
import 'package:yalla_cash_core/src/data/remote_yalla_cash_repository.dart';
import 'package:yalla_cash_core/src/data/yalla_cash_api_client.dart';
import 'package:yalla_cash_core/src/domain/yalla_cash_repository.dart';
import 'package:yalla_cash_core/src/in_memory_store.dart';
import 'package:yalla_cash_core/src/presentation/yalla_cash_cubits.dart';

class YallaCashRuntime {
  YallaCashRuntime._({
    required this.environment,
    required this.repository,
    this.demoStore,
  });

  factory YallaCashRuntime.fromEnvironment({
    YallaCashEnvironment? environment,
    AuthTokenStore? tokenStore,
    http.Client? httpClient,
  }) {
    final resolved = environment ?? YallaCashEnvironment.fromEnvironment();
    if (resolved.useRemoteBackend) {
      return YallaCashRuntime._(
        environment: resolved,
        repository: RemoteYallaCashRepository(
          YallaCashApiClient(
            environment: resolved,
            tokenStore: tokenStore ?? const SecureAuthTokenStore(),
            httpClient: httpClient,
          ),
        ),
      );
    }

    final store = YallaCashStore.demo();
    return YallaCashRuntime._(
      environment: resolved,
      repository: InMemoryYallaCashRepository(store),
      demoStore: store,
    );
  }

  final YallaCashEnvironment environment;
  final YallaCashRepository repository;
  final YallaCashStore? demoStore;

  CustomerAppCubit customerCubit() => CustomerAppCubit(repository);
  MerchantAppCubit merchantCubit() => MerchantAppCubit(repository);
  AdminAppCubit adminCubit() => AdminAppCubit(repository);

  void dispose() {
    demoStore?.dispose();
  }
}
