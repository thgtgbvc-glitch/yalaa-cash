import 'package:flutter/material.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';
import 'package:yalla_cash_customer/src/customer_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = YallaCashRuntime.fromEnvironment();
  runApp(YallaCashCustomerApp(runtime: runtime));
}
