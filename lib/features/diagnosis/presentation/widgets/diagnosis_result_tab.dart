import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/domain/models/screening_result.dart';
import 'package:myapp/domain/models/segmentation_overlays.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/state/diagnosis_provider.dart';

// === Section: Dark palette (Result tab only) ===
const Color _bg = Color(0xFF0F1117);
const Color _surface = Color(0xFF1A1E2B);
const Color _surfaceAlt = Color(0xFF232838);
const Color _border = Color(0x1FFFFFFF); // white 12%
const Color _textHi = Color(0xFFF1F5F9);
const Color _textLo = Color(0xFF94A3B8);

/// Display-label translation for known lesion classes. `entry.name` itself
/// (sourced from the bundle manifest) stays in English — only what's shown
/// is Bahasa Indonesia; an unrecognized class name just falls back as-is.
const Map<String, String> _lesionNameLabels = {
  'consolidation': 'Konsolidasi',
  'cavity': 'Kavitas',
  'effusion': 'Efusi',
  'fibrotic': 'Fibrotik',
  'calcification': 'Kalsifikasi',
};

/// The "Hasil Analisis" tab of the combined diagnosis screen. [DiagnosisScreen]
/// only lets the user reach this tab once an outcome exists, but it still
/// renders a safe, neutral placeholder for the brief moment it exists
/// off-screen before that (it's built eagerly as the second `TabBarView`
/// child).
class DiagnosisResultTab extends StatelessWidget {
  const DiagnosisResultTab({super.key, required this.onNewScreening});

  /// Called after the user confirms "Screening Baru" so the tab host can
  /// switch back to the input tab.
  final VoidCallback onNewScreening;

  @override
  Widget build(BuildContext context) {
    final diagnosis = context.watch<DiagnosisProvider>();
    final result = diagnosis.lastOutcome;
    final snapshot = diagnosis.lastResult?.draft;

    if (result == null || snapshot == null) {
      return const _EmptyResultState();
    }

    final isPositive = result.isPositive;
    // `result.confidence` is stored as-is (the data model is untouched) —
    // only the displayed figure flips for a negative verdict, so it always
    // reads as "confidence in the shown verdict" rather than "confidence TB".
    final displayedConfidence = isPositive
        ? result.confidence
        : 100 - result.confidence;

    return ColoredBox(
      key: const Key('diagnosis-result-content'),
      color: _bg,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1600),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // X-ray Image Card (with lung/lesion segmentation
                      // toggle when the on-device pipeline produced one)
                      _DarkCard(
                        padding: EdgeInsets.zero,
                        child: _XrayImageCard(
                          image: snapshot.image,
                          segmentation: result.segmentation,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Patient Summary Card
                      _DarkCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Ringkasan Pasien'),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _summaryField('Nama', snapshot.patientName),
                                _summaryField(
                                  'Jenis Kelamin',
                                  snapshot.gender ?? 'Tidak diisi',
                                ),
                                _summaryField(
                                  'Usia',
                                  snapshot.age?.toString() ?? '-',
                                ),
                                _summaryField(
                                  'Tinggi Badan',
                                  snapshot.heightCm != null
                                      ? '${snapshot.heightCm} cm'
                                      : '-',
                                ),
                                _summaryField(
                                  'Berat Badan',
                                  snapshot.weightKg != null
                                      ? '${snapshot.weightKg} kg'
                                      : '-',
                                ),
                                _summaryField(
                                  'BMI',
                                  snapshot.bmi != null
                                      ? snapshot.bmi!.toStringAsFixed(1)
                                      : '-',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Save status + action buttons
                      _DarkCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PersistenceBanner(
                              status: diagnosis.saveStatus,
                              error: diagnosis.persistenceError,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _actionButton(
                                  Icons.save_rounded,
                                  _saveButtonLabel(diagnosis.saveStatus),
                                  onPressed:
                                      result.isMock ||
                                          diagnosis.isSaving ||
                                          diagnosis.saveStatus ==
                                              ScreeningSaveStatus.pendingSync ||
                                          diagnosis.saveStatus ==
                                              ScreeningSaveStatus.saved
                                      ? null
                                      : () => _save(context, diagnosis),
                                ),
                                const SizedBox(width: 12),
                                _actionButton(
                                  Icons.picture_as_pdf_rounded,
                                  'Ekspor PDF',
                                  tooltip:
                                      'Dinonaktifkan sampai kebijakan PHI untuk hasil tersimpan disetujui.',
                                ),
                                const SizedBox(width: 12),
                                _actionButton(
                                  Icons.print_rounded,
                                  'Cetak',
                                  tooltip:
                                      'Dinonaktifkan sampai kebijakan PHI untuk hasil tersimpan disetujui.',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),

                // Right Column
                SizedBox(
                  width: 320,
                  child: Column(
                    children: [
                      // Hasil TB Card
                      _DarkCard(
                        padding: EdgeInsets.zero,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isPositive
                                  ? [AppTheme.error, AppTheme.errorDark]
                                  : [AppTheme.success, AppTheme.successDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.cardRadius,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  isPositive ? 'Terdeteksi TB' : 'Normal',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '$displayedConfidence%',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Text(
                                        'Tingkat Keyakinan AI',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Hasil AI hanya alat bantu screening.\n'
                                  'Konfirmasi oleh tenaga medis profesional tetap diperlukan.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Clinical Data Card
                      _DarkCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Data Klinis', fontSize: 14),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                key: const Key('show-clinical-data-button'),
                                onPressed: () =>
                                    _showClinicalDataDialog(context, snapshot),
                                icon: const Icon(
                                  Icons.description_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Tampilkan Data Klinis',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _textHi,
                                  side: const BorderSide(color: _border),
                                  backgroundColor: _surfaceAlt,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Recommendations Card
                      _DarkCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Rekomendasi', fontSize: 14),
                            const SizedBox(height: 8),
                            ...(isPositive
                                    ? [
                                        'Segera rujuk ke dokter spesialis paru',
                                        'Mulai pelacakan kontak',
                                        'Lakukan pemeriksaan tambahan',
                                      ]
                                    : [
                                        'Pantau gejala',
                                        'Jadwalkan tindak lanjut dalam 6 bulan',
                                        'Jaga gaya hidup sehat',
                                      ])
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 3,
                                          ),
                                          child: Icon(
                                            isPositive
                                                ? Icons.circle
                                                : Icons.check_circle,
                                            size: 6,
                                            color: isPositive
                                                ? AppTheme.error
                                                : AppTheme.success,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _textHi,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Analysis Details
                      _DarkCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              'Detail Analisis',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 8),
                            Table(
                              columnWidths: const {
                                0: IntrinsicColumnWidth(),
                                1: FlexColumnWidth(),
                              },
                              children: [
                                _analysisRow(
                                  'Tanggal Analisis',
                                  result.createdAt.toString().split(' ')[0],
                                ),
                                _analysisRow(
                                  'Versi Model',
                                  result.modelVersion,
                                ),
                                _analysisRow(
                                  'Waktu Proses',
                                  result.processingTime,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // New Screening Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('new-screening-button'),
                          onPressed: () =>
                              _startNewScreening(context, diagnosis),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Screening Baru'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _textHi,
        side: const BorderSide(color: _border),
        backgroundColor: _surface,
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
        content: Text(
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
            title: const Text('Mulai screening baru?'),
            content: Text(
              diagnosis.saveStatus == ScreeningSaveStatus.pendingSync
                  ? 'Hasil ini sudah tersimpan lokal namun masih menunggu sinkronisasi. Memulai screening baru tidak akan menghapusnya.'
                  : 'Hasil ini belum tersimpan dengan aman. Tinjau atau coba simpan ulang sebelum melanjutkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Lanjutkan'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showClinicalDataDialog(
    BuildContext context,
    DiagnosisDraft snapshot,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        key: const Key('clinical-data-dialog'),
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: const BorderSide(color: _border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Data Klinis'),
                const SizedBox(height: 20),
                if (snapshot.symptoms.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: snapshot.symptoms
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth(),
                  },
                  children: [
                    _clinicalRow(
                      'Komorbiditas',
                      snapshot.comorbidity ?? 'Tidak diisi',
                    ),
                    _clinicalRow(
                      'Status Merokok',
                      snapshot.smoking ?? 'Tidak diisi',
                    ),
                    _clinicalRow(
                      'Kontak TB',
                      snapshot.tbContact ?? 'Tidak diisi',
                    ),
                    _clinicalRow('Dahak (BTA)', snapshot.bta ?? 'Tidak diisi'),
                    _clinicalRow('Kultur', snapshot.culture ?? 'Tidak diisi'),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryField(String label, String value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _textLo)),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textHi,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _clinicalRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _textLo),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textHi,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _analysisRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: _textLo),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textHi,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the local-persistence pipeline's current status for this result.
class _PersistenceBanner extends StatelessWidget {
  const _PersistenceBanner({required this.status, this.error});

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while this tab has no outcome to render. Reachable in practice
/// only as an inert, off-screen `TabBarView` child — [DiagnosisScreen] keeps
/// this tab disabled until a real analysis exists — so it deliberately
/// carries no fabricated clinical numbers, unlike the old standalone
/// `/result` route's demo placeholder.
class _EmptyResultState extends StatelessWidget {
  const _EmptyResultState();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined, size: 56, color: _textLo),
              const SizedBox(height: 16),
              const Text(
                'Belum ada hasil analisis.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textHi,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lengkapi data pasien dan jalankan analisis pada tab Input Data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textLo, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// X-ray preview with an optional lung/lesion segmentation toggle. Falls
/// back to a plain image (today's behavior) when no segmentation was
/// produced — mock/HTTP outcomes never carry pixel-level mask data.
class _XrayImageCard extends StatefulWidget {
  const _XrayImageCard({required this.image, required this.segmentation});

  final XrayImage? image;
  final SegmentationOverlays? segmentation;

  @override
  State<_XrayImageCard> createState() => _XrayImageCardState();
}

class _XrayImageCardState extends State<_XrayImageCard> {
  int _view = 0; // 0 = X-ray, 1 = Lung, 2 = Lesion

  @override
  Widget build(BuildContext context) {
    final image = widget.image;
    final segmentation = widget.segmentation;

    if (image?.canPreview != true) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: Text('Pratinjau gambar tidak tersedia')),
      );
    }

    if (segmentation == null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const Key('xray-image-viewer-trigger'),
          onTap: () => _openImageViewer(context, image.bytes),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(
              image!.bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Center(child: Text('Gambar tidak tersedia')),
            ),
          ),
        ),
      );
    }

    final bytes = switch (_view) {
      1 => segmentation.lungPng,
      2 => segmentation.lesionPng,
      _ => segmentation.xrayPng,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            key: const Key('xray-image-viewer-trigger'),
            onTap: () => _openImageViewer(context, bytes),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Gambar tidak tersedia')),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SegmentedButton<int>(
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((
                      states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.black; // Warna teks saat dipilih
                      }
                      return Colors.white.withAlpha(
                        150,
                      ); // Warna teks saat tidak dipilih
                    }),
                  ),
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Rontgen')),
                    ButtonSegment(value: 1, label: Text('Paru')),
                    ButtonSegment(value: 2, label: Text('Lesi')),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _view = selection.first),
                ),
              ),
              if (segmentation.legend.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: segmentation.legend
                      .map(
                        (entry) => _LesionLegendChip(
                          entry: entry,
                          lungAreaPx: segmentation.lungAreaPx,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the currently-selected X-ray view (Rontgen/Paru/Lesi) full-size,
/// with pinch/drag zoom and pan, over a dark modal overlay.
void _openImageViewer(BuildContext context, Uint8List bytes) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      key: const Key('xray-image-viewer-dialog'),
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              key: const Key('xray-image-viewer-close-button'),
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _LesionLegendChip extends StatelessWidget {
  const _LesionLegendChip({required this.entry, required this.lungAreaPx});

  final LesionLegendEntry entry;
  final int lungAreaPx;

  @override
  Widget build(BuildContext context) {
    final dimmed = entry.pixelCount == 0;
    final proportion = lungAreaPx == 0
        ? 0.0
        : entry.pixelCount / lungAreaPx * 100;
    final color = Color.fromARGB(255, entry.red, entry.green, entry.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dimmed ? _surfaceAlt : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dimmed ? _border : color.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        '${_lesionNameLabels[entry.name.toLowerCase()] ?? entry.name} · '
        '${proportion.toStringAsFixed(1)}%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: dimmed ? _textLo : color,
        ),
      ),
    );
  }
}

/// Dark surface card used across the Result tab.
class _DarkCard extends StatelessWidget {
  const _DarkCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.fontSize = 18});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: _textHi,
      ),
    );
  }
}
