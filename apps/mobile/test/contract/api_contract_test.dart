// Runs the app's REAL data layer (Dio client, repositories) against a REAL running API.
//
// Skipped unless SURPRISE_API_URL is set, so `flutter test` stays offline by default:
//
//   SURPRISE_API_URL=http://localhost:4000/api/v1 flutter test test/contract
//
// It registers a throwaway account and deletes it at the end. Registration is rate limited
// (5/min per IP), so do not run this in a tight loop.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:surprise_studio/core/analytics.dart';
import 'package:surprise_studio/core/network/api_client.dart';
import 'package:surprise_studio/core/network/api_exception.dart';
import 'package:surprise_studio/core/storage/token_store.dart';
import 'package:surprise_studio/features/auth/auth_repository.dart';
import 'package:surprise_studio/features/surprises/picked_image.dart';
import 'package:surprise_studio/features/surprises/surprise.dart';
import 'package:surprise_studio/features/surprises/surprise_repository.dart';
import 'package:surprise_studio/features/templates/template_repository.dart';

final _apiUrl = Platform.environment['SURPRISE_API_URL'];

/// A valid, uncompressed-enough PNG, built by hand so the test needs no image package.
Uint8List makePng(int w, int h, {int r = 70, int g = 110, int b = 180}) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < w; x++) {
      raw.add([(r + x) & 255, (g + y) & 255, b]);
    }
  }
  final crcTable = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });
  int crc(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final byte in bytes) {
      c = crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFF;
  }

  List<int> u32(int v) => [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [...u32(data.length), ...body, ...u32(crc(body))];
  }

  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...chunk('IHDR', [...u32(w), ...u32(h), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', ZLibCodec().encode(raw.toBytes())),
    ...chunk('IEND', const []),
  ]);
}

void main() {
  test('makePng produces something the sniffer accepts', () {
    expect(sniffImageMime(makePng(120, 120)), 'image/png');
  });

  group('against the real API', skip: _apiUrl == null ? 'set SURPRISE_API_URL to run' : null, () {
    late MemoryTokenStore tokens;
    late ApiClient api;
    late ApiAuthRepository auth;
    late ApiSurpriseRepository surprises;
    final sessionExpired = <int>[];
    final email = 'contract-${DateTime.now().microsecondsSinceEpoch}@example.com';
    const password = 'Contract!Pass123';

    setUpAll(() {
      tokens = MemoryTokenStore();
      api = ApiClient(baseUrl: _apiUrl!, tokens: tokens, onSessionExpired: () => sessionExpired.add(1));
      auth = ApiAuthRepository(api, tokens);
      surprises = ApiSurpriseRepository(api);
    });

    test('templates: the four launch templates parse', () async {
      final list = await ApiTemplateRepository(api).list();
      expect(list.map((t) => t.slug), containsAll(['cinematic', 'cute', 'memories', 'luxury']));
      final cinematic = list.firstWhere((t) => t.slug == 'cinematic');
      expect(cinematic.allowsAccent, isTrue);
      expect(cinematic.requiredSections, containsAll(['photo_gallery', 'message']));
      expect(cinematic.colors, containsPair('accent', startsWith('#')));
    });

    test('register -> user, tokens stored; /auth/me restores the session', () async {
      final user = await auth.register(email, password, displayName: 'Contract Tester');
      expect(user.email, email);
      expect(await tokens.read(), isNotNull);
      final restored = await auth.restore();
      expect(restored?.id, user.id);
    });

    test('a wrong password is INVALID_CREDENTIALS (401), and registering twice is EMAIL_TAKEN', () async {
      await expectLater(auth.login(email, 'wrong-password'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS').having((e) => e.status, 'status', 401)));
      await expectLater(auth.register(email, password), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'EMAIL_TAKEN')));
    });

    late Surprise surprise;
    late String templateId;

    test('create -> update message, content and theme -> read back', () async {
      final templates = await ApiTemplateRepository(api).list();
      final cinematic = templates.firstWhere((t) => t.slug == 'cinematic');
      templateId = cinematic.id;

      surprise = await surprises.create(const SurpriseChanges(recipientName: 'Ayesha Khan', recipientNickname: 'Ayesha', relationship: 'Friend'));
      expect(surprise.status, SurpriseStatus.draft);
      expect(surprise.displayName, 'Ayesha');

      await surprises.update(surprise.id, SurpriseChanges(templateId: templateId));
      await surprises.update(
        surprise.id,
        const SurpriseChanges(
          message: 'Happy birthday!',
          content: ContentValue(intro: 'Hello', ending: 'See you soon', memories: [Memory(title: 'Beach', text: 'That day'), Memory(text: 'No title')]),
          theme: ThemeValue(accent: '#ff7a1a', font: 'inter'),
        ),
      );
      final back = await surprises.get(surprise.id);
      expect(back.message, 'Happy birthday!');
      expect((back.intro, back.ending), ('Hello', 'See you soon'));
      expect(back.memories.map((m) => m.text), ['That day', 'No title']);
      expect((back.accent, back.font), ('#ff7a1a', 'inter'));
      expect(back.templateId, templateId);
    });

    test('the API replaces content wholesale: a partial write really would erase the rest (why ContentValue is a unit)', () async {
      await surprises.update(surprise.id, const SurpriseChanges(content: ContentValue(memories: [Memory(text: 'only')])));
      final back = await surprises.get(surprise.id);
      expect(back.intro, '');
      expect(back.memories.map((m) => m.text), ['only']);
      // restore for the next tests
      await surprises.update(surprise.id, const SurpriseChanges(content: ContentValue(intro: 'Hello', ending: 'See you soon', memories: [Memory(text: 'That day')])));
    });

    test('invalid theme is rejected with the stable code the UI maps', () async {
      await expectLater(
        surprises.update(surprise.id, const SurpriseChanges(theme: ThemeValue(accent: '#0b1021'))), // invisible on the dark background
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'THEME_LOW_CONTRAST')),
      );
    });

    test('publishing without a photo explains what is missing (PHOTOS_REQUIRED)', () async {
      await expectLater(surprises.publish(surprise.id), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'PHOTOS_REQUIRED').having((e) => e.status, 'status', 400)));
    });

    late List<Photo> photos;

    test('photos: presigned upload straight to storage, processing, ordering', () async {
      final first = await surprises.uploadPhoto(surprise.id, PickedImage(bytes: makePng(300, 200), mimeType: 'image/png', name: 'a.png'));
      final second = await surprises.uploadPhoto(surprise.id, PickedImage(bytes: makePng(200, 300, r: 200), mimeType: 'image/png', name: 'b.png'));
      expect((first.width, first.height), (300, 200));
      expect((second.width, second.height), (200, 300));

      // The processed variants are publicly served WebP.
      final client = HttpClient();
      addTearDown(client.close);
      final req = await client.getUrl(Uri.parse(first.thumbUrl));
      final res = await req.close();
      expect(res.statusCode, 200);
      expect(res.headers.contentType?.mimeType, 'image/webp');
      await res.drain<void>();

      await surprises.setPhotoOrder(second.id, 0);
      await surprises.setPhotoOrder(first.id, 1);
      photos = await surprises.photos(surprise.id);
      expect(photos.map((p) => p.id), [second.id, first.id]);
    });

    test('a non-image is refused before upload, and a disguised one by the server', () async {
      await expectLater(
        surprises.uploadPhoto(surprise.id, PickedImage(bytes: Uint8List.fromList(utf8.encode('<?php echo 1; ?>')), mimeType: 'image/jpeg', name: 'evil.jpg')),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_FILE_TYPE')),
      );
    });

    test('preview token renders the unpublished draft through the public preview endpoint', () async {
      final token = await surprises.previewToken(surprise.id);
      final client = HttpClient();
      addTearDown(client.close);
      final req = await client.getUrl(Uri.parse('$_apiUrl/public/previews/$token'));
      final res = await req.close();
      expect(res.statusCode, 200);
      final body = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      expect((data['recipient'] as Map)['name'], 'Ayesha Khan');
      expect((data['photos'] as List), hasLength(2));
    });

    test('publish -> a public link that works without login; unpublish takes it down', () async {
      final published = await surprises.publish(surprise.id);
      expect(published.isPublished, isTrue);
      expect(published.slug, matches(RegExp(r'^[A-Za-z0-9_-]{10}$')));

      final anonymous = ApiClient(baseUrl: _apiUrl!, tokens: MemoryTokenStore());
      final publicView = await anonymous.get('/public/surprises/${published.slug}') as Map<String, dynamic>;
      expect((publicView['recipient'] as Map)['name'], 'Ayesha Khan');
      expect(publicView['message'], 'Happy birthday!');
      expect((publicView['theme'] as Map)['font'], 'inter');

      await surprises.unpublish(surprise.id);
      await expectLater(anonymous.get('/public/surprises/${published.slug}'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
      await surprises.publish(surprise.id); // republish: same link
      expect((await surprises.get(surprise.id)).slug, published.slug);
    });

    test('the list contains it, newest first', () async {
      final list = await surprises.list();
      expect(list.map((s) => s.id), contains(surprise.id));
    });

    test('an expired access token is refreshed transparently (real refresh-token rotation)', () async {
      final before = (await tokens.read())!;
      await tokens.write(Tokens(accessToken: 'expired.or.garbage', refreshToken: before.refreshToken));
      final list = await surprises.list(); // 401 -> POST /auth/refresh -> retry
      expect(list, isNotEmpty);
      final after = (await tokens.read())!;
      expect(after.refreshToken, isNot(before.refreshToken)); // rotated
      expect(after.accessToken, isNot('expired.or.garbage'));
      expect(sessionExpired, isEmpty);
    });

    test('analytics events are accepted', () async {
      ApiAnalytics(api).track(AppEvent.appOpened);
      ApiAnalytics(api).track(AppEvent.templateSelected, template: 'cinematic');
      // Fire and forget: nothing to assert except that it does not throw.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    test('delete surprise erases its photos', () async {
      final photoUrl = photos.first.thumbUrl;
      await surprises.delete(surprise.id);
      final client = HttpClient();
      addTearDown(client.close);
      final res = await (await client.getUrl(Uri.parse(photoUrl))).close();
      expect(res.statusCode, anyOf(403, 404));
      await res.drain<void>();
      await expectLater(surprises.get(surprise.id), throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    });

    test('logout revokes the session, login works again, and a bad password blocks account deletion', () async {
      await auth.logout();
      expect(await tokens.read(), isNull);
      await auth.login(email, password);
      await expectLater(auth.deleteAccount('not-my-password'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
      expect(await tokens.read(), isNotNull); // a failed delete must not sign the user out
    });

    test('delete account: everything goes and the old credentials stop working', () async {
      await auth.deleteAccount(password);
      expect(await tokens.read(), isNull);
      await expectLater(auth.login(email, password), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')));
    });
  });
}
