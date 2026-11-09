import 'package:flutter/material.dart';

/// The common shape of a step: a question, scrollable content, and a pinned continue button.
class StepLayout extends StatelessWidget {
  const StepLayout({super.key, required this.question, this.hint, required this.children, required this.footer});

  final String question;
  final String? hint;
  final List<Widget> children;

  /// The pinned bottom area (usually the continue button).
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 12), children: [
          Text(question, style: theme.textTheme.headlineSmall),
          if (hint != null) ...[const SizedBox(height: 6), Text(hint!, style: theme.textTheme.bodyMedium)],
          const SizedBox(height: 20),
          ...children,
        ]),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: footer),
    ]);
  }
}
