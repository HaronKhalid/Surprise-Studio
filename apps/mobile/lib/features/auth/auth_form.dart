import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/validators.dart';
import '../../core/widgets/common.dart';
import 'auth_controller.dart';

/// Shared by the login and register screens.
class AuthForm extends ConsumerStatefulWidget {
  const AuthForm({super.key, required this.register});

  final bool register;

  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (widget.register) {
        await auth.register(_email.text.trim(), _password.text, displayName: _name.text.trim());
      } else {
        await auth.login(_email.text.trim(), _password.text);
      }
      // Success flips auth state; the router moves us on, nothing else to do here.
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.register;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (register) ...[
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Your name (optional)'),
              validator: (v) => (v ?? '').length > 80 ? 'Keep it under 80 characters' : null,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: [register ? AutofillHints.newPassword : AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: register ? 'At least 8 characters' : null,
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: register ? validatePassword : (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
          ),
          const SizedBox(height: 24),
          BusyButton(label: register ? 'Create account' : 'Log in', busy: _busy, onPressed: _submit),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : () => context.go(register ? '/login' : '/register'),
            child: Text(register ? 'I already have an account' : 'New here? Create an account'),
          ),
        ]),
      ),
    );
  }
}
