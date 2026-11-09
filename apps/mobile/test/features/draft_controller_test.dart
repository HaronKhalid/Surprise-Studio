import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:surprise_studio/app/providers.dart';
import 'package:surprise_studio/core/analytics.dart';
import 'package:surprise_studio/features/create/draft_controller.dart';
import 'package:surprise_studio/features/create/draft_state.dart';
import 'package:surprise_studio/features/surprises/surprise.dart';

import '../support/fakes.dart';

({ProviderContainer c, FakeSurpriseRepository repo, RecordingAnalytics analytics}) setup([String? id]) {
  final repo = FakeSurpriseRepository();
  final analytics = RecordingAnalytics();
  final c = ProviderContainer(retry: (_, _) => null, overrides: [surpriseRepositoryProvider.overrideWithValue(repo), analyticsProvider.overrideWithValue(analytics)]);
  addTearDown(c.dispose);
  // Keep the autoDispose provider alive for the test's duration.
  c.listen(draftProvider(id), (_, _) {});
  return (c: c, repo: repo, analytics: analytics);
}

void main() {
  group('new surprise', () {
    test('starting records create_started and begins empty with no id', () {
      final s = setup();
      expect(s.c.read(draftProvider(null)).id, isNull);
      expect(s.analytics.events, [AppEvent.createStarted]);
    });

    test('the first save CREATES the surprise, later saves UPDATE it', () async {
      final s = setup();
      final n = s.c.read(draftProvider(null).notifier);
      await n.saveWho(name: ' Sara ', nickname: 'Saru', relationship: 'Friend');
      expect(s.repo.calls, ['create']);
      expect(s.c.read(draftProvider(null)).id, 's1');
      expect(s.c.read(draftProvider(null)).name, 'Sara'); // trimmed

      await n.saveWho(name: 'Sara', nickname: '', relationship: null);
      expect(s.repo.calls, ['create', 'update:s1']); // not a second create
      expect(s.analytics.events.where((e) => e == AppEvent.surpriseCreated), hasLength(1));
    });

    test('a failed create leaves no id, so retrying creates (never updates a ghost)', () async {
      final s = setup();
      s.repo.failNext = apiError('INTERNAL_ERROR', status: 500);
      await expectLater(s.c.read(draftProvider(null).notifier).saveWho(name: 'Sara', nickname: ''), throwsA(anything));
      expect(s.c.read(draftProvider(null)).id, isNull);
    });

    test('saveMessage writes message and content as one unit', () async {
      final s = setup();
      final n = s.c.read(draftProvider(null).notifier);
      await n.saveWho(name: 'Sara', nickname: '');
      await n.saveMessage(message: ' Hello ', intro: 'Hi', ending: 'Bye', memories: [const Memory(text: 'm')]);
      final sent = s.repo.updates.last;
      expect(sent.message, 'Hello');
      expect((sent.content!.intro, sent.content!.ending, sent.content!.memories.length), ('Hi', 'Bye', 1));
      expect(s.c.read(draftProvider(null)).memories, hasLength(1));
    });
  });

  group('editing an existing surprise', () {
    test('loads fields and photos in order', () async {
      final s = setup('s9');
      s.repo.seed(id: 's9', name: 'Ayesha', message: 'Hello', templateId: 't-cinematic');
      s.repo.photosBySurprise['s9'] = [
        const Photo(id: 'b', sortOrder: 1, thumbUrl: 't', mediumUrl: 'm'),
        const Photo(id: 'a', sortOrder: 0, thumbUrl: 't', mediumUrl: 'm'),
      ];
      await s.c.read(draftProvider('s9').notifier).load();
      final d = s.c.read(draftProvider('s9'));
      expect((d.id, d.name, d.message, d.templateId), ('s9', 'Ayesha', 'Hello', 't-cinematic'));
      expect(d.photos.map((p) => p.id), ['a', 'b']);
      expect(d.loading, isFalse);
      expect(s.analytics.events, isNot(contains(AppEvent.createStarted)));
    });

    test('a load failure is recorded for the screen to show a retry', () async {
      final s = setup('s9');
      s.repo.failNext = apiError('X', status: 500);
      await s.c.read(draftProvider('s9').notifier).load();
      expect(s.c.read(draftProvider('s9')).loadError, isNotNull);
    });
  });

  group('photos', () {
    Future<DraftController> started(({ProviderContainer c, FakeSurpriseRepository repo, RecordingAnalytics analytics}) s) async {
      final n = s.c.read(draftProvider(null).notifier);
      await n.saveWho(name: 'Sara', nickname: '');
      return n;
    }

    test('uploads each photo, all end up in the list, and each is counted', () async {
      final s = setup();
      final n = await started(s);
      await n.addPhotos([image('a.jpg'), image('b.jpg')]);
      final d = s.c.read(draftProvider(null));
      expect(d.photos, hasLength(2));
      expect(d.uploads, isEmpty);
      expect(s.analytics.events.where((e) => e == AppEvent.photoUploaded), hasLength(2));
    });

    test('one failed photo does not stop the rest, and is kept listed as failed', () async {
      final s = setup();
      s.repo.uploadError = apiError('INVALID_FILE_TYPE');
      final n = await started(s);
      await n.addPhotos([image('a.jpg'), image('bad.jpg'), image('c.jpg')]);
      final d = s.c.read(draftProvider(null));
      expect(d.photos, hasLength(2));
      expect(d.uploads.single.status, UploadStatus.failed);
      n.dismissUpload(d.uploads.single.key);
      expect(s.c.read(draftProvider(null)).uploads, isEmpty);
    });

    test('never exceeds the 10 photo limit, even if more are offered', () async {
      final s = setup();
      final n = await started(s);
      await n.addPhotos([for (var i = 0; i < 14; i++) image('p$i.jpg')]);
      expect(s.c.read(draftProvider(null)).photos, hasLength(10));
      expect(s.repo.calls.where((c) => c.startsWith('upload:')), hasLength(10));
    });

    test('removing a photo is optimistic, and rolls back if the server refuses', () async {
      final s = setup();
      final n = await started(s);
      await n.addPhotos([image('a.jpg'), image('b.jpg')]);
      final id = s.c.read(draftProvider(null)).photos.first.id;
      s.repo.failNext = apiError('X', status: 500);
      await expectLater(n.removePhoto(id), throwsA(anything));
      expect(s.c.read(draftProvider(null)).photos, hasLength(2)); // restored

      await n.removePhoto(id);
      expect(s.c.read(draftProvider(null)).photos.map((p) => p.id), isNot(contains(id)));
    });

    test('reordering persists only the photos that moved', () async {
      final s = setup();
      final n = await started(s);
      await n.addPhotos([image('a.jpg'), image('b.jpg'), image('c.jpg')]);
      final ids = s.c.read(draftProvider(null)).photos.map((p) => p.id).toList();

      await n.reorder(2, 0); // c goes to the front: order becomes c, a, b
      expect(s.c.read(draftProvider(null)).photos.map((p) => p.id), [ids[2], ids[0], ids[1]]);
      expect(s.repo.orderCalls.toSet(), {(ids[2], 0), (ids[0], 1), (ids[1], 2)});

      s.repo.orderCalls.clear();
      await n.reorder(1, 1); // dropped where it was: nothing to save
      expect(s.repo.orderCalls, isEmpty);
    });

    test('a failed reorder reloads the real order from the server', () async {
      final s = setup();
      final n = await started(s);
      await n.addPhotos([image('a.jpg'), image('b.jpg')]);
      final before = s.c.read(draftProvider(null)).photos.map((p) => p.id).toList();
      s.repo.failNext = apiError('X', status: 500);
      await expectLater(n.reorder(1, 0), throwsA(anything));
      expect(s.c.read(draftProvider(null)).photos.map((p) => p.id), before); // server never changed
    });
  });

  group('style', () {
    test('choosing a different template clears the accent and font locally, as the server does', () async {
      final s = setup();
      final n = s.c.read(draftProvider(null).notifier);
      await n.saveWho(name: 'Sara', nickname: '');
      await n.chooseTemplate(template());
      await n.saveTheme(accent: '#ffaa00', font: 'inter');
      expect(s.c.read(draftProvider(null)).accent, '#ffaa00');

      await n.chooseTemplate(template(id: 't-cute', slug: 'cute', name: 'Cute'));
      final d = s.c.read(draftProvider(null));
      expect((d.templateId, d.accent, d.font), ('t-cute', null, null));
      expect(s.analytics.events.where((e) => e == AppEvent.templateSelected), hasLength(2));
    });

    test('choosing the template already chosen makes no request', () async {
      final s = setup();
      final n = s.c.read(draftProvider(null).notifier);
      await n.saveWho(name: 'Sara', nickname: '');
      await n.chooseTemplate(template());
      s.repo.calls.clear();
      await n.chooseTemplate(template());
      expect(s.repo.calls, isEmpty);
    });

    test('theme is sent as a whole value (accent and font together)', () async {
      final s = setup();
      final n = s.c.read(draftProvider(null).notifier);
      await n.saveWho(name: 'Sara', nickname: '');
      await n.saveTheme(accent: '#ffaa00', font: null);
      expect(s.repo.updates.last.theme!.accent, '#ffaa00');
      expect(s.repo.updates.last.theme!.font, isNull);
    });
  });

  test('publish returns the published surprise and records the event', () async {
    final s = setup();
    final n = s.c.read(draftProvider(null).notifier);
    await n.saveWho(name: 'Sara', nickname: '');
    final published = await n.publish();
    expect(published.isPublished, isTrue);
    expect(s.analytics.events, contains(AppEvent.surprisePublished));
  });
}
