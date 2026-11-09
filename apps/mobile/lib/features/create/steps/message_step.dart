import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../../surprises/surprise.dart';
import '../draft_controller.dart';
import 'step_layout.dart';

const _maxMemories = 10;

class MessageStep extends ConsumerStatefulWidget {
  const MessageStep({super.key, required this.surpriseId, required this.onContinue});
  final String? surpriseId;
  final VoidCallback onContinue;

  @override
  ConsumerState<MessageStep> createState() => _MessageStepState();
}

class _MessageStepState extends ConsumerState<MessageStep> {
  late final TextEditingController _message;
  late final TextEditingController _intro;
  late final TextEditingController _ending;
  late List<Memory> _memories;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final d = ref.read(draftProvider(widget.surpriseId));
    _message = TextEditingController(text: d.message);
    _intro = TextEditingController(text: d.intro);
    _ending = TextEditingController(text: d.ending);
    _memories = [...d.memories];
  }

  @override
  void dispose() {
    _message.dispose();
    _intro.dispose();
    _ending.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(draftProvider(widget.surpriseId).notifier)
          .saveMessage(message: _message.text, intro: _intro.text, ending: _ending.text, memories: _memories);
      if (mounted) widget.onContinue();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMemory() async {
    final memory = await showModalBottomSheet<Memory>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _MemorySheet(),
    );
    if (memory != null) setState(() => _memories = [..._memories, memory]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StepLayout(
      question: 'What do you want to say?',
      hint: 'Write it the way you\'d say it to them.',
      footer: BusyButton(label: 'Continue', busy: _busy, onPressed: _continue),
      children: [
        TextField(
          controller: _message,
          minLines: 5,
          maxLines: 10,
          maxLength: 5000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Your message', alignLabelWithHint: true),
        ),
        const SizedBox(height: 16),
        Text('Memories', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Little moments you share. Some styles show them as cards.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        for (var i = 0; i < _memories.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(_memories[i].title?.isNotEmpty == true ? _memories[i].title! : _memories[i].text, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: _memories[i].title?.isNotEmpty == true ? Text(_memories[i].text, maxLines: 2, overflow: TextOverflow.ellipsis) : null,
              trailing: IconButton(
                tooltip: 'Remove memory',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _memories = [..._memories]..removeAt(i)),
              ),
            ),
          ),
        if (_memories.length < _maxMemories)
          OutlinedButton.icon(onPressed: _addMemory, icon: const Icon(Icons.add_rounded), label: const Text('Add a memory')),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('More (optional)'),
          children: [
            TextField(
              controller: _intro,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'A line to open with', helperText: 'Shown under their name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ending,
              maxLength: 600,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Closing words', helperText: 'Revealed at the very end'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MemorySheet extends StatefulWidget {
  const _MemorySheet();

  @override
  State<_MemorySheet> createState() => _MemorySheetState();
}

class _MemorySheetState extends State<_MemorySheet> {
  final _title = TextEditingController();
  final _text = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: _title, maxLength: 80, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Title (optional)', hintText: 'The road trip')),
        const SizedBox(height: 8),
        TextField(
          controller: _text,
          autofocus: true,
          maxLength: 500,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'The memory'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _text.text.trim().isEmpty ? null : () => Navigator.of(context).pop(Memory(title: _title.text.trim(), text: _text.text.trim())),
          child: const Text('Add'),
        ),
      ]),
    );
  }
}
