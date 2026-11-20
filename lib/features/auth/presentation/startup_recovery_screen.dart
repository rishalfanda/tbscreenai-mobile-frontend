import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/localization/language_toggle.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/features/auth/presentation/auth_frame.dart';

enum StartupErrorKind { none, storageUnavailable, corruptedIdentity }

/// Recovery UI rendered before routing when device identity cannot be read on
/// startup. Offers retry and a clinical-data-preserving registration reset.
class StartupRecoveryScreen extends StatelessWidget {
  const StartupRecoveryScreen({
    super.key,
    required this.errorKind,
    required this.busy,
    required this.onRetry,
    required this.onResetActivation,
    this.recoveryError,
  });

  final StartupErrorKind errorKind;
  final bool busy;
  final String? recoveryError;
  final VoidCallback onRetry;
  final VoidCallback onResetActivation;

  bool get _isCorrupted => errorKind == StartupErrorKind.corruptedIdentity;

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.trRead(
            'Reset aktivasi tablet?',
            'Reset tablet activation?',
          ),
        ),
        content: Text(
          context.trRead(
            'Pendaftaran tablet pada penyimpanan aman akan dihapus agar Anda dapat memasukkan ulang kode aktivasi. Arsip klinis, antrean sinkronisasi, dan citra terenkripsi tetap aman.',
            'Tablet registration in secure storage will be cleared so you can re-enter your activation code. Clinical archives, sync queues, and encrypted images stay preserved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.trRead('Batal', 'Cancel')),
          ),
          FilledButton(
            key: const Key('startup-confirm-reset-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.trRead('Reset', 'Reset')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onResetActivation();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();

    final title = _isCorrupted
        ? context.trRead(
            'Data aktivasi tablet rusak',
            'Tablet activation data corrupted',
          )
        : context.trRead(
            'Penyimpanan perangkat belum siap',
            'Device storage unavailable',
          );

    final description = _isCorrupted
        ? context.trRead(
            'Data pendaftaran tablet pada penyimpanan aman tidak dapat dibaca. Reset aktivasi tablet untuk memasukkan ulang kode dari admin tanpa menghapus data klinis atau antrean offline.',
            'Tablet registration data in secure storage could not be parsed. Reset tablet activation to re-enter your administrator code without deleting clinical data or offline queues.',
          )
        : context.trRead(
            'Penyimpanan perangkat belum dapat dibaca. Coba muat ulang, atau reset aktivasi tablet jika masalah berlanjut.',
            'Device storage could not be read. Retry loading, or reset tablet activation if the issue persists.',
          );

    final retryLabel = context.trRead('Coba lagi', 'Retry');
    final resetLabel = context.trRead(
      'Reset aktivasi tablet',
      'Reset tablet activation',
    );

    final retryButton = _isCorrupted
        ? OutlinedButton(
            key: const Key('startup-retry-button'),
            onPressed: busy ? null : onRetry,
            child: Text(retryLabel),
          )
        : FilledButton(
            key: const Key('startup-retry-button'),
            onPressed: busy ? null : onRetry,
            child: Text(retryLabel),
          );

    final resetButton = _isCorrupted
        ? FilledButton(
            key: const Key('startup-reset-activation-button'),
            onPressed: busy ? null : () => _confirmReset(context),
            child: Text(resetLabel),
          )
        : OutlinedButton(
            key: const Key('startup-reset-activation-button'),
            onPressed: busy ? null : () => _confirmReset(context),
            child: Text(resetLabel),
          );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 44,
                            color: _isCorrupted
                                ? AppTheme.error
                                : AppTheme.warning,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          if (recoveryError != null) ...[
                            const SizedBox(height: 16),
                            AuthErrorBanner(
                              message: context.trRead(
                                'Gagal mereset aktivasi tablet pada penyimpanan aman. Coba lagi.',
                                'Failed to reset tablet activation in secure storage. Please retry.',
                              ),
                            ),
                          ],
                          if (busy) ...[
                            const SizedBox(height: 20),
                            const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (_isCorrupted) ...[
                            resetButton,
                            const SizedBox(height: 12),
                            retryButton,
                          ] else ...[
                            retryButton,
                            const SizedBox(height: 12),
                            resetButton,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(top: 16, right: 24, child: LanguageToggle()),
          ],
        ),
      ),
    );
  }
}
