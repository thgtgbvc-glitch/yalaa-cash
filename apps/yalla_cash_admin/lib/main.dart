import 'package:flutter/material.dart';
import 'package:yalla_cash_admin/src/admin_app.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment(
    'YALLA_CASH_API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  final runtime = YallaCashRuntime.fromEnvironment(
    environment: YallaCashEnvironment(
      apiBaseUrl: Uri.parse(baseUrl),
      useRemoteBackend: true,
    ),
  );
  runApp(YallaCashAdminApp(runtime: runtime));
}
