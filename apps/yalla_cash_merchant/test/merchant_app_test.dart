import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';
import 'package:yalla_cash_merchant/src/merchant_app.dart';

void main() {
  testWidgets('merchant can sign in with injected test credentials',
      (tester) async {
    final store = YallaCashStore.demo();
    await tester.pumpWidget(YallaCashMerchantApp(store: store));

    await tester.enterText(
        find.byKey(const Key('merchant-email')), 'wasim@yallacash.app');
    await tester.enterText(
        find.byKey(const Key('merchant-password')), '123456');
    await tester.tap(find.byKey(const Key('merchant-login')));
    await tester.pumpAndSettle();

    expect(find.textContaining('العمولة المستحقة'), findsOneWidget);
    expect(find.text('بدء عملية جديدة'), findsOneWidget);
  });
}
