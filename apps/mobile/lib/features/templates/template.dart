import 'dart:ui';

/// A style the creator can choose. Mirrors GET /templates (see docs/templates.md); the colours and
/// fonts here are only for *previewing choices*: the real rendering is done by the web app.
class Template {
  const Template({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.colors,
    required this.font,
    required this.customizableColors,
    required this.fonts,
    required this.minPhotos,
    required this.maxMemories,
    required this.sections,
    required this.requiredSections,
  });

  factory Template.fromJson(Map<String, dynamic> json) {
    final c = json['configuration'] as Map<String, dynamic>;
    final theme = c['theme'] as Map<String, dynamic>;
    final custom = c['customizable'] as Map<String, dynamic>;
    final limits = c['limits'] as Map<String, dynamic>;
    return Template(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: c['description'] as String,
      colors: (theme['colors'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      font: theme['font'] as String,
      customizableColors: List<String>.from(custom['colors'] as List),
      fonts: List<String>.from(custom['fonts'] as List),
      minPhotos: limits['minPhotos'] as int,
      maxMemories: limits['maxMemories'] as int,
      sections: [for (final s in c['sections'] as List) (s as Map<String, dynamic>)['type'] as String],
      requiredSections: {
        for (final s in c['sections'] as List)
          if ((s as Map<String, dynamic>)['required'] == true) s['type'] as String,
      },
    );
  }

  final String id;
  final String slug;
  final String name;
  final String description;
  final Map<String, String> colors;
  final String font;
  final List<String> customizableColors;
  final List<String> fonts;
  final int minPhotos;
  final int maxMemories;
  final List<String> sections;

  /// Section types the surprise must have content for before it can be published.
  final Set<String> requiredSections;

  bool get allowsAccent => customizableColors.contains('accent');
  bool get showsMemories => sections.contains('memory_cards');

  Color color(String key) => parseHex(colors[key] ?? '#000000');
}

/// `#rrggbb` to a [Color]. The API only ever sends six-digit hex.
Color parseHex(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

/// `#rrggbb` from a [Color], lower case, as the API expects.
String toHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0')}';
}
