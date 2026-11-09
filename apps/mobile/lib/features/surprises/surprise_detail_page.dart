import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/analytics.dart';
import '../../core/format.dart';
import '../../core/platform.dart';
import '../../core/widgets/common.dart';
import 'surprise.dart';
import 'surprise_providers.dart';

class SurpriseDetailPage extends ConsumerStatefulWidget {
  const SurpriseDetailPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<SurpriseDetailPage> createState() => _SurpriseDetailPageState();
}

class _SurpriseDetailPageState extends ConsumerState<SurpriseDetailPage> {
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

  Future<void> _delete(Surprise s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${s.displayName}\'s surprise?'),
        content: const Text('The link stops working immediately and the photos are permanently deleted. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await ref.read(surpriseRepositoryProvider).delete(s.id);
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(surpriseProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Surprise')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(surpriseProvider(widget.id))),
        data: (s) => _Body(surprise: s, busy: _busy, onDelete: () => _delete(s), run: _run, refresh: () => ref.invalidate(surpriseProvider(widget.id))),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.surprise, required this.busy, required this.onDelete, required this.run, required this.refresh});

  final Surprise surprise;
  final bool busy;
  final VoidCallback onDelete;
  final Future<void> Function(Future<void> Function()) run;
  final VoidCallback refresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = surprise;
    final link = s.slug == null ? null : ref.read(configProvider).publicLink(s.slug!);
    final repo = ref.read(surpriseRepositoryProvider);

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(s.displayName, style: theme.textTheme.headlineMedium),
      const SizedBox(height: 4),
      Text('${s.isPublished ? 'Published' : 'Draft'} · edited ${relativeTime(s.updatedAt)}', style: theme.textTheme.bodyMedium),
      if ((s.message ?? '').isNotEmpty) ...[
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(s.message!, maxLines: 5, overflow: TextOverflow.ellipsis))),
      ],
      if (s.isPublished && link != null) ...[
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Their link', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SelectableText(link, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.primary)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(sharerProvider).copy(link);
                if (context.mounted) showMessage(context, 'Link copied');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                ref.read(analyticsProvider).track(AppEvent.shareClicked);
                ref.read(sharerProvider).shareText('I made a surprise for you 🎁\n$link');
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share'),
            ),
          ),
        ]),
      ],
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: s.templateId == null ? null : () => context.push('/surprise/${s.id}/preview'),
        icon: const Icon(Icons.visibility_outlined),
        label: Text(s.templateId == null ? 'Pick a style to preview' : 'Preview'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: busy
            ? null
            : () async {
                await context.push('/create?id=${s.id}');
                refresh();
              },
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      const SizedBox(height: 12),
      if (s.isPublished)
        OutlinedButton.icon(
          onPressed: busy ? null : () => run(() async { await repo.unpublish(s.id); refresh(); if (context.mounted) showMessage(context, 'Unpublished. The link no longer works.'); }),
          icon: const Icon(Icons.link_off_rounded),
          label: const Text('Unpublish'),
        )
      else
        BusyButton(
          label: 'Publish',
          icon: Icons.rocket_launch_outlined,
          busy: busy,
          onPressed: () => run(() async {
            await repo.publish(s.id);
            ref.read(analyticsProvider).track(AppEvent.surprisePublished);
            if (context.mounted) context.go('/surprise/${s.id}/published');
          }),
        ),
      const SizedBox(height: 32),
      TextButton.icon(
        onPressed: busy ? null : onDelete,
        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Delete surprise'),
      ),
    ]);
  }
}
