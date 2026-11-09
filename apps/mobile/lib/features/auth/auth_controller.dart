import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import 'user.dart';

/// The signed-in user, or null when signed out. Loading while the saved session is checked.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() => ref.read(authRepositoryProvider).restore();

  // login/register throw ApiException on failure so the form that called them can show the reason;
  // only success changes app-wide state.
  Future<void> login(String email, String password) async {
    state = AsyncData(await ref.read(authRepositoryProvider).login(email, password));
  }

  Future<void> register(String email, String password, {String? displayName}) async {
    state = AsyncData(await ref.read(authRepositoryProvider).register(email, password, displayName: displayName));
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount(String password) async {
    await ref.read(authRepositoryProvider).deleteAccount(password);
    state = const AsyncData(null);
  }

  /// The API rejected our refresh token: back to the login screen.
  void sessionExpired() => state = const AsyncData(null);

  /// After an offline start, try restoring the session again.
  void retry() => ref.invalidateSelf();
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

/// Whether the one-time intro has been shown.
class OnboardingSeen extends Notifier<bool> {
  static const _key = 'onboarding_seen';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> markSeen() async {
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
    state = true;
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingSeen, bool>(OnboardingSeen.new);

// Re-exported so tests can build a SharedPreferences without importing the plugin twice.
typedef Prefs = SharedPreferences;
