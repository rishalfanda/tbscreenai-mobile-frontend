import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/segmentation_overlays.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/state/diagnosis_provider.dart';

// === Section: Dark palette (Result screen only) ===
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

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final diagnosis = context.watch<DiagnosisProvider>();
    final result = diagnosis.lastOutcome;
    final snapshot = diagnosis.lastResult?.draft;

    // The direct Result route is useful during stakeholder demos. Keep the
    // sample unmistakably labelled as dummy data; a real inference outcome
    // always replaces it.
    if (result == null || snapshot == null) {
      return const _DummyScreeningResultState();
    }

    final isPositive = result.isPositive;
    // `result.confidence` is stored as-is (the data model is untouched) —
    // only the displayed figure flips for a negative verdict, so it always
    // reads as "confidence in the shown verdict" rather than "confidence TB".
    final displayedConfidence = isPositive
        ? result.confidence
        : 100 - result.confidence;

    return ColoredBox(
      color: _bg,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.isMock) ...[
                  const Text(
                    'DUMMY / DEMO — BUKAN HASIL KLINIS',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // === Section: Header Row ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hasil Screening',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _textHi,
                      ),
                    ),
                    Row(
                      children: [
                        _headerButton(Icons.save_rounded, 'Simpan'),
                        const SizedBox(width: 12),
                        _headerButton(
                          Icons.picture_as_pdf_rounded,
                          'Ekspor PDF',
                        ),
                        const SizedBox(width: 12),
                        _headerButton(Icons.print_rounded, 'Cetak'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // === Section: Main Content ===
                Row(
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

                          // Clinical Data Card
                          _DarkCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('Data Klinis'),
                                const SizedBox(height: 20),
                                if (snapshot.symptoms.isNotEmpty)
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
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: AppTheme.primary
                                                    .withValues(alpha: 0.4),
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
                                    _clinicalRow(
                                      'Dahak (BTA)',
                                      snapshot.bta ?? 'Tidak diisi',
                                    ),
                                    _clinicalRow(
                                      'Kultur',
                                      snapshot.culture ?? 'Tidak diisi',
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
                          // AI Result Card
                          Container(
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
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isPositive
                                              ? AppTheme.error
                                              : AppTheme.success)
                                          .withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    isPositive
                                        ? Icons.warning_rounded
                                        : Icons.check_circle_rounded,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isPositive ? 'Terdeteksi TB' : 'Normal',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '$displayedConfidence%',
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Text(
                                          'Persentase TB',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Hasil AI hanya alat bantu screening.\n'
                                    'Konfirmasi oleh tenaga medis profesional tetap diperlukan.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Recommendations Card
                          _DarkCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('Rekomendasi'),
                                const SizedBox(height: 16),
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
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: Icon(
                                                isPositive
                                                    ? Icons.circle
                                                    : Icons.check_circle,
                                                size: 8,
                                                color: isPositive
                                                    ? AppTheme.error
                                                    : AppTheme.success,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                item,
                                                style: const TextStyle(
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
                          const SizedBox(height: 16),

                          // Analysis Details
                          _DarkCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('Detail Analisis'),
                                const SizedBox(height: 16),
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
                          const SizedBox(height: 16),

                          // New Screening Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                diagnosis.resetForNewDiagnosis();
                                context.go('/diagnosis');
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Screening Baru'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerButton(IconData icon, String label) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _textHi,
        side: const BorderSide(color: _border),
        backgroundColor: _surface,
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: _textLo),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textHi,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stakeholder-demo sample shown only when no analysis outcome exists.
/// Every clinical-looking value is visibly marked as dummy data.
class _DummyScreeningResultState extends StatelessWidget {
  const _DummyScreeningResultState();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppTheme.warning, width: 2),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'DUMMY / DEMO — BUKAN HASIL KLINIS',
                        style: TextStyle(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Hasil Screening (Contoh)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _textHi,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warning,
                          size: 38,
                        ),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diduga TB',
                              style: TextStyle(
                                color: _textHi,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Keyakinan 78% · Model Demo v0.1',
                              style: TextStyle(color: _textLo, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Contoh ini hanya untuk mempresentasikan layout halaman. '
                      'Hasil nyata hanya muncul setelah X-ray dianalisis dan '
                      'wajib dikonfirmasi tenaga medis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: _textLo,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go('/diagnosis'),
                icon: const Icon(Icons.biotech_rounded, size: 20),
                label: const Text('Mulai Screening'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                  ),
                ),
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
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.memory(
          image!.bytes,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Center(child: Text('Gambar tidak tersedia')),
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
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                const Center(child: Text('Gambar tidak tersedia')),
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
                      .map((entry) => _LesionLegendChip(entry: entry))
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

class _LesionLegendChip extends StatelessWidget {
  const _LesionLegendChip({required this.entry});

  final LesionLegendEntry entry;

  @override
  Widget build(BuildContext context) {
    final dimmed = entry.pixelCount == 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Color.fromARGB(255, entry.red, entry.green, entry.blue),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${_lesionNameLabels[entry.name.toLowerCase()] ?? entry.name} · '
          '${entry.pixelCount} px',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: dimmed ? _textLo : _textHi,
          ),
        ),
      ],
    );
  }
}

/// Dark surface card used across the Result screen.
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
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _textHi,
      ),
    );
  }
}
