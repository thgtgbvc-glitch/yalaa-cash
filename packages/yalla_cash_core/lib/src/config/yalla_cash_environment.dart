import 'package:flutter/foundation.dart';

/// Single source of truth for backend API configuration.
///
/// All three apps (admin / customer / merchant) resolve their base URL
/// through [YallaCashEnvironment.fromEnvironment] so every app running in
/// the same environment talks to the SAME backend. No app hardcodes its own
/// URL anymore.
///
/// Resolution order:
///   1. Explicit `--dart-define=YALLA_CASH_API_BASE_URL=...` (required for
///      production/release builds).
///   2. Platform-aware LOCAL default:
///        - Android emulator -> http://10.0.2.2:3000 (host loopback alias)
///        - Chrome / desktop / everything else -> http://localhost:3000
class YallaCashEnvironment {
  const YallaCashEnvironment({
    required this.apiBaseUrl,
    this.apiTimeout = const Duration(seconds: 15),
    this.useRemoteBackend = false,
  });

  /// --dart-define key used to pin the backend URL explicitly.
  static const baseUrlEnvKey = 'YALLA_CASH_API_BASE_URL';

  /// Local development default (Chrome, desktop tools, physical debugging).
  static const localBaseUrl = 'http://localhost:3000';

  /// Local development default for Android emulators, which reach the host
  /// machine through the 10.0.2.2 loopback alias instead of localhost.
  static const androidEmulatorLocalBaseUrl = 'http://10.0.2.2:3000';

  factory YallaCashEnvironment.fromEnvironment({bool? useRemoteBackend}) {
    const configuredBaseUrl = String.fromEnvironment(baseUrlEnvKey);
    final resolvedUrl =
        configuredBaseUrl.isEmpty ? platformDefaultBaseUrl : configuredBaseUrl;
    final remote =
        useRemoteBackend ?? bool.fromEnvironment('YALLA_CASH_USE_REMOTE');
    return YallaCashEnvironment(
      apiBaseUrl: Uri.parse(resolvedUrl),
      useRemoteBackend: remote,
    );
  }

  /// Default base URL for the current runtime environment when no explicit
  /// URL was provided via --dart-define.
  ///
  /// Android emulators cannot reach the developer machine on `localhost`;
  /// they must use the 10.0.2.2 alias. Everything else (Chrome, desktop,
  /// iOS simulator) uses localhost directly.
 static String get platformDefaultBaseUrl {
  if (kIsWeb) {
    return 'https://yalla-cash-api.onrender.com';
  }

  if (defaultTargetPlatform == TargetPlatform.android) {
    return androidEmulatorLocalBaseUrl;
  }

  return localBaseUrl;
}

  final Uri apiBaseUrl;
  final Duration apiTimeout;
  final bool useRemoteBackend;
}
