import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surprise_studio/app/app.dart';
import 'package:surprise_studio/app/providers.dart';
import 'package:surprise_studio/core/analytics.dart';
import 'package:surprise_studio/core/network/api_exception.dart';
import 'package:surprise_studio/core/platform.dart';
import 'package:surprise_studio/features/auth/auth_repository.dart';
import 'package:surprise_studio/features/auth/user.dart';
import 'package:surprise_studio/features/surprises/picked_image.dart';
import 'package:surprise_studio/features/surprises/surprise.dart';
import 'package:surprise_studio/features/surprises/surprise_repository.dart';
import 'package:surprise_studio/features/templates/template.dart';
import 'package:surprise_studio/features/templates/template_repository.dart';

/// A template in the exact shape GET /templates returns it.
Map<String, dynamic> templateJson({
  String id = 't-cinematic',
  String slug = 'cinematic',
  String name = 'Cinematic',
  String background = '#0B1020',
  String accent = '#D4AF37',
  List<String> customizableColors = const ['accent'],
  List<String> fonts = const ['playfair', 'cormorant', 'inter'],
  int minPhotos = 1,
  int maxMemories = 6,
  List<Map<String, Object>> sections = const [
    {'type': 'hero', 'required': true},
    {'type': 'photo_gallery', 'required': true},
    {'type': 'memory_cards', 'required': false},
    {'type': 'message', 'required': true},
    {'type': 'footer', 'required': true},
  ],
}) =>
    {
      'id': id,
      'slug': slug,
      'name': name,
      'occasion': 'birthday',
      'version': 1,
      'configuration': {
        'schemaVersion': 1,
        'displayOrder': 1,
        'description': 'A $name template',
        'sections': sections,
        'theme': {
          'colors': {'background': background, 'surface': '#151B2E', 'text': '#FFFFFF', 'accent': accent},
          'font': fonts.first,
        },
        'customizable': {'colors': customizableColors, 'fonts': fonts},
        'limits': {'minPhotos': minPhotos, 'maxMemories': maxMemories},
      },
    };

Template template({String id = 't-cinematic', String slug = 'cinematic', String name = 'Cinematic', int minPhotos = 1, List<Map<String, Object>>? sections, String background = '#0B1020', String accent = '#D4AF37', List<String> fonts = const ['playfair', 'cormorant', 'inter'], int maxMemories = 6}) {
  final base = templateJson(id: id, slug: slug, name: name, minPhotos: minPhotos, background: background, accent: accent, fonts: fonts, maxMemories: maxMemories);
  return Template.fromJson(sections == null ? base : templateJson(id: id, slug: slug, name: name, minPhotos: minPhotos, sections: sections, background: background, accent: accent, fonts: fonts, maxMemories: maxMemories));
}

class FakeTemplateRepository implements TemplateRepository {
  FakeTemplateRepository([List<Template>? templates]) : templates = templates ?? [template(), template(id: 't-cute', slug: 'cute', name: 'Cute')];
  final List<Template> templates;
  Object? failWith;

  @override
  Future<List<Template>> list() async {
    if (failWith != null) throw failWith!;
    return templates;
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user});
  User? user;
  Object? loginError;
  String? lastLoginEmail;
  bool deleted = false;

  @override
  Future<User?> restore() async => user;

  @override
  Future<User> login(String email, String password) async {
    lastLoginEmail = email;
    if (loginError != null) throw loginError!;
    return user = User(id: 'u1', email: email);
  }

  @override
  Future<User> register(String email, String password, {String? displayName}) async => user = User(id: 'u1', email: email, displayName: displayName);

  @override
  Future<void> logout() async => user = null;

  @override
  Future<void> deleteAccount(String password) async {
    deleted = true;
    user = null;
  }
}

class FakeSurpriseRepository implements SurpriseRepository {
  final Map<String, Surprise> surprises = {};
  final Map<String, List<Photo>> photosBySurprise = {};
  final List<String> calls = [];
  final List<SurpriseChanges> updates = [];
  final List<(String, int)> orderCalls = [];
  Object? failNext;
  Object? uploadError;
  int _n = 0;

  void _maybeFail() {
    final e = failNext;
    if (e != null) {
      failNext = null;
      throw e;
    }
  }

  Surprise seed({String id = 's1', String name = 'Sara', SurpriseStatus status = SurpriseStatus.draft, String? slug, String? templateId, String? message}) {
    final s = Surprise(id: id, recipientName: name, status: status, updatedAt: DateTime.now(), slug: slug, templateId: templateId, message: message);
    surprises[id] = s;
    return s;
  }

  @override
  Future<List<Surprise>> list() async {
    calls.add('list');
    _maybeFail();
    return surprises.values.toList();
  }

  @override
  Future<Surprise> get(String id) async {
    calls.add('get:$id');
    _maybeFail();
    return surprises[id]!;
  }

  @override
  Future<Surprise> create(SurpriseChanges c) async {
    calls.add('create');
    _maybeFail();
    final id = 's${++_n}';
    updates.add(c);
    return surprises[id] = Surprise(id: id, recipientName: c.recipientName!, recipientNickname: c.recipientNickname, relationship: c.relationship, status: SurpriseStatus.draft, updatedAt: DateTime.now());
  }

  @override
  Future<Surprise> update(String id, SurpriseChanges c) async {
    calls.add('update:$id');
    _maybeFail();
    updates.add(c);
    final o = surprises[id]!;
    return surprises[id] = Surprise(
      id: id,
      recipientName: c.recipientName ?? o.recipientName,
      recipientNickname: c.recipientNickname ?? o.recipientNickname,
      relationship: c.relationship ?? o.relationship,
      message: c.message ?? o.message,
      templateId: c.templateId ?? o.templateId,
      slug: o.slug,
      status: o.status,
      updatedAt: DateTime.now(),
      intro: c.content?.intro ?? o.intro,
      ending: c.content?.ending ?? o.ending,
      memories: c.content?.memories ?? o.memories,
      accent: c.theme != null ? c.theme!.accent : o.accent,
      font: c.theme != null ? c.theme!.font : o.font,
    );
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    _maybeFail();
    surprises.remove(id);
  }

  @override
  Future<Surprise> publish(String id) async {
    calls.add('publish:$id');
    _maybeFail();
    final o = surprises[id]!;
    return surprises[id] = Surprise(id: id, recipientName: o.recipientName, recipientNickname: o.recipientNickname, status: SurpriseStatus.published, slug: 'abc123XYZ_', updatedAt: DateTime.now(), templateId: o.templateId, message: o.message);
  }

  @override
  Future<Surprise> unpublish(String id) async {
    calls.add('unpublish:$id');
    final o = surprises[id]!;
    return surprises[id] = Surprise(id: id, recipientName: o.recipientName, status: SurpriseStatus.draft, slug: o.slug, updatedAt: DateTime.now());
  }

  @override
  Future<String> previewToken(String id) async => 'preview-token-for-$id-xxxxxxxxxxxxxxxx';

  @override
  Future<List<Photo>> photos(String surpriseId) async => [...?photosBySurprise[surpriseId]];

  @override
  Future<Photo> uploadPhoto(String surpriseId, PickedImage image) async {
    calls.add('upload:${image.name}');
    if (uploadError != null && image.name.startsWith('bad')) throw uploadError!;
    final list = photosBySurprise.putIfAbsent(surpriseId, () => []);
    final photo = Photo(id: 'p${list.length + 1}-${image.name}', sortOrder: list.length, thumbUrl: 'https://img.test/t.webp', mediumUrl: 'https://img.test/m.webp');
    list.add(photo);
    return photo;
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    calls.add('deletePhoto:$photoId');
    _maybeFail();
    for (final l in photosBySurprise.values) {
      l.removeWhere((p) => p.id == photoId);
    }
  }

  @override
  Future<void> setPhotoOrder(String photoId, int sortOrder) async {
    orderCalls.add((photoId, sortOrder));
    _maybeFail();
  }
}

class FakeSharer implements Sharer {
  final List<String> shared = [];
  final List<String> copied = [];
  @override
  Future<void> shareText(String text) async => shared.add(text);
  @override
  Future<void> copy(String text) async => copied.add(text);
}

class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker([this.next = const []]);
  List<PickedImage> next;
  int? lastLimit;
  @override
  Future<List<PickedImage>> pickMany(int limit) async {
    lastLimit = limit;
    return next.take(limit).toList();
  }
}

class RecordingAnalytics implements Analytics {
  final List<AppEvent> events = [];
  @override
  void track(AppEvent event, {String? template, String? step}) => events.add(event);
}

PickedImage image(String name) => PickedImage(bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]), mimeType: 'image/jpeg', name: name);

/// The whole app with every external dependency faked.
class TestHarness {
  TestHarness({FakeAuthRepository? auth, FakeSurpriseRepository? surprises, FakeTemplateRepository? templates, FakePhotoPicker? picker})
      : auth = auth ?? FakeAuthRepository(user: const User(id: 'u1', email: 'sara@example.com')),
        surprises = surprises ?? FakeSurpriseRepository(),
        templates = templates ?? FakeTemplateRepository(),
        picker = picker ?? FakePhotoPicker();

  final FakeAuthRepository auth;
  final FakeSurpriseRepository surprises;
  final FakeTemplateRepository templates;
  final FakePhotoPicker picker;
  final FakeSharer sharer = FakeSharer();
  final RecordingAnalytics analytics = RecordingAnalytics();

  Future<Widget> app({bool onboardingSeen = true}) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': onboardingSeen});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWithValue(auth),
        surpriseRepositoryProvider.overrideWithValue(surprises),
        templateRepositoryProvider.overrideWithValue(templates),
        sharerProvider.overrideWithValue(sharer),
        photoPickerProvider.overrideWithValue(picker),
        analyticsProvider.overrideWithValue(analytics),
      ],
      child: const SurpriseStudioApp(),
    );
  }
}

/// A representative error as the API client would raise it.
ApiException apiError(String code, {String message = 'Server message', int status = 400}) => ApiException(code: code, message: message, status: status);
