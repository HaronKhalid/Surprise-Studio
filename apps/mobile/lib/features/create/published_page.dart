import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/analytics.dart';
import '../../core/platform.dart';
import '../../core/widgets/common.dart';
import '../surprises/surprise_providers.dart';


/// The payoff screen: the link, and the quickest ways to send it.
class PublishedPage extends ConsumerWidget {
  const PublishedPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(surpriseProvider(id));
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(surpriseProvider(id))),
          data: (s) {
            final link = s.slug == null ? null : ref.read(configProvider).publicLink(s.slug!);
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Spacer(),
                Icon(Icons.celebration_rounded, size: 88, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text('Your surprise is ready!', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Send ${s.displayName} this link. It opens in their browser.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (link != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(link, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                    ),
                  ),
                const Spacer(),
                if (link != null) ...[
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(analyticsProvider).track(AppEvent.shareClicked);
                      ref.read(sharerProvider).shareText('I made a surprise for you 🎁\n$link');
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                  const SizedBox(height: 12),
                  _CopyLinkButton(link: link),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    ref.invalidate(surprisesProvider); // the list must show this as published
                    context.go('/');
                  },
                  child: const Text('Done'),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Copies the link and says so on the button itself. A snackbar would float over the buttons below it.
class _CopyLinkButton extends ConsumerStatefulWidget {
  const _CopyLinkButton({required this.link});
  final String link;

  @override
  ConsumerState<_CopyLinkButton> createState() => _CopyLinkButtonState();
}

class _CopyLinkButtonState extends ConsumerState<_CopyLinkButton> {
  Timer? _reset;
  bool _copied = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await ref.read(sharerProvider).copy(widget.link);
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _copy,
      icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded),
      label: Text(_copied ? 'Copied' : 'Copy link'),
    );
  }
}
