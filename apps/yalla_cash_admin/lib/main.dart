import 'package:flutter/material.dart';
import 'package:yalla_cash_admin/src/admin_app.dart';
import 'package:yalla_cash_core/yalla_cash_core.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = YallaCashRuntime.fromEnvironment();
  runApp(YallaCashAdminApp(runtime: runtime));
}
