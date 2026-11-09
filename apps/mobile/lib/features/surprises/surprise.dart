enum SurpriseStatus {
  draft,
  published,
  archived,
  deleted;

  static SurpriseStatus parse(String value) =>
      SurpriseStatus.values.firstWhere((s) => s.name == value.toLowerCase(), orElse: () => SurpriseStatus.draft);
}

class Memory {
  const Memory({this.title, required this.text});

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(title: json['title'] as String?, text: json['text'] as String);

  final String? title;
  final String text;

  Map<String, dynamic> toJson() => {if (title != null && title!.isNotEmpty) 'title': title, 'text': text};
}

/// A surprise as the creator sees it (GET /surprises, /surprises/:id).
class Surprise {
  const Surprise({
    required this.id,
    required this.recipientName,
    required this.status,
    required this.updatedAt,
    this.recipientNickname,
    this.relationship,
    this.message,
    this.templateId,
    this.slug,
    this.intro,
    this.ending,
    this.memories = const [],
    this.accent,
    this.font,
  });

  factory Surprise.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as Map<String, dynamic>?) ?? const {};
    final theme = (json['theme'] as Map<String, dynamic>?) ?? const {};
    final colors = (theme['colors'] as Map<String, dynamic>?) ?? const {};
    return Surprise(
      id: json['id'] as String,
      recipientName: json['recipientName'] as String,
      recipientNickname: json['recipientNickname'] as String?,
      relationship: json['relationship'] as String?,
      message: json['message'] as String?,
      templateId: json['templateId'] as String?,
      slug: json['slug'] as String?,
      status: SurpriseStatus.parse(json['status'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      intro: content['intro'] as String?,
      ending: content['ending'] as String?,
      memories: [for (final m in (content['memories'] as List?) ?? const []) Memory.fromJson(m as Map<String, dynamic>)],
      accent: colors['accent'] as String?,
      font: theme['font'] as String?,
    );
  }

  final String id;
  final String recipientName;
  final String? recipientNickname;
  final String? relationship;
  final String? message;
  final String? templateId;
  final String? slug;
  final SurpriseStatus status;
  final DateTime updatedAt;
  final String? intro;
  final String? ending;
  final List<Memory> memories;
  final String? accent;
  final String? font;

  bool get isPublished => status == SurpriseStatus.published && slug != null;
  String get displayName => (recipientNickname?.trim().isNotEmpty ?? false) ? recipientNickname!.trim() : recipientName;
}

/// A confirmed, processed photo (GET /assets).
class Photo {
  const Photo({required this.id, required this.sortOrder, required this.thumbUrl, required this.mediumUrl, this.width, this.height});

  factory Photo.fromJson(Map<String, dynamic> json) {
    final urls = json['urls'] as Map<String, dynamic>;
    return Photo(
      id: json['id'] as String,
      sortOrder: json['sortOrder'] as int,
      width: json['width'] as int?,
      height: json['height'] as int?,
      thumbUrl: urls['thumb'] as String,
      mediumUrl: urls['medium'] as String,
    );
  }

  final String id;
  final int sortOrder;
  final int? width;
  final int? height;
  final String thumbUrl;
  final String mediumUrl;

  Photo withSortOrder(int order) =>
      Photo(id: id, sortOrder: order, thumbUrl: thumbUrl, mediumUrl: mediumUrl, width: width, height: height);
}

/// Content is written as a unit: the API replaces it wholesale, so a partial value would erase the rest.
class ContentValue {
  const ContentValue({this.intro = '', this.ending = '', this.memories = const []});

  final String intro;
  final String ending;
  final List<Memory> memories;

  Map<String, dynamic> toJson() => {
        'intro': intro,
        'ending': ending,
        'memories': [for (final m in memories) m.toJson()],
      };
}

/// Theme overrides, also replaced wholesale. An empty value (no accent, no font) resets to the
/// template's own look.
class ThemeValue {
  const ThemeValue({this.accent, this.font});

  final String? accent;
  final String? font;

  Map<String, dynamic> toJson() => {
        if (accent != null) 'colors': {'accent': accent},
        if (font != null) 'font': font,
      };
}

/// The editable fields. A null field is left unchanged; only what is set is sent. [content] and
/// [theme] are whole values for the reason given on their classes.
class SurpriseChanges {
  const SurpriseChanges({
    this.recipientName,
    this.recipientNickname,
    this.relationship,
    this.message,
    this.templateId,
    this.content,
    this.theme,
  });

  final String? recipientName;
  final String? recipientNickname;
  final String? relationship;
  final String? message;
  final String? templateId;
  final ContentValue? content;
  final ThemeValue? theme;

  Map<String, dynamic> toJson() => {
        if (recipientName != null) 'recipientName': recipientName,
        if (recipientNickname != null) 'recipientNickname': recipientNickname,
        if (relationship != null) 'relationship': relationship,
        if (message != null) 'message': message,
        if (templateId != null) 'templateId': templateId,
        if (content != null) 'content': content!.toJson(),
        if (theme != null) 'theme': theme!.toJson(),
      };
}
