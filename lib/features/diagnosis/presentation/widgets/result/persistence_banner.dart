import 'package:myapp/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/screening_result.dart';

/// Shows the local-persistence pipeline's current status for this result.
class PersistenceBanner extends StatelessWidget {
  const PersistenceBanner({super.key, required this.status, this.error});

  final ScreeningSaveStatus status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (icon, color, message) = switch (status) {
      ScreeningSaveStatus.demo => (
        Icons.science_outlined,
        Colors.amber,
        'Hasil demo — penyimpanan klinis diblokir.',
      ),
      ScreeningSaveStatus.saving => (
        Icons.lock_clock_outlined,
        AppTheme.cyan,
        'Mengenkripsi X-ray dan menyimpan hasil yang ditinjau...',
      ),
      ScreeningSaveStatus.pendingSync => (
        Icons.cloud_upload_outlined,
        AppTheme.warning,
        'Tersimpan lokal — menunggu sinkronisasi.',
      ),
      ScreeningSaveStatus.saved => (
        Icons.cloud_done_outlined,
        AppTheme.success,
        'Tersimpan dan terkonfirmasi oleh server.',
      ),
      ScreeningSaveStatus.conflict => (
        Icons.compare_arrows_rounded,
        AppTheme.warning,
        'Konflik server — diperlukan resolusi oleh dokter.',
      ),
      ScreeningSaveStatus.failed => (
        Icons.error_outline,
        AppTheme.error,
        error ?? 'Penyimpanan lokal gagal. Coba lagi sebelum keluar.',
      ),
      ScreeningSaveStatus.unsaved => (
        Icons.save_outlined,
        AppTheme.warning,
        'Belum tersimpan.',
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: AppText(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
