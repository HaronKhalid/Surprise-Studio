import 'package:flutter_test/flutter_test.dart';
import 'package:surprise_studio/features/surprises/surprise.dart';
import 'package:surprise_studio/features/templates/template.dart';

import '../support/fakes.dart';

void main() {
  group('Template.fromJson (real GET /templates shape)', () {
    final t = Template.fromJson(templateJson(customizableColors: ['accent'], minPhotos: 2, maxMemories: 0));

    test('reads identity, look and limits', () {
      expect((t.id, t.slug, t.name), ('t-cinematic', 'cinematic', 'Cinematic'));
      expect(t.colors['accent'], '#D4AF37');
      expect(t.font, 'playfair');
      expect(t.fonts, ['playfair', 'cormorant', 'inter']);
      expect((t.minPhotos, t.maxMemories), (2, 0));
      expect(t.allowsAccent, isTrue);
    });

    test('knows which sections are required and whether memories are shown', () {
      expect(t.requiredSections, {'hero', 'photo_gallery', 'message', 'footer'});
      expect(t.showsMemories, isTrue);
      final noMemories = Template.fromJson(templateJson(sections: [
        {'type': 'hero', 'required': true},
        {'type': 'footer', 'required': true},
      ]));
      expect(noMemories.showsMemories, isFalse);
    });

    test('a template that allows no colour changes says so', () {
      expect(Template.fromJson(templateJson(customizableColors: [])).allowsAccent, isFalse);
    });
  });

  group('Surprise.fromJson (real POST/GET /surprises shape)', () {
    test('reads a full draft including content and theme', () {
      final s = Surprise.fromJson({
        'id': 'abc',
        'userId': 'ignored',
        'recipientName': 'Ayesha Khan',
        'recipientNickname': 'Ayesha',
        'relationship': 'Friend',
        'message': 'Hi',
        'templateId': 't1',
        'slug': null,
        'status': 'DRAFT',
        'updatedAt': '2026-06-15T10:00:00.000Z',
        'content': {
          'intro': 'Hello',
          'ending': 'Bye',
          'memories': [
            {'title': 'Beach', 'text': 'That day'},
            {'text': 'No title'},
          ],
        },
        'theme': {'colors': {'accent': '#ffaa00'}, 'font': 'inter'},
      });
      expect(s.displayName, 'Ayesha');
      expect(s.status, SurpriseStatus.draft);
      expect(s.isPublished, isFalse);
      expect((s.intro, s.ending), ('Hello', 'Bye'));
      expect(s.memories.map((m) => (m.title, m.text)), [('Beach', 'That day'), (null, 'No title')]);
      expect((s.accent, s.font), ('#ffaa00', 'inter'));
    });

    test('copes with the minimal row a brand-new surprise has', () {
      final s = Surprise.fromJson({'id': 'a', 'recipientName': 'Sara', 'status': 'DRAFT', 'updatedAt': '2026-06-15T10:00:00.000Z', 'content': <String, dynamic>{}, 'theme': <String, dynamic>{}});
      expect(s.displayName, 'Sara');
      expect(s.memories, isEmpty);
      expect(s.accent, isNull);
    });

    test('a blank nickname falls back to the name', () {
      final s = Surprise.fromJson({'id': 'a', 'recipientName': 'Sara', 'recipientNickname': '  ', 'status': 'DRAFT', 'updatedAt': '2026-06-15T10:00:00.000Z'});
      expect(s.displayName, 'Sara');
    });

    test('published means status AND a slug', () {
      Surprise parse(String status, String? slug) => Surprise.fromJson({'id': 'a', 'recipientName': 'S', 'status': status, 'slug': slug, 'updatedAt': '2026-06-15T10:00:00.000Z'});
      expect(parse('PUBLISHED', 'abc123XYZ_').isPublished, isTrue);
      expect(parse('PUBLISHED', null).isPublished, isFalse);
      expect(parse('DRAFT', 'abc123XYZ_').isPublished, isFalse); // unpublished keeps its slug
    });

    test('unknown status values do not crash', () {
      expect(SurpriseStatus.parse('SOMETHING_NEW'), SurpriseStatus.draft);
    });
  });

  group('Photo.fromJson (GET /assets)', () {
    test('reads variants and size', () {
      final p = Photo.fromJson({'id': 'p', 'width': 800, 'height': 600, 'sortOrder': 2, 'confirmed': true, 'urls': {'thumb': 'https://x/t', 'medium': 'https://x/m', 'large': 'https://x/l'}});
      expect((p.id, p.sortOrder, p.width, p.height), ('p', 2, 800, 600));
      expect((p.thumbUrl, p.mediumUrl), ('https://x/t', 'https://x/m'));
      expect(p.withSortOrder(0).sortOrder, 0);
    });
  });

  group('SurpriseChanges.toJson: the API REPLACES content and theme wholesale', () {
    test('sends only what is set', () {
      expect(const SurpriseChanges(message: 'Hi').toJson(), {'message': 'Hi'});
      expect(const SurpriseChanges().toJson(), isEmpty);
    });

    test('content always carries intro, ending and memories together, so a partial write cannot erase the rest', () {
      final json = const SurpriseChanges(content: ContentValue(memories: [Memory(text: 'm')])).toJson();
      expect(json['content'], {'intro': '', 'ending': '', 'memories': [{'text': 'm'}]});
    });

    test('a memory without a title omits the key rather than sending an empty one', () {
      expect(const Memory(text: 'x').toJson(), {'text': 'x'});
      expect(const Memory(title: '', text: 'x').toJson(), {'text': 'x'});
      expect(const Memory(title: 'T', text: 'x').toJson(), {'title': 'T', 'text': 'x'});
    });

    test('theme with nothing selected is an empty object: the server\'s way to reset to template defaults', () {
      expect(const SurpriseChanges(theme: ThemeValue()).toJson(), {'theme': <String, dynamic>{}});
      expect(const SurpriseChanges(theme: ThemeValue(accent: '#ffaa00', font: 'inter')).toJson(), {
        'theme': {'colors': {'accent': '#ffaa00'}, 'font': 'inter'},
      });
    });
  });
}
