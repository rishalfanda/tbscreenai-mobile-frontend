import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/state/auth_provider.dart';

/// Prompts for sign-out confirmation, blocks UI interaction with a modal
/// loading indicator while [AuthProvider.logout] completes cleanup, and then
/// navigates to `/login`.
Future<void> confirmAndLogout(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  if (auth.isBusy) return;

  final confirmed = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      key: const Key('logout-confirmation-dialog'),
      title: Text(context.trRead('Keluar dari akun?', 'Sign out?')),
      content: Text(
        context.trRead(
          'Data offline yang belum disinkronkan tetap tersimpan aman di perangkat ini.',
          'Any unsynced offline data will remain safely stored on this device.',
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-logout-button'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.trRead('Batal', 'Cancel')),
        ),
        FilledButton(
          key: const Key('confirm-logout-button'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.trRead('Keluar', 'Sign out')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted || auth.isBusy) return;

  final router = GoRouter.maybeOf(context);
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final loadingRoute = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BlockingLogoutDialog(),
  );
  unawaited(rootNavigator.push(loadingRoute));

  try {
    await auth.logout();
  } catch (_) {
    // AuthProvider records logout_cleanup_failed and transitions to loggedOut.
  } finally {
    if (loadingRoute.isActive) {
      rootNavigator.removeRoute(loadingRoute);
    }
    if (context.mounted) {
      router?.go('/login');
    }
  }
}

class _BlockingLogoutDialog extends StatelessWidget {
  const _BlockingLogoutDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('logout-loading-dialog'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                context.trRead('Sedang keluar...', 'Signing out...'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
