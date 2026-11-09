import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analytics.dart';
import '../surprises/picked_image.dart';
import '../surprises/surprise.dart';
import '../templates/template.dart';
import 'draft_state.dart';

/// The creation wizard's brain. It saves to the server step by step, so a draft is never lost if
/// the app is closed mid-way and the same screens edit an existing surprise.
///
/// Methods throw the repository's [ApiException]; the screen that called shows it.
class DraftController extends Notifier<DraftState> {
  DraftController(this.surpriseId);

  /// The surprise being edited, or null to start a new one.
  final String? surpriseId;

  int _uploadKey = 0;

  @override
  DraftState build() {
    if (surpriseId == null) {
      ref.read(analyticsProvider).track(AppEvent.createStarted);
      return const DraftState();
    }
    Future.microtask(load);
    return DraftState(id: surpriseId, loading: true);
  }

  Future<void> load() async {
    final id = surpriseId;
    if (id == null) return;
    state = state.copyWith(loading: true, loadError: () => null);
    try {
      final repo = ref.read(surpriseRepositoryProvider);
      final results = await Future.wait([repo.get(id), repo.photos(id)]);
      if (!ref.mounted) return;
      final s = results[0] as Surprise;
      final photos = (results[1] as List<Photo>)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      state = DraftState(
        id: s.id,
        name: s.recipientName,
        nickname: s.recipientNickname ?? '',
        relationship: s.relationship,
        message: s.message ?? '',
        intro: s.intro ?? '',
        ending: s.ending ?? '',
        memories: s.memories,
        templateId: s.templateId,
        accent: s.accent,
        font: s.font,
        photos: photos,
      );
    } catch (e) {
      if (ref.mounted) state = state.copyWith(loading: false, loadError: () => e);
    }
  }

  // ---- step 1: who ----

  Future<void> saveWho({required String name, required String nickname, String? relationship}) async {
    final repo = ref.read(surpriseRepositoryProvider);
    final changes = SurpriseChanges(recipientName: name.trim(), recipientNickname: nickname.trim(), relationship: relationship);
    if (state.id == null) {
      final created = await repo.create(changes);
      ref.read(analyticsProvider).track(AppEvent.surpriseCreated);
      state = state.copyWith(id: created.id);
    } else {
      await repo.update(state.id!, changes);
    }
    state = state.copyWith(name: name.trim(), nickname: nickname.trim(), relationship: () => relationship);
  }

  // ---- step 2: message and memories ----

  Future<void> saveMessage({required String message, String intro = '', String ending = '', List<Memory> memories = const []}) async {
    await ref.read(surpriseRepositoryProvider).update(
          state.id!,
          SurpriseChanges(message: message.trim(), content: ContentValue(intro: intro.trim(), ending: ending.trim(), memories: memories)),
        );
    state = state.copyWith(message: message.trim(), intro: intro.trim(), ending: ending.trim(), memories: memories);
  }

  // ---- step 3: photos ----

  /// Uploads one at a time. Each photo shows as pending, then either joins [DraftState.photos]
  /// or stays listed as failed until dismissed. A failure never aborts the rest.
  Future<void> addPhotos(List<PickedImage> images) async {
    final repo = ref.read(surpriseRepositoryProvider);
    for (final image in images) {
      if (state.photoSlotsUsed >= maxPhotosPerSurprise) break;
      final key = ++_uploadKey;
      state = state.copyWith(uploads: [...state.uploads, PendingUpload(key: key, name: image.name, status: UploadStatus.uploading)]);
      try {
        final photo = await repo.uploadPhoto(state.id!, image);
        if (!ref.mounted) return;
        ref.read(analyticsProvider).track(AppEvent.photoUploaded);
        state = state.copyWith(
          uploads: [for (final u in state.uploads) if (u.key != key) u],
          photos: [...state.photos, photo],
        );
      } catch (e) {
        if (!ref.mounted) return;
        state = state.copyWith(
          uploads: [for (final u in state.uploads) u.key == key ? PendingUpload(key: key, name: image.name, status: UploadStatus.failed, error: e) : u],
        );
      }
    }
  }

  void dismissUpload(int key) => state = state.copyWith(uploads: [for (final u in state.uploads) if (u.key != key) u]);

  Future<void> removePhoto(String photoId) async {
    final before = state.photos;
    state = state.copyWith(photos: [for (final p in before) if (p.id != photoId) p]);
    try {
      await ref.read(surpriseRepositoryProvider).deletePhoto(photoId);
    } catch (_) {
      state = state.copyWith(photos: before); // it is still on the server, so put it back
      rethrow;
    }
  }

  /// [newIndex] is where the photo ends up (what ReorderableListView.onReorderItem reports).
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final list = [...state.photos];
    list.insert(newIndex, list.removeAt(oldIndex));
    final reordered = [for (var i = 0; i < list.length; i++) list[i].withSortOrder(i)];
    final changed = [for (var i = 0; i < reordered.length; i++) if (state.photos.length > i && state.photos.firstWhere((p) => p.id == reordered[i].id).sortOrder != i) reordered[i]];
    state = state.copyWith(photos: reordered);
    final repo = ref.read(surpriseRepositoryProvider);
    try {
      for (final p in changed) {
        await repo.setPhotoOrder(p.id, p.sortOrder);
      }
    } catch (_) {
      // Partly applied on the server: reload the truth rather than guess.
      final fresh = await repo.photos(state.id!);
      if (ref.mounted) state = state.copyWith(photos: fresh..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));
      rethrow;
    }
  }

  // ---- step 4: style ----

  /// Choosing a different template clears the colour and font overrides on the server (they were
  /// picked for the old one), so they are cleared here too.
  Future<void> chooseTemplate(Template template) async {
    if (template.id == state.templateId) return;
    await ref.read(surpriseRepositoryProvider).update(state.id!, SurpriseChanges(templateId: template.id));
    ref.read(analyticsProvider).track(AppEvent.templateSelected, template: template.slug);
    state = state.copyWith(templateId: () => template.id, accent: () => null, font: () => null);
  }

  Future<void> saveTheme({String? accent, String? font}) async {
    await ref.read(surpriseRepositoryProvider).update(state.id!, SurpriseChanges(theme: ThemeValue(accent: accent, font: font)));
    state = state.copyWith(accent: () => accent, font: () => font);
  }

  // ---- step 5: publish ----

  Future<Surprise> publish() async {
    final s = await ref.read(surpriseRepositoryProvider).publish(state.id!);
    ref.read(analyticsProvider).track(AppEvent.surprisePublished);
    return s;
  }
}

final draftProvider =
    NotifierProvider.autoDispose.family<DraftController, DraftState, String?>(DraftController.new);
