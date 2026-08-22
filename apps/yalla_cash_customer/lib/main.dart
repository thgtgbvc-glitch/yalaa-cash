import 'package:flutter/material.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';
import 'package:yalla_cash_customer/src/customer_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment(
    'YALLA_CASH_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
  final runtime = YallaCashRuntime.fromEnvironment(
    environment: YallaCashEnvironment(
      apiBaseUrl: Uri.parse(baseUrl),
      useRemoteBackend: true,
    ),
  );
  runApp(YallaCashCustomerApp(runtime: runtime));
}
