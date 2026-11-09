import 'package:flutter_test/flutter_test.dart';
import 'package:surprise_studio/app/router.dart';
import 'package:surprise_studio/features/preview/preview_page.dart';

String? redirect(String location, SessionStatus session, {bool seen = true}) => resolveRedirect(location: location, session: session, onboardingSeen: seen);

void main() {
  group('resolveRedirect', () {
    test('while the session is being restored (or failed to), everything shows the splash', () {
      for (final s in [SessionStatus.loading, SessionStatus.failed]) {
        expect(redirect('/', s), '/splash');
        expect(redirect('/create', s), '/splash');
        expect(redirect('/splash', s), isNull);
      }
    });

    test('signed out: protected routes go to login, or onboarding the first time', () {
      for (final path in ['/', '/create', '/settings', '/surprise/abc', '/surprise/abc/preview']) {
        expect(redirect(path, SessionStatus.signedOut), '/login', reason: path);
        expect(redirect(path, SessionStatus.signedOut, seen: false), '/onboarding', reason: path);
      }
      expect(redirect('/splash', SessionStatus.signedOut), '/login');
      expect(redirect('/splash', SessionStatus.signedOut, seen: false), '/onboarding');
    });

    test('signed out may stay on the public screens', () {
      for (final path in ['/login', '/register']) {
        expect(redirect(path, SessionStatus.signedOut), isNull, reason: path);
      }
      expect(redirect('/onboarding', SessionStatus.signedOut, seen: false), isNull);
    });

    test('once the intro has been seen, onboarding hands over to login (regression: the user used to stay stuck on it)', () {
      expect(redirect('/onboarding', SessionStatus.signedOut, seen: true), '/login');
    });

    test('signed in: the login/register/onboarding/splash screens go home, everything else stays', () {
      for (final path in ['/login', '/register', '/onboarding', '/splash']) {
        expect(redirect(path, SessionStatus.signedIn), '/', reason: path);
      }
      for (final path in ['/', '/create', '/settings', '/surprise/abc']) {
        expect(redirect(path, SessionStatus.signedIn), isNull, reason: path);
      }
    });
  });

  group('isAllowedPreviewNavigation (the preview URL carries a credential)', () {
    final site = Uri.parse('https://example.com');

    test('allows the site\'s own pages', () {
      expect(isAllowedPreviewNavigation(Uri.parse('https://example.com/preview/tok'), site), isTrue);
      expect(isAllowedPreviewNavigation(Uri.parse('https://example.com/'), site), isTrue);
      expect(isAllowedPreviewNavigation(Uri.parse('about:blank'), site), isTrue);
    });

    test('blocks other hosts, schemes, ports and look-alikes', () {
      for (final url in ['https://evil.example/', 'http://example.com/', 'https://example.com:8443/', 'https://example.com.evil.net/', 'https://sub.example.com/', 'intent://x#Intent;end', 'javascript:alert(1)', 'file:///etc/passwd']) {
        expect(isAllowedPreviewNavigation(Uri.parse(url), site), isFalse, reason: url);
      }
    });

    test('a dev site on a custom port only allows that port', () {
      final dev = Uri.parse('http://localhost:3000');
      expect(isAllowedPreviewNavigation(Uri.parse('http://localhost:3000/preview/x'), dev), isTrue);
      expect(isAllowedPreviewNavigation(Uri.parse('http://localhost:4000/'), dev), isFalse);
    });
  });
}
