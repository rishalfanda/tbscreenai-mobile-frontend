import 'package:myapp/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/screening_category.dart';
import 'result_theme.dart';

/// Card C: Hasil Screening / Presentase (Diagnosis AI).
class DiagnosisAiCard extends StatelessWidget {
  const DiagnosisAiCard({
    super.key,
    required this.isPositive,
    required this.displayedConfidence,
    this.category,
  });

  final bool isPositive;
  final num displayedConfidence;
  final ScreeningLevel? category;

  @override
  Widget build(BuildContext context) {
    final cat = category ?? ScreeningLevel.fromScore(displayedConfidence);
    final List<Color> gradientColors = switch (cat) {
      ScreeningLevel.veryLow || ScreeningLevel.low => [
        AppTheme.success,
        AppTheme.successDark,
      ],
      ScreeningLevel.greyArea => [
        const Color(0xFFF59E0B),
        const Color(0xFFD97706),
      ],
      ScreeningLevel.high || ScreeningLevel.veryHigh => [
        AppTheme.error,
        AppTheme.errorDark,
      ],
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: kResultBorderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppText(
            'Screening AI',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level Indikasi TB: ${cat.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cat.interpretation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${displayedConfidence.round()}%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
