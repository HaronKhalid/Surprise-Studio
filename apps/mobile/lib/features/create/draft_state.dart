import '../surprises/surprise.dart';

enum UploadStatus { uploading, failed }

/// A photo that is on its way up, or failed. Confirmed photos live in [DraftState.photos].
class PendingUpload {
  const PendingUpload({required this.key, required this.name, required this.status, this.error});
  final int key;
  final String name;
  final UploadStatus status;
  final Object? error;
}

/// Everything the creation wizard knows. Immutable: the controller replaces it on every change.
class DraftState {
  const DraftState({
    this.id,
    this.loading = false,
    this.loadError,
    this.name = '',
    this.nickname = '',
    this.relationship,
    this.message = '',
    this.intro = '',
    this.ending = '',
    this.memories = const [],
    this.templateId,
    this.accent,
    this.font,
    this.photos = const [],
    this.uploads = const [],
  });

  /// Null until the first step has been saved: the surprise is created on the server then.
  final String? id;
  final bool loading;

  /// Set if an existing draft could not be loaded.
  final Object? loadError;
  final String name;
  final String nickname;
  final String? relationship;
  final String message;
  final String intro;
  final String ending;
  final List<Memory> memories;
  final String? templateId;
  final String? accent;
  final String? font;
  final List<Photo> photos;
  final List<PendingUpload> uploads;

  bool get isUploading => uploads.any((u) => u.status == UploadStatus.uploading);

  /// Counts photos in flight against the limit, so quick repeated picks cannot exceed it.
  int get photoSlotsUsed => photos.length + uploads.where((u) => u.status == UploadStatus.uploading).length;

  DraftState copyWith({
    String? id,
    bool? loading,
    Object? Function()? loadError,
    String? name,
    String? nickname,
    String? Function()? relationship,
    String? message,
    String? intro,
    String? ending,
    List<Memory>? memories,
    String? Function()? templateId,
    String? Function()? accent,
    String? Function()? font,
    List<Photo>? photos,
    List<PendingUpload>? uploads,
  }) =>
      DraftState(
        id: id ?? this.id,
        loading: loading ?? this.loading,
        loadError: loadError != null ? loadError() : this.loadError,
        name: name ?? this.name,
        nickname: nickname ?? this.nickname,
        relationship: relationship != null ? relationship() : this.relationship,
        message: message ?? this.message,
        intro: intro ?? this.intro,
        ending: ending ?? this.ending,
        memories: memories ?? this.memories,
        templateId: templateId != null ? templateId() : this.templateId,
        accent: accent != null ? accent() : this.accent,
        font: font != null ? font() : this.font,
        photos: photos ?? this.photos,
        uploads: uploads ?? this.uploads,
      );
}
