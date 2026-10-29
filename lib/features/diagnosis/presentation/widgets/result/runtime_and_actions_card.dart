import 'package:myapp/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/screening_result.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'persistence_banner.dart';
import 'result_theme.dart';

/// Card F: Runtime Details and Action Buttons (Save, PDF, Print, Screening Baru).
class RuntimeAndActionsCard extends StatelessWidget {
  const RuntimeAndActionsCard({
    super.key,
    required this.diagnosis,
    required this.result,
    required this.onNewScreening,
  });

  final DiagnosisProvider diagnosis;
  final DiagnosisOutcome result;
  final VoidCallback onNewScreening;

  @override
  Widget build(BuildContext context) {
    return DarkCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Detail Runtime & Aksi', fontSize: 13),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth()},
            children: [
              _analysisRow(
                'Tanggal Analisis',
                result.createdAt.toString().split(' ')[0],
              ),
              _analysisRow('Versi Model', result.modelVersion),
              _analysisRow('Waktu Proses', result.processingTime),
            ],
          ),
          const SizedBox(height: 8),
          AppText(
            result.isMock
                ? 'MOCK / DEMO - bukan hasil model asli'
                : result.segmentation != null
                ? 'Hasil model perangkat'
                : 'Hasil model backend',
            style: const TextStyle(color: kResultTextLoColor),
          ),
          if (result.segmentation == null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final entry in result.findings.entries)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        kLesionNameLabels[entry.key] ?? entry.key,
                        style: const TextStyle(color: kResultTextLoColor),
                      ),
                      AppText(
                        '${entry.value.toStringAsFixed(1)}%',
                        style: const TextStyle(color: kResultTextHiColor),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PersistenceBanner(
            status: diagnosis.saveStatus,
            error: diagnosis.persistenceError,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                child: _actionButton(
                  Icons.save_rounded,
                  _saveButtonLabel(diagnosis.saveStatus),
                  onPressed:
                      result.isMock ||
                          diagnosis.isSaving ||
                          diagnosis.saveStatus ==
                              ScreeningSaveStatus.pendingSync ||
                          diagnosis.saveStatus == ScreeningSaveStatus.saved
                      ? null
                      : () => _save(context, diagnosis),
                ),
              ),
              const SizedBox(width: 8),
              _actionButton(
                Icons.picture_as_pdf_rounded,
                'PDF',
                tooltip:
                    'Dinonaktifkan sampai kebijakan PHI untuk hasil tersimpan disetujui.',
              ),
              const SizedBox(width: 8),
              _actionButton(
                Icons.print_rounded,
                'Cetak',
                tooltip:
                    'Dinonaktifkan sampai kebijakan PHI untuk hasil tersimpan disetujui.',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('new-screening-button'),
              onPressed: () => _startNewScreening(context, diagnosis),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const AppText('Screening Baru'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label, {
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: AppText(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: kResultTextHiColor,
        side: const BorderSide(color: kResultBorderColor),
        backgroundColor: kResultSurfaceColor,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  String _saveButtonLabel(ScreeningSaveStatus status) => switch (status) {
    ScreeningSaveStatus.saving => 'Menyimpan...',
    ScreeningSaveStatus.pendingSync => 'Dalam Antrian',
    ScreeningSaveStatus.saved => 'Tersimpan',
    ScreeningSaveStatus.failed => 'Coba Simpan Lagi',
    _ => 'Simpan',
  };

  Future<void> _save(BuildContext context, DiagnosisProvider diagnosis) async {
    final saved = await diagnosis.saveCurrentResult();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(
          saved
              ? 'Terenkripsi secara lokal dan dalam antrian sinkronisasi.'
              : diagnosis.persistenceError ??
                    'Screening tidak berhasil disimpan.',
        ),
        backgroundColor: saved ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  Future<void> _startNewScreening(
    BuildContext context,
    DiagnosisProvider diagnosis,
  ) async {
    if (!await _confirmLeave(context, diagnosis) || !context.mounted) return;
    diagnosis.resetForNewDiagnosis();
    onNewScreening();
  }

  Future<bool> _confirmLeave(
    BuildContext context,
    DiagnosisProvider diagnosis,
  ) async {
    if (!diagnosis.requiresLeaveConfirmation) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const AppText('Mulai screening baru?'),
            content: AppText(
              diagnosis.saveStatus == ScreeningSaveStatus.pendingSync
                  ? 'Hasil ini sudah tersimpan lokal namun masih menunggu sinkronisasi. Memulai screening baru tidak akan menghapusnya.'
                  : 'Hasil ini belum tersimpan dengan aman. Tinjau atau coba simpan ulang sebelum melanjutkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const AppText('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const AppText('Lanjutkan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  static TableRow _analysisRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: AppText(
            label,
            style: const TextStyle(fontSize: 11, color: kResultTextLoColor),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kResultTextHiColor,
            ),
          ),
        ),
      ],
    );
  }
}
