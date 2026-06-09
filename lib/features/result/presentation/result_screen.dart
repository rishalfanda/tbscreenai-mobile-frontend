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
    final hasResult = result != null;
    final isPositive = result?.isPositive ?? false;
    final gradient = hasResult
        ? (isPositive
            ? const [AppTheme.error, Color(0xFFB91C1C)]
            : const [AppTheme.success, Color(0xFF15803D)])
        : const [AppTheme.primary, AppTheme.primaryDark];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Save'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Export PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.print_rounded),
                          label: const Text('Print'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  diagnosis.imageLabel ?? 'No image',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Patient Summary',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _MetaCard(label: 'Name', value: diagnosis.patientName.isEmpty ? '-' : diagnosis.patientName),
                                _MetaCard(label: 'Gender', value: diagnosis.gender),
                                _MetaCard(label: 'Age', value: diagnosis.age?.toString() ?? '-'),
                                _MetaCard(label: 'Height', value: diagnosis.heightCm == null ? '-' : '${diagnosis.heightCm!.toStringAsFixed(0)} cm'),
                                _MetaCard(label: 'Weight', value: diagnosis.weightKg == null ? '-' : '${diagnosis.weightKg!.toStringAsFixed(0)} kg'),
                                _MetaCard(label: 'BMI', value: diagnosis.bmi == null ? '-' : diagnosis.bmi!.toStringAsFixed(1)),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Clinical Data',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: diagnosis.symptoms.isEmpty
                                  ? [const Chip(label: Text('No symptoms selected'))]
                                  : diagnosis.symptoms
                                      .map(
                                        (symptom) => Chip(
                                          label: Text(symptom),
                                          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _MetaCard(label: 'Comorbidity', value: diagnosis.comorbidity),
                                _MetaCard(label: 'Smoking', value: diagnosis.smoking),
                                _MetaCard(label: 'TB Contact', value: diagnosis.tbContact),
                                _MetaCard(label: 'TB History', value: diagnosis.tbHistory),
                                _MetaCard(label: 'Model Type', value: diagnosis.modelType),
                                _MetaCard(label: 'IGRA', value: diagnosis.igra),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        gradient: LinearGradient(colors: gradient),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isPositive ? Icons.warning_amber_rounded : Icons.verified_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            hasResult ? (isPositive ? 'TB Detected' : 'Normal') : 'No Result Yet',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            hasResult ? '${result.confidence}%' : '--',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'AI result is a screening tool, not a diagnosis',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recommendations',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            ...(isPositive
                                    ? const [
                                        'Refer to pulmonology team for confirmatory testing',
                                        'Prioritize bacteriology and infection control workflow',
                                        'Review TB contact and treatment history immediately',
                                      ]
                                    : const [
                                        'Continue symptom monitoring over the next 2-4 weeks',
                                        'Repeat imaging if symptoms worsen',
                                        'Maintain adequate ventilation and follow-up screening',
                                      ])
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: AppTheme.primaryDark, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(item)),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Analysis Meta',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            _MetaLine(label: 'Date', value: result?.createdAt.toString() ?? '-'),
                            _MetaLine(label: 'Model Version', value: result?.modelVersion ?? '-'),
                            _MetaLine(label: 'Processing Time', value: result?.processingTime ?? '-'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          diagnosis.resetForNewDiagnosis();
                          context.go('/diagnosis');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('New Diagnosis'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black54))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
