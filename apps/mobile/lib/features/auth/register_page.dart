import 'package:flutter/material.dart';

import 'auth_form.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

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
                Text('Create your account', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('It takes a few seconds.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                const AuthForm(register: true),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
