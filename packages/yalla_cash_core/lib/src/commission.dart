class CommissionResult {
  const CommissionResult({
    required this.invoiceAmountSyp,
    required this.commissionRate,
    required this.commissionAmountSyp,
    required this.platformRevenueSyp,
    required this.customerShareSyp,
    required this.customerPoints,
    required this.pointValueSyp,
  });

  final int invoiceAmountSyp;
  final double commissionRate;
  final int commissionAmountSyp;
  final int platformRevenueSyp;
  final int customerShareSyp;
  final int customerPoints;
  final int pointValueSyp;
}

class CommissionCalculator {
  const CommissionCalculator._();

  static CommissionResult calculate({
    required int invoiceAmountSyp,
    required double commissionRate,
    required int pointValueSyp,
  }) {
    if (invoiceAmountSyp <= 0) {
      throw ArgumentError.value(invoiceAmountSyp, 'invoiceAmountSyp');
    }
    if (commissionRate < 0 || commissionRate > 100) {
      throw ArgumentError.value(commissionRate, 'commissionRate');
    }
    if (pointValueSyp <= 0) {
      throw ArgumentError.value(pointValueSyp, 'pointValueSyp');
    }

    final commission = (invoiceAmountSyp * commissionRate / 100).round();
    final customerShare = (commission / 2).round();
    final platformShare = commission - customerShare;
    final points = (customerShare / pointValueSyp).round();

    return CommissionResult(
      invoiceAmountSyp: invoiceAmountSyp,
      commissionRate: commissionRate,
      commissionAmountSyp: commission,
      platformRevenueSyp: platformShare,
      customerShareSyp: customerShare,
      customerPoints: points,
      pointValueSyp: pointValueSyp,
    );
  }
}
