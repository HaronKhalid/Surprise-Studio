import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contrast.dart';
import '../../../core/widgets/common.dart';
import '../../surprises/surprise_providers.dart';
import '../../templates/template.dart';
import '../draft_controller.dart';
import 'step_layout.dart';

/// Accent colours offered on top of each template's own. Filtered per template so only readable
/// ones appear (the server rejects anything below 3:1 against the background).
const accentPalette = ['#e63d7a', '#ff7a1a', '#d4af37', '#2bb673', '#2f80ed', '#8e5cf7', '#00b8a9', '#ff5252'];
const _minAccentContrast = 3.0;

const fontLabels = {
  'playfair': 'Playfair',
  'cormorant': 'Cormorant',
  'dm-serif': 'DM Serif',
  'inter': 'Inter',
  'poppins': 'Poppins',
};

/// The accents a creator can pick for [t]: its own default first, then palette colours that stay
/// readable on its background.
List<String> readableAccents(Template t) {
  final bg = t.color('background');
  final fromPalette = [for (final hex in accentPalette) if (contrastRatio(parseHex(hex), bg) >= _minAccentContrast) hex];
  return [t.colors['accent']!, ...fromPalette.where((h) => h != t.colors['accent'])];
}

class StyleStep extends ConsumerStatefulWidget {
  const StyleStep({super.key, required this.surpriseId, required this.onContinue});
  final String? surpriseId;
  final VoidCallback onContinue;

  @override
  ConsumerState<StyleStep> createState() => _StyleStepState();
}

class _StyleStepState extends ConsumerState<StyleStep> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftProvider(widget.surpriseId));
    final notifier = ref.read(draftProvider(widget.surpriseId).notifier);
    final templates = ref.watch(templatesProvider);
    final theme = Theme.of(context);

    return templates.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(templatesProvider)),
      data: (list) {
        Template? selected;
        for (final t in list) {
          if (t.id == draft.templateId) selected = t;
        }
        return StepLayout(
          question: 'Pick a style',
          hint: 'You\'ll preview it before anything is shared.',
          footer: BusyButton(label: 'Continue', busy: _busy, onPressed: selected == null ? null : widget.onContinue),
          children: [
            for (final t in list) ...[
              _TemplateCard(template: t, selected: t.id == draft.templateId, hasMemories: draft.memories.isNotEmpty, onTap: _busy ? null : () => _run(() => notifier.chooseTemplate(t))),
              const SizedBox(height: 12),
            ],
            if (selected != null && selected.allowsAccent) ...[
              const SizedBox(height: 12),
              Text('Accent colour', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final hex in readableAccents(selected))
                  _Swatch(
                    color: parseHex(hex),
                    selected: (draft.accent ?? selected.colors['accent']) == hex,
                    onTap: _busy ? null : () => _run(() => notifier.saveTheme(accent: hex == selected!.colors['accent'] ? null : hex, font: draft.font)),
                  ),
              ]),
            ],
            if (selected != null && selected.fonts.length > 1) ...[
              const SizedBox(height: 20),
              Text('Font', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in selected.fonts)
                  ChoiceChip(
                    label: Text(fontLabels[f] ?? f),
                    selected: (draft.font ?? selected.font) == f,
                    onSelected: _busy ? null : (_) => _run(() => notifier.saveTheme(accent: draft.accent, font: f == selected!.font ? null : f)),
                  ),
              ]),
            ],
          ],
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.selected, required this.hasMemories, required this.onTap});
  final Template template;
  final bool selected;
  final bool hasMemories;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      selected: selected,
      button: true,
      label: '${template.name} style',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: selected ? 2.5 : 1),
          ),
          child: Row(children: [
            // A little swatch of the style's own background, surface and accent.
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: template.color('background'),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 44, height: 8, decoration: BoxDecoration(color: template.color('accent'), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: 32, height: 6, decoration: BoxDecoration(color: template.color('text').withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 5),
                Container(width: 38, height: 6, decoration: BoxDecoration(color: template.color('surface'), borderRadius: BorderRadius.circular(3))),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(template.name, style: theme.textTheme.titleMedium)),
                    if (selected) Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
                  ]),
                  const SizedBox(height: 2),
                  Text(template.description, style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (hasMemories && !template.showsMemories)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text('Memories aren\'t shown in this style', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary))),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: 'Accent ${toHex(color)}',
      child: InkResponse(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent, width: 3),
          ),
          child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
        ),
      ),
    );
  }
}
