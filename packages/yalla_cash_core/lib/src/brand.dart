import 'package:flutter/material.dart';

/// Official Yalla Cash artwork shared by the customer, merchant and admin apps.
class YallaCashLogo extends StatelessWidget {
  const YallaCashLogo({
    super.key,
    this.height = 96,
    this.markOnly = false,
    this.color,
  });

  final double height;
  final bool markOnly;
  final Color? color;

  @override
  Widget build(BuildContext context) => Image.asset(
        markOnly
            ? 'assets/images/yalla_cash_mark.png'
            : 'assets/images/yalla_cash_logo.png',
        package: 'yalla_cash_core',
        height: height,
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: color == null ? null : BlendMode.srcIn,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Yalla Cash',
      );
}
