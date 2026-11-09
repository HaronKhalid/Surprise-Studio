import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Tokens {
  const Tokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

/// Where the session lives. Behind an interface so tests use memory and production uses the
/// platform keystore.
abstract class TokenStore {
  Future<Tokens?> read();
  Future<void> write(Tokens tokens);
  Future<void> clear();
}

/// Android Keystore-backed storage. Refresh tokens are long-lived credentials, so they must not go
/// in plain SharedPreferences.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;

  static const _access = 'access_token';
  static const _refresh = 'refresh_token';

  @override
  Future<Tokens?> read() async {
    final access = await _storage.read(key: _access);
    final refresh = await _storage.read(key: _refresh);
    return access == null || refresh == null ? null : Tokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> write(Tokens tokens) async {
    await _storage.write(key: _access, value: tokens.accessToken);
    await _storage.write(key: _refresh, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}

class MemoryTokenStore implements TokenStore {
  Tokens? _tokens;
  @override
  Future<Tokens?> read() async => _tokens;
  @override
  Future<void> write(Tokens tokens) async => _tokens = tokens;
  @override
  Future<void> clear() async => _tokens = null;
}
