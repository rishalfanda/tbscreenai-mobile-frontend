import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/state/auth_provider.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Account', style: Theme.of(context).textTheme.headlineMedium),
        ListTile(title: Text(auth.displayName), subtitle: Text(auth.email)),
        ListTile(title: const Text('Role'), subtitle: Text(auth.role)),
        ListTile(title: const Text('Tenant'), subtitle: Text(auth.tenantId)),
        const Text(
          'Profile editing and security status unavailable: backend contract pending.',
        ),
        const OutlinedButton(
          onPressed: null,
          child: Text('Edit profile unavailable'),
        ),
        const OutlinedButton(
          onPressed: null,
          child: Text('Password / 2FA unavailable'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await auth.logout();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign out cleanup failed. Please retry.'),
                  ),
                );
              }
            }
          },
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
}
