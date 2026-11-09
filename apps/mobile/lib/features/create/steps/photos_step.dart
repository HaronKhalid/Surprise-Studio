import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/platform.dart';
import '../../../core/widgets/common.dart';
import '../../surprises/picked_image.dart';
import '../draft_controller.dart';
import '../draft_state.dart';
import 'step_layout.dart';

class PhotosStep extends ConsumerStatefulWidget {
  const PhotosStep({super.key, required this.surpriseId, required this.onContinue});
  final String? surpriseId;
  final VoidCallback onContinue;

  @override
  ConsumerState<PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends ConsumerState<PhotosStep> {
  Future<void> _pick() async {
    final draft = ref.read(draftProvider(widget.surpriseId));
    final room = maxPhotosPerSurprise - draft.photoSlotsUsed;
    try {
      final picked = await ref.read(photoPickerProvider).pickMany(room);
      if (picked.isEmpty) return;
      // Fire and forget: progress shows in the list, and one bad photo must not block the rest.
      ref.read(draftProvider(widget.surpriseId).notifier).addPhotos(picked);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftProvider(widget.surpriseId));
    final notifier = ref.read(draftProvider(widget.surpriseId).notifier);
    final theme = Theme.of(context);
    final full = draft.photoSlotsUsed >= maxPhotosPerSurprise;

    return StepLayout(
      question: 'Add your favourite photos',
      hint: 'Up to $maxPhotosPerSurprise. Drag to change the order they appear in.',
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        if (draft.photos.isEmpty && !draft.isUploading)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Most styles need at least one photo to publish.', style: theme.textTheme.bodySmall)),
        BusyButton(label: draft.isUploading ? 'Uploading…' : 'Continue', busy: draft.isUploading, onPressed: widget.onContinue),
      ]),
      children: [
        OutlinedButton.icon(
          onPressed: full ? null : _pick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(full ? 'Photo limit reached' : 'Add photos (${draft.photoSlotsUsed}/$maxPhotosPerSurprise)'),
        ),
        const SizedBox(height: 16),
        for (final u in draft.uploads) _UploadTile(upload: u, onDismiss: () => notifier.dismissUpload(u.key)),
        if (draft.photos.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: draft.photos.length,
            onReorderItem: (from, to) => _guard(() => notifier.reorder(from, to)),
            itemBuilder: (_, i) {
              final p = draft.photos[i];
              return Card(
                key: ValueKey(p.id),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(width: 56, height: 56, child: Image.network(p.thumbUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))),
                  ),
                  title: Text('Photo ${i + 1}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Remove photo ${i + 1}', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _guard(() => notifier.removePhoto(p.id))),
                    ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded))),
                  ]),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.upload, required this.onDismiss});
  final PendingUpload upload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final failed = upload.status == UploadStatus.failed;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: failed ? theme.colorScheme.errorContainer : null,
      child: ListTile(
        leading: failed ? Icon(Icons.error_outline_rounded, color: theme.colorScheme.onErrorContainer) : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
        title: Text(upload.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(failed ? friendlyError(upload.error ?? '') : 'Uploading…'),
        trailing: failed ? IconButton(tooltip: 'Dismiss', icon: const Icon(Icons.close_rounded), onPressed: onDismiss) : null,
      ),
    );
  }
}
