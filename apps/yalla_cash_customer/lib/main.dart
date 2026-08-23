import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';
import 'package:yalla_cash_customer/src/customer_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const configuredBaseUrl = String.fromEnvironment('YALLA_CASH_API_BASE_URL');
  if (kReleaseMode && configuredBaseUrl.isEmpty) {
    throw StateError(
      'YALLA_CASH_API_BASE_URL must be provided for release builds.',
    );
  }
  final baseUrl =
      configuredBaseUrl.isEmpty ? 'http://10.0.2.2:3000' : configuredBaseUrl;
  final runtime = YallaCashRuntime.fromEnvironment(
    environment: YallaCashEnvironment(
      apiBaseUrl: Uri.parse(baseUrl),
      useRemoteBackend: true,
    ),
  );
  runApp(YallaCashCustomerApp(runtime: runtime));
}
