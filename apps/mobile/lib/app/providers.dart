import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/analytics.dart';
import '../core/config.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_store.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/auth_repository.dart';
import '../features/surprises/surprise_repository.dart';
import '../features/templates/template_repository.dart';

// Everything below is overridable in tests: swap the repositories for fakes and no network,
// storage or plugin is touched.

final configProvider = Provider<AppConfig>((_) => AppConfig.fromEnvironment);

/// Set in main() once SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('override in main()'));

final tokenStoreProvider = Provider<TokenStore>((_) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      baseUrl: ref.watch(configProvider).apiUrl,
      tokens: ref.watch(tokenStoreProvider),
      // Looked up lazily, when a session actually expires, which avoids a construction cycle.
      onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
    ));

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => ApiAuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)));
final surpriseRepositoryProvider = Provider<SurpriseRepository>((ref) => ApiSurpriseRepository(ref.watch(apiClientProvider)));
final templateRepositoryProvider = Provider<TemplateRepository>((ref) => ApiTemplateRepository(ref.watch(apiClientProvider)));
final analyticsProvider = Provider<Analytics>((ref) => ApiAnalytics(ref.watch(apiClientProvider)));
