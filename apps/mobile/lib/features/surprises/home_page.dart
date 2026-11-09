import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/widgets/common.dart';
import 'surprise.dart';
import 'surprise_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await context.push('/create');
    ref.invalidate(surprisesProvider); // the draft may have been created or published
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surprises = ref.watch(surprisesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your surprises'),
        actions: [IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings'))],
      ),
      floatingActionButton: surprises.hasValue && surprises.value!.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create surprise'),
            )
          : null,
      body: surprises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(surprisesProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            try {
              await ref.read(surprisesProvider.notifier).refresh();
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
          child: items.isEmpty
              ? _Empty(onCreate: () => _create(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _SurpriseCard(
                    surprise: items[i],
                    onTap: () async {
                      await context.push('/surprise/${items[i].id}');
                      ref.invalidate(surprisesProvider);
                    },
                  ),
                ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scrollable so pull-to-refresh still works on an empty screen.
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
      SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.card_giftcard_rounded, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text('Nothing here yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Create a surprise for someone you love.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create a surprise'),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _SurpriseCard extends StatelessWidget {
  const _SurpriseCard({required this.surprise, required this.onTap});
  final Surprise surprise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final published = surprise.isPublished;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: published ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
              child: Icon(published ? Icons.link_rounded : Icons.edit_note_rounded,
                  color: published ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(surprise.displayName, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${published ? 'Published' : 'Draft'} · ${relativeTime(surprise.updatedAt)}', style: theme.textTheme.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      ),
    );
  }
}
