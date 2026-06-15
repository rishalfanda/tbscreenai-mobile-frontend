import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/state/diagnosis_provider.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final diagnosis = context.watch<DiagnosisProvider>();
    final result = diagnosis.lastOutcome;
    final isPositive = result?.isPositive ?? true;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Diagnosis Result',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Save'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Export PDF'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.print_rounded),
                        label: const Text('Print'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Main Content
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // X-ray Image Card
                        Card(
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827),
                                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.image_rounded,
                                  size: 64,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Patient Summary Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Patient Summary',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    _SummaryField('Name', diagnosis.patientName),
                                    _SummaryField('Gender', diagnosis.gender),
                                    _SummaryField('Age', '${diagnosis.age ?? 0}'),
                                    _SummaryField('Height', '${diagnosis.heightCm ?? 0} cm'),
                                    _SummaryField('Weight', '${diagnosis.weightKg ?? 0} kg'),
                                    _SummaryField(
                                      'BMI',
                                      diagnosis.heightCm != null && diagnosis.weightKg != null
                                          ? ((diagnosis.weightKg! / ((diagnosis.heightCm! / 100) * (diagnosis.heightCm! / 100))).toStringAsFixed(1))
                                          : '-',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Clinical Data Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Clinical Data',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Symptoms
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: diagnosis.symptoms
                                      .map(
                                        (s) => Chip(
                                          label: Text(s),
                                          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
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
                                    _ClinicalRow('Comorbidity', diagnosis.comorbidity),
                                    _ClinicalRow('Smoking Status', diagnosis.smoking),
                                    _ClinicalRow('TB Contact', diagnosis.tbContact),
                                    _ClinicalRow('Sputum (BTA)', diagnosis.bta),
                                    _ClinicalRow('Culture', diagnosis.culture),
                                  ],
                                ),
                              ],
                            ),
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
                                  ? [AppTheme.error, const Color(0xFFB91C1C)]
                                  : [AppTheme.success, const Color(0xFF15803D)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(
                                  isPositive ? Icons.warning_rounded : Icons.check_circle_rounded,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        '${result?.confidence ?? 85}%',
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
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recommendations',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.navy,
                                  ),
                                ),
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
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Icon(
                                                isPositive ? Icons.circle : Icons.check_circle,
                                                size: 8,
                                                color: isPositive ? AppTheme.error : AppTheme.success,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                item,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Analysis Details
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Analysis Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Table(
                                  columnWidths: const {
                                    0: IntrinsicColumnWidth(),
                                    1: FlexColumnWidth(),
                                  },
                                  children: [
                                    _AnalysisRow('Analysis Date', DateTime.now().toString().split(' ')[0]),
                                    _AnalysisRow('Model Version', 'TBScreen v2.1.0'),
                                    _AnalysisRow('Processing Time', '2.8s'),
                                  ],
                                ),
                              ],
                            ),
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
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _SummaryField(String label, String value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _ClinicalRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _AnalysisRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
