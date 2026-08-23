import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';

void main() {
  test('invoice credits the scanned customer using the store rate snapshot',
      () {
    final store = YallaCashStore.demo()..loginDemoCustomer();
    final customer = store.currentCustomer!;
    final balanceBefore = customer.pointsBalance;

    final transaction = store.registerInvoice(
      customerId: customer.id,
      storeId: 'store-001',
      amountSyp: 100000,
    );

    expect(transaction.commissionRateSnapshot, 6.7);
    expect(transaction.commissionAmountSyp, 6700);
    expect(transaction.customerPointsEarned, 670);
    expect(store.currentCustomer!.pointsBalance, balanceBefore + 670);
  });

  test('pending cash request reduces available points without changing balance',
      () {
    final store = YallaCashStore.demo()..loginDemoCustomer();
    final customer = store.currentCustomer!;
    final balanceBefore = customer.pointsBalance;

    store.requestCashRedemption(customerId: customer.id, points: 500);

    expect(store.currentCustomer!.pointsBalance, balanceBefore);
    expect(store.availablePoints(customer.id), balanceBefore - 500);
  });

  test('QR parser only accepts known Yalla Cash customers', () {
    final store = YallaCashStore.demo();
    expect(store.customerIdFromQr(store.customerQrPayload('cust-001')),
        'cust-001');
    expect(store.customerIdFromQr('https://example.com/customer/cust-001'),
        isNull);
  });

  test('admin can settle a pending cash request', () {
    final store = YallaCashStore.demo();
    final request = store.cashRequests.single;
    final balanceBefore = store.customerById(request.customerId).pointsBalance;

    store.settleCashRequest(request.id);

    expect(store.cashRequests.single.status, CashRequestStatus.settled);
    expect(
      store.customerById(request.customerId).pointsBalance,
      balanceBefore - request.pointsRequested,
    );
  });

  test('governorate targeted banners only appear for matching governorate',
      () async {
    final store = YallaCashStore.demo();
    final repository = InMemoryYallaCashRepository(store);

    final idlibBanners = await repository.listActiveBanners(
      placement: 'HOME',
      governorateId: 'gov-idlib',
    );
    final damascusBanners = await repository.listActiveBanners(
      placement: 'HOME',
      governorateId: 'gov-damascus',
    );

    expect(idlibBanners.map((banner) => banner.id), contains('banner-001'));
    expect(damascusBanners.map((banner) => banner.id),
        isNot(contains('banner-001')));
    expect(damascusBanners.map((banner) => banner.id), contains('banner-002'));
  });

  test('admin can delete a banner from the repository', () async {
    final store = YallaCashStore.demo();
    final repository = InMemoryYallaCashRepository(store);

    await repository.deleteBanner('banner-001');

    final banners = await repository.listAdminBanners();
    expect(banners.map((banner) => banner.id), isNot(contains('banner-001')));
  });
}
