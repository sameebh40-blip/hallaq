import 'dart:async';
import 'dart:io';

bool _isRetryable(Object e) {
  if (e is TimeoutException) return true;
  if (e is SocketException) return true;
  final s = e.toString().toLowerCase();
  if (s.contains('socketexception')) return true;
  if (s.contains('failed host lookup')) return true;
  if (s.contains('connection reset')) return true;
  if (s.contains('connection closed')) return true;
  if (s.contains('failed to fetch')) return true;
  if (s.contains('timed out')) return true;
  return false;
}

Future<T> resilientRequest<T>(
  Future<T> Function() action, {
  int retries = 2,
  Duration timeout = const Duration(seconds: 15),
}) async {
  var attempt = 0;
  while (true) {
    try {
      return await action().timeout(timeout);
    } catch (e) {
      if (attempt >= retries || !_isRetryable(e)) rethrow;
      attempt += 1;
      await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
    }
  }
}

