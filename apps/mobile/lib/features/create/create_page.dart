import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import 'draft_controller.dart';
import 'steps/message_step.dart';
import 'steps/photos_step.dart';
import 'steps/review_step.dart';
import 'steps/style_step.dart';
import 'steps/who_step.dart';

const stepTitles = ['Who it\'s for', 'Your words', 'Photos', 'Style', 'Preview & publish'];

/// A short guided flow, one question at a time, rather than one long form. Each step saves to the
/// server when you continue, so leaving at any point keeps your draft.
class CreatePage extends ConsumerStatefulWidget {
  const CreatePage({super.key, this.surpriseId});

  /// Edit this surprise; null creates a new one.
  final String? surpriseId;

  @override
  ConsumerState<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends ConsumerState<CreatePage> {
  int _step = 0;

  void _go(int step) => setState(() => _step = step.clamp(0, stepTitles.length - 1));

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftProvider(widget.surpriseId));
    final id = widget.surpriseId;

    if (draft.loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(error: draft.loadError!, onRetry: () => ref.read(draftProvider(id).notifier).load()),
      );
    }
    if (draft.loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));

    final steps = <Widget>[
      WhoStep(surpriseId: id, onContinue: () => _go(1)),
      MessageStep(surpriseId: id, onContinue: () => _go(2)),
      PhotosStep(surpriseId: id, onContinue: () => _go(3)),
      StyleStep(surpriseId: id, onContinue: () => _go(4)),
      ReviewStep(surpriseId: id, onJump: _go),
    ];

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: _step == 0 ? 'Close' : 'Back',
            icon: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
            onPressed: () => _step == 0 ? context.pop() : _go(_step - 1),
          ),
          title: Text(stepTitles[_step]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(value: (_step + 1) / stepTitles.length, minHeight: 4),
          ),
        ),
        // Only the current step is built, so a step's controllers start from the saved draft.
        body: SafeArea(child: KeyedSubtree(key: ValueKey(_step), child: steps[_step])),
      ),
    );
  }
}
