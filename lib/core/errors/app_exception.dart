class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() => 'AppException(message: $message, cause: $cause)';
}

