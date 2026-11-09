/// Form validators. They return an error message, or null when the value is fine, which is the
/// contract Flutter's `TextFormField.validator` expects. The server re-validates everything.
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter your email';
  if (v.length > 254 || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email';
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Enter a password';
  if (v.length < 8) return 'Use at least 8 characters';
  if (v.length > 128) return 'That password is too long';
  return null;
}

String? validateRequired(String? value, {String message = 'This is required', int max = 80}) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return message;
  if (v.length > max) return 'Keep it under $max characters';
  return null;
}
