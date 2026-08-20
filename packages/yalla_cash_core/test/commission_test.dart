import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';

void main() {
  group('CommissionCalculator', () {
    test('splits commission and converts customer share to points', () {
      final result = CommissionCalculator.calculate(
        invoiceAmountSyp: 100000,
        commissionRate: 10,
        pointValueSyp: 5,
      );

      expect(result.commissionAmountSyp, 10000);
      expect(result.customerShareSyp, 5000);
      expect(result.platformRevenueSyp, 5000);
      expect(result.customerPoints, 1000);
    });

    test('rejects invalid amounts', () {
      expect(
        () => CommissionCalculator.calculate(
          invoiceAmountSyp: 0,
          commissionRate: 5,
          pointValueSyp: 5,
        ),
        throwsArgumentError,
      );
    });
  });
}
