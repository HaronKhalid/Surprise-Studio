import 'package:flutter/material.dart';

import 'auth_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => const _AuthScaffold(title: 'Welcome back', subtitle: 'Log in to keep creating.', register: false);
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.register});
  final String title;
  final String subtitle;
  final bool register;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.card_giftcard_rounded, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(subtitle, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                AuthForm(register: register),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
