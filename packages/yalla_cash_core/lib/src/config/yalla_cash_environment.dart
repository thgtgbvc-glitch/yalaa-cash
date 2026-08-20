class YallaCashEnvironment {
  const YallaCashEnvironment({
    required this.apiBaseUrl,
    this.apiTimeout = const Duration(seconds: 15),
    this.useRemoteBackend = false,
  });

  factory YallaCashEnvironment.fromEnvironment() {
    const baseUrl = String.fromEnvironment(
      'YALLA_CASH_API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    );
    const useRemote = bool.fromEnvironment('YALLA_CASH_USE_REMOTE');
    return YallaCashEnvironment(
      apiBaseUrl: Uri.parse(baseUrl),
      useRemoteBackend: useRemote,
    );
  }

  final Uri apiBaseUrl;
  final Duration apiTimeout;
  final bool useRemoteBackend;
}
