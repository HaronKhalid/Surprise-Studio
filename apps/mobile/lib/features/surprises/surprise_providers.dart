import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../templates/template.dart';
import 'surprise.dart';

/// The creator's surprises, newest first (the API sorts them).
class SurprisesNotifier extends AsyncNotifier<List<Surprise>> {
  @override
  Future<List<Surprise>> build() => ref.read(surpriseRepositoryProvider).list();

  /// Pull-to-refresh. On failure the previous list stays visible and the error is rethrown for a
  /// snackbar, instead of replacing everything with an error screen.
  Future<void> refresh() async {
    final fresh = await ref.read(surpriseRepositoryProvider).list();
    state = AsyncData(fresh);
  }
}

final surprisesProvider = AsyncNotifierProvider<SurprisesNotifier, List<Surprise>>(SurprisesNotifier.new);

/// One surprise, always fetched fresh when its screen opens.
final surpriseProvider =
    FutureProvider.autoDispose.family<Surprise, String>((ref, id) => ref.read(surpriseRepositoryProvider).get(id));

/// Templates change rarely and the API caches them for five minutes, so keep them for the session.
final templatesProvider = FutureProvider<List<Template>>((ref) => ref.read(templateRepositoryProvider).list());
