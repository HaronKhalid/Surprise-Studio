import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import 'auth_controller.dart';

/// Shown while the saved session is checked, and if that check fails (for example offline).
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: auth.hasError
          ? ErrorState(error: auth.error!, onRetry: () => ref.read(authControllerProvider.notifier).retry())
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
