class YallaCashFailure implements Exception {
  const YallaCashFailure({
    required this.message,
    this.code = 'unknown_error',
    this.statusCode,
    this.details,
  });

  final String message;
  final String code;
  final int? statusCode;
  final Object? details;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'YallaCashFailure($code, $message)';
}
