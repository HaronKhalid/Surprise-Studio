import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../auth/auth_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
    // The router sends us to the login screen; nothing else to do.
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final password = await showDialog<String>(context: context, builder: (_) => const _DeleteAccountDialog());
    if (password == null || !context.mounted) return;
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount(password);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        ListTile(leading: const Icon(Icons.person_outline_rounded), title: Text(user?.displayName?.isNotEmpty == true ? user!.displayName! : 'Your account'), subtitle: Text(user?.email ?? '')),
        const Divider(),
        ListTile(leading: const Icon(Icons.logout_rounded), title: const Text('Log out'), onTap: () => _logout(context, ref)),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
          title: Text('Delete account', style: TextStyle(color: theme.colorScheme.error)),
          subtitle: const Text('Permanently deletes your account, surprises and photos'),
          onTap: () => _deleteAccount(context, ref),
        ),
      ]),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Every surprise you made stops working and all your photos are permanently deleted. This can\'t be undone.'),
        const SizedBox(height: 16),
        TextField(controller: _password, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'Enter your password to confirm'), onChanged: (_) => setState(() {})),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: _password.text.isEmpty ? null : () => Navigator.of(context).pop(_password.text),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Delete everything'),
        ),
      ],
    );
  }
}
