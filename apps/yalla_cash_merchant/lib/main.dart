import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';
import 'package:yalla_cash_merchant/src/merchant_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Release builds must pin the SHARED backend explicitly via
  // --dart-define=YALLA_CASH_API_BASE_URL=... Debug/local runs fall back to
  // the platform-aware default from YallaCashEnvironment (localhost:3000,
  // or 10.0.2.2:3000 inside an Android emulator). The previous hardcoded
  // production fallback was removed so this app can never silently target a
  // different backend than the admin/customer apps.
  const configuredBaseUrl =
      String.fromEnvironment(YallaCashEnvironment.baseUrlEnvKey);
  if (kReleaseMode && configuredBaseUrl.isEmpty) {
    throw StateError(
      'YALLA_CASH_API_BASE_URL must be provided for release builds.',
    );
  }
  // The app widget builds its runtime through the SHARED
  // YallaCashEnvironment resolver (see _merchantProductionRuntime), so all
  // three apps resolve the same backend base URL.
  runApp(const YallaCashMerchantApp());
}
