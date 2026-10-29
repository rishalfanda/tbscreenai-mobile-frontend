import 'package:myapp/core/localization/app_text.dart';
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
        AppText('Account', style: Theme.of(context).textTheme.headlineMedium),
        ListTile(title: Text(auth.displayName), subtitle: Text(auth.email)),
        ListTile(title: const AppText('Role'), subtitle: Text(auth.role)),
        ListTile(title: const AppText('Tenant'), subtitle: Text(auth.tenantId)),
        const AppText(
          'Profile editing and security status unavailable: backend contract pending.',
        ),
        const OutlinedButton(
          onPressed: null,
          child: AppText('Edit profile unavailable'),
        ),
        const OutlinedButton(
          onPressed: null,
          child: AppText('Password / 2FA unavailable'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await auth.logout();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: AppText('Sign out cleanup failed. Please retry.'),
                  ),
                );
              }
            }
          },
          child: const AppText('Sign Out'),
        ),
      ],
    );
  }
}
