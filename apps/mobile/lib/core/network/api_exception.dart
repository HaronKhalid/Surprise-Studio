/// An error from the API (or from reaching it), carrying the server's stable error `code`.
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.status});

  /// Could not reach the server at all (offline, DNS, timeout).
  const ApiException.network()
      : code = 'NETWORK_ERROR',
        message = 'Could not reach the server',
        status = null;

  final String code;
  final String message;
  final int? status;

  bool get isNetwork => code == 'NETWORK_ERROR';
  bool get isUnauthenticated => status == 401;

  @override
  String toString() => 'ApiException($code${status == null ? '' : ', $status'}): $message';
}

/// Turns any error into something a person can read. Codes come from docs/api.md; unknown codes
/// fall back to the server's own message, which is written for end users.
String friendlyError(Object error) {
  if (error is! ApiException) return 'Something went wrong. Please try again.';
  return switch (error.code) {
    'NETWORK_ERROR' => 'No connection. Check your internet and try again.',
    'INVALID_CREDENTIALS' => 'Incorrect email or password.',
    'EMAIL_TAKEN' => 'That email is already registered. Try logging in.',
    'PHOTO_LIMIT_REACHED' => 'You can add up to 10 photos.',
    'PHOTOS_REQUIRED' || 'MESSAGE_REQUIRED' || 'MEMORIES_REQUIRED' || 'TEMPLATE_REQUIRED' => error.message,
    'THEME_LOW_CONTRAST' => 'That colour is hard to read on this style. Try another.',
    'TOO_MANY_MEMORIES' => error.message,
    'FILE_TOO_LARGE' => 'That photo is too large (10 MB max).',
    'INVALID_FILE_TYPE' || 'MIME_MISMATCH' || 'INVALID_IMAGE' => 'Only JPEG, PNG and WebP photos are supported.',
    'INVALID_DIMENSIONS' => 'That photo is too small or too large.',
    'TOO_MANY_REQUESTS' || 'ThrottlerException' => 'Too many attempts. Please wait a moment.',
    _ when error.status != null && error.status! >= 500 => 'The server had a problem. Please try again shortly.',
    _ => error.message,
  };
}
