import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/token_store.dart';
import 'user.dart';

abstract class AuthRepository {
  /// The signed-in user, or null if there is no valid session.
  Future<User?> restore();
  Future<User> login(String email, String password);
  Future<User> register(String email, String password, {String? displayName});
  Future<void> logout();

  /// Permanently deletes the account and everything in it. Needs the password.
  Future<void> deleteAccount(String password);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._tokens);
  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<User?> restore() async {
    if (await _tokens.read() == null) return null;
    try {
      return User.fromJson(await _api.get('/auth/me') as Map<String, dynamic>);
    } on ApiException catch (e) {
      // Only a rejected session means "signed out". An offline start must not look like a logout.
      if (e.isUnauthenticated) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<User> login(String email, String password) async =>
      _startSession(await _api.post('/auth/login', body: {'email': email.trim(), 'password': password}, auth: false));

  @override
  Future<User> register(String email, String password, {String? displayName}) async => _startSession(
        await _api.post('/auth/register',
            body: {'email': email.trim(), 'password': password, if (displayName != null && displayName.isNotEmpty) 'displayName': displayName},
            auth: false),
      );

  @override
  Future<void> logout() async {
    final tokens = await _tokens.read();
    try {
      // Best effort: revoke the refresh token server-side, but never block signing out on it.
      if (tokens != null) await _api.post('/auth/logout', body: {'refreshToken': tokens.refreshToken}, auth: false);
    } on ApiException {
      // ignored on purpose
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _api.delete('/auth/me', body: {'password': password});
    await _tokens.clear();
  }

  Future<User> _startSession(dynamic data) async {
    final map = data as Map<String, dynamic>;
    await _tokens.write(Tokens(accessToken: map['accessToken'] as String, refreshToken: map['refreshToken'] as String));
    return User.fromJson(map['user'] as Map<String, dynamic>);
  }
}
