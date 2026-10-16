import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/result/widgets.dart';
import 'package:myapp/state/diagnosis_provider.dart';

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
      return const EmptyResultState();
    }

    final isPositive = result.isPositive;
    // HTTP returns decision confidence; local segmentation uses TB confidence.
    final displayedConfidence = result.segmentation != null && !isPositive
        ? 100 - result.confidence
        : result.confidence;

    return ColoredBox(
      key: const Key('diagnosis-result-content'),
      color: kResultBgColor,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                if (isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: A (Visual X-Ray) on left, B, C, D on right
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // A. Visual X-Ray
                            Expanded(
                              flex: 6,
                              child: DarkCard(
                                padding: const EdgeInsets.all(12),
                                child: Center(
                                  child: XrayImageCard(
                                    image: snapshot.image,
                                    segmentation: result.segmentation,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Right Column: B, C, D
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  // B. Identitas Pasien
                                  Expanded(
                                    child: PatientIdentityCard(
                                      snapshot: snapshot,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // C. Hasil Screening/Presentase (Screening AI)
                                  Expanded(
                                    child: DiagnosisAiCard(
                                      isPositive: isPositive,
                                      displayedConfidence: displayedConfidence,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // D. Rekomendasi
                                  Expanded(
                                    child: RecommendationCard(
                                      isPositive: isPositive,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Row 2: E (Detail Klinis) on left, F (Runtime & Simpan) on right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // E. Detail Klinis (Hide/Unhide)
                          Expanded(
                            flex: 6,
                            child: ClinicalDetailsCard(snapshot: snapshot),
                          ),
                          const SizedBox(width: 16),
                          // F. Detail Runtime dan Tombol Simpan
                          Expanded(
                            flex: 4,
                            child: RuntimeAndActionsCard(
                              diagnosis: diagnosis,
                              result: result,
                              onNewScreening: onNewScreening,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                // Narrow layout (<720)
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DarkCard(
                      padding: const EdgeInsets.all(12),
                      child: XrayImageCard(
                        image: snapshot.image,
                        segmentation: result.segmentation,
                      ),
                    ),
                    const SizedBox(height: 12),
                    PatientIdentityCard(snapshot: snapshot),
                    const SizedBox(height: 10),
                    DiagnosisAiCard(
                      isPositive: isPositive,
                      displayedConfidence: displayedConfidence,
                    ),
                    const SizedBox(height: 10),
                    RecommendationCard(isPositive: isPositive),
                    const SizedBox(height: 14),
                    ClinicalDetailsCard(snapshot: snapshot),
                    const SizedBox(height: 14),
                    RuntimeAndActionsCard(
                      diagnosis: diagnosis,
                      result: result,
                      onNewScreening: onNewScreening,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
