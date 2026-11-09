import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:surprise_studio/core/config.dart';
import 'package:surprise_studio/core/contrast.dart';
import 'package:surprise_studio/core/format.dart';
import 'package:surprise_studio/core/network/api_exception.dart';
import 'package:surprise_studio/core/validators.dart';
import 'package:surprise_studio/features/surprises/picked_image.dart';
import 'package:surprise_studio/features/templates/template.dart';

void main() {
  group('validators', () {
    test('email', () {
      expect(validateEmail(null), isNotNull);
      expect(validateEmail('   '), isNotNull);
      for (final bad in ['a', 'a@b', '@b.co', 'a b@c.de', 'a@b@c.de']) {
        expect(validateEmail(bad), isNotNull, reason: bad);
      }
      expect(validateEmail(' sara@example.com '), isNull);
      expect(validateEmail('a.b+tag@sub.example.co'), isNull);
      expect(validateEmail('${'a' * 250}@b.co'), isNotNull);
    });

    test('password', () {
      expect(validatePassword(''), isNotNull);
      expect(validatePassword('1234567'), isNotNull);
      expect(validatePassword('12345678'), isNull);
      expect(validatePassword('x' * 129), isNotNull);
    });

    test('required', () {
      expect(validateRequired('  '), isNotNull);
      expect(validateRequired('Sara'), isNull);
      expect(validateRequired('x' * 81), isNotNull);
      expect(validateRequired('x' * 81, max: 100), isNull);
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 6, 15, 12);
    String t(Duration ago) => relativeTime(now.subtract(ago), now: now);

    test('buckets', () {
      expect(t(const Duration(seconds: 10)), 'just now');
      expect(t(const Duration(minutes: 5)), '5 min ago');
      expect(t(const Duration(hours: 3)), '3 h ago');
      expect(t(const Duration(days: 1, hours: 2)), 'yesterday');
      expect(t(const Duration(days: 4)), '4 days ago');
    });

    test('older than a week becomes a date, with the year only when it differs', () {
      expect(t(const Duration(days: 20)), '26 May');
      expect(t(const Duration(days: 400)), '11 May 2025');
    });

    test('a timestamp slightly in the future (clock skew) reads as just now', () {
      expect(relativeTime(now.add(const Duration(minutes: 2)), now: now), 'just now');
    });
  });

  group('contrastRatio (must agree with the server)', () {
    test('known values', () {
      expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
      expect(contrastRatio(const Color(0xFF336699), const Color(0xFF336699)), closeTo(1, 0.0001));
    });

    test('is symmetric', () {
      const a = Color(0xFFD4AF37);
      const b = Color(0xFF0B1020);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 1e-9));
    });

    test('matches the server for the launch templates\' default accents (all ≥ 3)', () {
      expect(contrastRatio(parseHex('#d4af37'), parseHex('#0b1020')), greaterThan(3));
      expect(contrastRatio(parseHex('#e63d7a'), parseHex('#fff4f8')), greaterThan(3));
      expect(contrastRatio(parseHex('#0b1021'), parseHex('#0b1020')), lessThan(3)); // the server rejects this one
    });
  });

  group('hex', () {
    test('round trips', () {
      expect(toHex(parseHex('#e63d7a')), '#e63d7a');
      expect(toHex(parseHex('#000000')), '#000000');
      expect(toHex(parseHex('#FFAA00')), '#ffaa00');
    });
  });

  group('AppConfig', () {
    test('builds public and preview links, tolerating a trailing slash', () {
      const c = AppConfig(apiUrl: 'https://api.example.com/api/v1', siteUrl: 'https://example.com/');
      expect(c.publicLink('abc123XYZ_'), 'https://example.com/s/abc123XYZ_');
      expect(c.previewUri('tok.en').toString(), 'https://example.com/preview/tok.en');
    });
  });

  group('sniffImageMime', () {
    Uint8List b(List<int> bytes) => Uint8List.fromList(bytes);

    test('recognises JPEG, PNG and WebP by content', () {
      expect(sniffImageMime(b([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
      expect(sniffImageMime(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0])), 'image/png');
      expect(sniffImageMime(b([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])), 'image/webp');
    });

    test('rejects everything else, including a script, a GIF and RIFF that is not WebP', () {
      expect(sniffImageMime(b('<?php echo 1;'.codeUnits)), isNull);
      expect(sniffImageMime(b('GIF89a......'.codeUnits)), isNull);
      expect(sniffImageMime(b([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits])), isNull);
      expect(sniffImageMime(b([])), isNull);
      expect(sniffImageMime(b([0x89, 0x50])), isNull);
    });
  });

  group('friendlyError', () {
    test('never leaks raw exception text', () {
      expect(friendlyError(StateError('secret internal detail')), isNot(contains('secret')));
    });

    test('maps known codes and falls back to the server message', () {
      expect(friendlyError(const ApiException.network()), contains('connection'));
      expect(friendlyError(const ApiException(code: 'INVALID_CREDENTIALS', message: 'x', status: 401)), 'Incorrect email or password.');
      expect(friendlyError(const ApiException(code: 'PHOTOS_REQUIRED', message: 'Add at least 2 photos before publishing', status: 400)), 'Add at least 2 photos before publishing');
      expect(friendlyError(const ApiException(code: 'WEIRD', message: 'Plain words from the server', status: 400)), 'Plain words from the server');
      expect(friendlyError(const ApiException(code: 'INTERNAL_ERROR', message: 'Something went wrong', status: 500)), contains('server had a problem'));
    });
  });
}
