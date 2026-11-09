import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../surprises/surprise_providers.dart';
import '../../templates/template.dart';
import '../draft_controller.dart';
import '../draft_state.dart';

/// One line of the "ready to publish" checklist.
class Requirement {
  const Requirement({required this.label, required this.met, required this.step});
  final String label;
  final bool met;

  /// The wizard step that fixes it.
  final int step;
}

/// What this surprise still needs before the server will publish it. The same rules as the
/// server's (apps/api/src/templates/template-config.ts); the server stays the authority, this
/// just says so up front instead of after a failed tap.
List<Requirement> publishRequirements(DraftState d, Template? t) {
  final reqs = <Requirement>[
    Requirement(label: 'Their name', met: d.name.trim().isNotEmpty, step: 0),
    Requirement(label: 'A style', met: t != null, step: 3),
  ];
  if (t == null) return reqs;
  if (t.requiredSections.contains('photo_gallery')) {
    final need = t.minPhotos < 1 ? 1 : t.minPhotos;
    reqs.add(Requirement(label: need == 1 ? 'At least 1 photo' : 'At least $need photos', met: d.photos.length >= need, step: 2));
  }
  if (t.requiredSections.contains('message')) {
    reqs.add(Requirement(label: 'A message', met: d.message.trim().isNotEmpty, step: 1));
  }
  if (t.requiredSections.contains('memory_cards')) {
    reqs.add(Requirement(label: 'At least 1 memory', met: d.memories.isNotEmpty, step: 1));
  }
  return reqs;
}

class ReviewStep extends ConsumerStatefulWidget {
  const ReviewStep({super.key, required this.surpriseId, required this.onJump});
  final String? surpriseId;
  final void Function(int step) onJump;

  @override
  ConsumerState<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<ReviewStep> {
  bool _publishing = false;

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final s = await ref.read(draftProvider(widget.surpriseId).notifier).publish();
      ref.invalidate(surprisesProvider);
      if (mounted) context.go('/surprise/${s.id}/published');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftProvider(widget.surpriseId));
    final templates = ref.watch(templatesProvider).value;
    Template? template;
    for (final t in templates ?? const <Template>[]) {
      if (t.id == draft.templateId) template = t;
    }
    final reqs = publishRequirements(draft, template);
    final ready = reqs.every((r) => r.met);
    final theme = Theme.of(context);

    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12), children: [
          Text('Almost there', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(ready ? 'Take a look, then publish to get your link.' : 'A couple of things are still missing.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          Card(
            child: Column(children: [
              for (final r in reqs)
                ListTile(
                  leading: Icon(r.met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: r.met ? theme.colorScheme.primary : theme.colorScheme.error),
                  title: Text(r.label),
                  trailing: r.met ? null : TextButton(onPressed: () => widget.onJump(r.step), child: const Text('Fix')),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: draft.id == null || template == null ? null : () => context.push('/surprise/${draft.id}/preview'),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Preview'),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: BusyButton(label: 'Publish', icon: Icons.rocket_launch_outlined, busy: _publishing, onPressed: ready ? _publish : null),
      ),
    ]);
  }
}
