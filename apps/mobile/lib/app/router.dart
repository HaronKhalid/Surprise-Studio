import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/auth/onboarding_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/splash_page.dart';
import '../features/create/create_page.dart';
import '../features/create/published_page.dart';
import '../features/preview/preview_page.dart';
import '../features/settings/settings_page.dart';
import '../features/surprises/home_page.dart';
import '../features/surprises/surprise_detail_page.dart';

enum SessionStatus { loading, failed, signedOut, signedIn }

const _publicRoutes = {'/onboarding', '/login', '/register'};

/// Where a navigation should actually go, given who is signed in. Pure so it is unit tested
/// without any widgets. Returns null to stay where we are.
String? resolveRedirect({required String location, required SessionStatus session, required bool onboardingSeen}) {
  switch (session) {
    case SessionStatus.loading:
    case SessionStatus.failed:
      return location == '/splash' ? null : '/splash';
    case SessionStatus.signedOut:
      if (location == '/splash' || location == '/') return onboardingSeen ? '/login' : '/onboarding';
      // The intro is shown once: after it has been seen there is no way back to it.
      if (location == '/onboarding') return onboardingSeen ? '/login' : null;
      return _publicRoutes.contains(location) ? null : (onboardingSeen ? '/login' : '/onboarding');
    case SessionStatus.signedIn:
      return location == '/splash' || _publicRoutes.contains(location) ? '/' : null;
  }
}

/// Re-runs the router's redirect whenever auth or onboarding state changes.
class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.ping());
  ref.listen(onboardingSeenProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final session = auth.isLoading
          ? SessionStatus.loading
          : auth.hasError
              ? SessionStatus.failed
              : auth.value == null
                  ? SessionStatus.signedOut
                  : SessionStatus.signedIn;
      return resolveRedirect(location: state.matchedLocation, session: session, onboardingSeen: ref.read(onboardingSeenProvider));
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
      // /create edits a draft when given ?id=, otherwise starts a new surprise.
      GoRoute(path: '/create', builder: (_, state) => CreatePage(surpriseId: state.uri.queryParameters['id'])),
      GoRoute(path: '/surprise/:id', builder: (_, state) => SurpriseDetailPage(id: state.pathParameters['id']!)),
      GoRoute(path: '/surprise/:id/preview', builder: (_, state) => PreviewPage(surpriseId: state.pathParameters['id']!)),
      GoRoute(path: '/surprise/:id/published', builder: (_, state) => PublishedPage(id: state.pathParameters['id']!)),
    ],
  );
});
