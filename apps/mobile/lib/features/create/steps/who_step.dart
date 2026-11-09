import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validators.dart';
import '../../../core/widgets/common.dart';
import '../draft_controller.dart';
import 'step_layout.dart';

const relationships = ['Friend', 'Best friend', 'Partner', 'Sibling', 'Parent', 'Child', 'Colleague', 'Other'];

class WhoStep extends ConsumerStatefulWidget {
  const WhoStep({super.key, required this.surpriseId, required this.onContinue});
  final String? surpriseId;
  final VoidCallback onContinue;

  @override
  ConsumerState<WhoStep> createState() => _WhoStepState();
}

class _WhoStepState extends ConsumerState<WhoStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nickname;
  String? _relationship;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final d = ref.read(draftProvider(widget.surpriseId));
    _name = TextEditingController(text: d.name);
    _nickname = TextEditingController(text: d.nickname);
    _relationship = d.relationship;
  }

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(draftProvider(widget.surpriseId).notifier).saveWho(name: _name.text, nickname: _nickname.text, relationship: _relationship);
      if (mounted) widget.onContinue();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: StepLayout(
        question: 'Who is this surprise for?',
        hint: 'Their name appears at the very start.',
        footer: BusyButton(label: 'Continue', busy: _busy, onPressed: _continue),
        children: [
          TextFormField(
            controller: _name,
            autofocus: widget.surpriseId == null,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Their name'),
            validator: (v) => validateRequired(v, message: 'Enter their name'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nickname,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'What do you call them? (optional)', helperText: 'If set, this is the name shown on the page'),
            validator: (v) => (v ?? '').trim().length > 80 ? 'Keep it under 80 characters' : null,
          ),
          const SizedBox(height: 24),
          Text('They are your…', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in relationships)
              ChoiceChip(
                label: Text(r),
                selected: _relationship == r,
                // Tapping the selected chip again clears it: the relationship is optional.
                onSelected: (on) => setState(() => _relationship = on ? r : null),
              ),
          ]),
        ],
      ),
    );
  }
}
