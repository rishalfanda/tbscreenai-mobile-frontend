import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/screening_category.dart';
import 'result_theme.dart';

/// Card D: Tindak Lanjut klinis berdasarkan kategori hasil skrining.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    super.key,
    required this.isPositive,
    this.category,
  });

  final bool isPositive;
  final ScreeningLevel? category;

  @override
  Widget build(BuildContext context) {
    final cat = category;
    final Color iconColor = switch (cat) {
      ScreeningLevel.veryLow || ScreeningLevel.low => AppTheme.success,
      ScreeningLevel.greyArea => AppTheme.warning,
      ScreeningLevel.high || ScreeningLevel.veryHigh => AppTheme.error,
      null => isPositive ? AppTheme.error : AppTheme.success,
    };

    final followUpText = cat?.followUp ??
        (isPositive
            ? 'Hasil skrining positif. Perlu dilanjutkan dengan pemeriksaan lanjutan.'
            : 'Hasil skrining negatif. Tetap mempertimbangkan gejala klinis dan faktor risiko pasien.');

    return DarkCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: SectionTitle('Tindak Lanjut', fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            followUpText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kResultTextHiColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
