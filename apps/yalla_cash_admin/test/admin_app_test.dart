import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_cash_admin/src/admin_app.dart';

void main() {
  testWidgets('admin dashboard shows the overview metrics', (tester) async {
    await tester.pumpWidget(const YallaCashAdminApp(skipLogin: true));
    await tester.pumpAndSettle();

    expect(find.text('نظرة عامة'), findsWidgets);
    expect(find.text('دخل المنصة'), findsOneWidget);
    expect(find.text('طلبات كاش معلقة'), findsOneWidget);
  });
}
