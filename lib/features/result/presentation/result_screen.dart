import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/state/diagnosis_provider.dart';

// === Section: Dark palette (Result screen only) ===
const Color _bg = Color(0xFF0F1117);
const Color _surface = Color(0xFF1A1E2B);
const Color _surfaceAlt = Color(0xFF232838);
const Color _border = Color(0x1FFFFFFF); // white 12%
const Color _textHi = Color(0xFFF1F5F9);
const Color _textLo = Color(0xFF94A3B8);

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
                      'Screening Result',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _textHi,
                      ),
                    ),
                    Row(
                      children: [
                        _headerButton(Icons.save_rounded, 'Save'),
                        const SizedBox(width: 12),
                        _headerButton(
                          Icons.picture_as_pdf_rounded,
                          'Export PDF',
                        ),
                        const SizedBox(width: 12),
                        _headerButton(Icons.print_rounded, 'Print'),
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
                          // X-ray Image Card
                          _DarkCard(
                            padding: EdgeInsets.zero,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: snapshot.image?.canPreview == true
                                  ? Image.memory(
                                      snapshot.image!.bytes,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Text('Image unavailable'),
                                      ),
                                    )
                                  : const Center(
                                      child: Text('Image preview unavailable'),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Patient Summary Card
                          _DarkCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionTitle('Patient Summary'),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    _summaryField('Name', snapshot.patientName),
                                    _summaryField(
                                      'Gender',
                                      snapshot.gender ?? 'Not provided',
                                    ),
                                    _summaryField(
                                      'Age',
                                      snapshot.age?.toString() ?? '-',
                                    ),
                                    _summaryField(
                                      'Height',
                                      snapshot.heightCm != null
                                          ? '${snapshot.heightCm} cm'
                                          : '-',
                                    ),
                                    _summaryField(
                                      'Weight',
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
                                const _SectionTitle('Clinical Data'),
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
                                      'Comorbidity',
                                      snapshot.comorbidity ?? 'Not provided',
                                    ),
                                    _clinicalRow(
                                      'Smoking Status',
                                      snapshot.smoking ?? 'Not provided',
                                    ),
                                    _clinicalRow(
                                      'TB Contact',
                                      snapshot.tbContact ?? 'Not provided',
                                    ),
                                    _clinicalRow(
                                      'Sputum (BTA)',
                                      snapshot.bta ?? 'Not provided',
                                    ),
                                    _clinicalRow(
                                      'Culture',
                                      snapshot.culture ?? 'Not provided',
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
                                    isPositive ? 'TB Detected' : 'Normal',
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
                                          '${result.confidence}%',
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Text(
                                          'AI Confidence',
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
                                    'AI results are screening tools only.\nConfirmation by a qualified medical professional is required.',
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
                                const _SectionTitle('Recommendations'),
                                const SizedBox(height: 16),
                                ...(isPositive
                                        ? [
                                            'Refer to pulmonologist immediately',
                                            'Start contact tracing',
                                            'Order additional screening tests',
                                          ]
                                        : [
                                            'Monitor symptoms',
                                            'Schedule follow-up in 6 months',
                                            'Maintain healthy lifestyle',
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
                                const _SectionTitle('Analysis Details'),
                                const SizedBox(height: 16),
                                Table(
                                  columnWidths: const {
                                    0: IntrinsicColumnWidth(),
                                    1: FlexColumnWidth(),
                                  },
                                  children: [
                                    _analysisRow(
                                      'Analysis Date',
                                      result.createdAt.toString().split(' ')[0],
                                    ),
                                    _analysisRow(
                                      'Model Version',
                                      result.modelVersion,
                                    ),
                                    _analysisRow(
                                      'Processing Time',
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
                              label: const Text('New Screening'),
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
                      'Screening Result (Dummy)',
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
                              'TB Suspected',
                              style: TextStyle(
                                color: _textHi,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Confidence 78% · Demo Model v0.1',
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
