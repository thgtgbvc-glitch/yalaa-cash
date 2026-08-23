import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yalla_cash_admin/src/admin_app.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const configuredBaseUrl = String.fromEnvironment('YALLA_CASH_API_BASE_URL');
  if (kReleaseMode && configuredBaseUrl.isEmpty) {
    throw StateError(
      'YALLA_CASH_API_BASE_URL must be provided for release builds.',
    );
  }
  final baseUrl =
      configuredBaseUrl.isEmpty ? 'http://localhost:3000' : configuredBaseUrl;
  final runtime = YallaCashRuntime.fromEnvironment(
    environment: YallaCashEnvironment(
      apiBaseUrl: Uri.parse(baseUrl),
      useRemoteBackend: true,
    ),
  );
  runApp(YallaCashAdminApp(runtime: runtime));
}
