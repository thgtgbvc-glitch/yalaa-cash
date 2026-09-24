import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';

void main() {
  test('restore skips profile request when no session is saved', () async {
    final store = YallaCashStore.demo();
    final repository = _RestoreRepository(store, hasSession: false);
    final cubit = CustomerAppCubit(repository);
    addTearDown(cubit.close);

    await cubit.restoreSession();

    expect(repository.profileRequests, 0);
    expect(cubit.state.customer, isNull);
    expect(cubit.state.status, LoadStatus.initial);
  });

  test('restore validates profile when a session is saved', () async {
    final store = YallaCashStore.demo()..loginDemoCustomer();
    final repository = _RestoreRepository(store, hasSession: true);
    final cubit = CustomerAppCubit(repository);
    addTearDown(cubit.close);

    await cubit.restoreSession();

    expect(repository.profileRequests, 1);
    expect(cubit.state.customer, isNotNull);
  });
}

class _RestoreRepository extends InMemoryYallaCashRepository {
  _RestoreRepository(super.store, {required this.hasSession});

  final bool hasSession;
  var profileRequests = 0;

  @override
  Future<bool> hasSavedSession() async => hasSession;

  @override
  Future<Customer> getCustomerProfile() {
    profileRequests += 1;
    return super.getCustomerProfile();
  }
}
