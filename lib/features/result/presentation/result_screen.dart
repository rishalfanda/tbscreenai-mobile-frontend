import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/features/shared/presentation/widgets/widgets.dart';
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

    // Safety: never render a verdict when no analysis has run. Falling back to
    // a placeholder here would show a fabricated "TB Detected 85%" to a doctor.
    if (result == null) {
      return const _NoResultState();
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
                // === Section: Header Row ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Diagnosis Result',
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
                        _headerButton(Icons.picture_as_pdf_rounded, 'Export PDF'),
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
                          const _DarkCard(
                            padding: EdgeInsets.zero,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: XrayPreview(label: 'Citra X-ray dada'),
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
                                    _summaryField('Name', diagnosis.patientName),
                                    _summaryField('Gender', diagnosis.gender),
                                    _summaryField('Age', diagnosis.age?.toString() ?? '-'),
                                    _summaryField(
                                        'Height', diagnosis.heightCm != null ? '${diagnosis.heightCm} cm' : '-'),
                                    _summaryField(
                                        'Weight', diagnosis.weightKg != null ? '${diagnosis.weightKg} kg' : '-'),
                                    _summaryField(
                                      'BMI',
                                      diagnosis.bmi != null
                                          ? diagnosis.bmi!.toStringAsFixed(1)
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
                                if (diagnosis.symptoms.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: diagnosis.symptoms
                                        .map(
                                          (s) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
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
                                    _clinicalRow('Comorbidity', diagnosis.comorbidity),
                                    _clinicalRow('Smoking Status', diagnosis.smoking),
                                    _clinicalRow('TB Contact', diagnosis.tbContact),
                                    _clinicalRow('Sputum (BTA)', diagnosis.bta),
                                    _clinicalRow('Culture', diagnosis.culture),
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
                              borderRadius:
                                  BorderRadius.circular(AppTheme.cardRadius),
                              boxShadow: [
                                BoxShadow(
                                  color: (isPositive
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
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
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
                                            'Order additional diagnostic tests',
                                          ]
                                        : [
                                            'Monitor symptoms',
                                            'Schedule follow-up in 6 months',
                                            'Maintain healthy lifestyle',
                                          ])
                                    .map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 4),
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
                                      result.createdAt
                                          .toString()
                                          .split(' ')[0],
                                    ),
                                    _analysisRow('Model Version',
                                        result.modelVersion),
                                    _analysisRow('Processing Time',
                                        result.processingTime),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // New Diagnosis Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                diagnosis.resetForNewDiagnosis();
                                context.go('/diagnosis');
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('New Diagnosis'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _textLo),
          ),
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
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: _textLo)),
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
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: _textLo)),
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

/// Shown when no analysis has been run yet. A medical screening app must not
/// display a verdict it did not compute.
class _NoResultState extends StatelessWidget {
  const _NoResultState();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.analytics_outlined, size: 72, color: _textLo),
              const SizedBox(height: 24),
              const Text(
                'Belum ada hasil diagnosis',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textHi,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Unggah atau ambil citra X-ray dada, lalu jalankan analisis AI '
                'untuk melihat hasilnya di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: _textLo, height: 1.5),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => context.go('/diagnosis'),
                icon: const Icon(Icons.biotech_rounded, size: 20),
                label: const Text('Mulai Diagnosis'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 18),
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
