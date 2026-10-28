import 'package:myapp/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'result_theme.dart';

/// Card D: Rekomendasi klinis.
class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key, required this.isPositive});

  final bool isPositive;

  @override
  Widget build(BuildContext context) {
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
                color: isPositive ? AppTheme.error : AppTheme.success,
              ),
              const SizedBox(width: 6),
              Expanded(child: SectionTitle('Rekomendasi', fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          const AppText(
            'Segera rujuk ke fasilitas kesehatan untuk di evaluasi dan dilakukan pemeriksaan tambahan oleh dokter',
            style: TextStyle(
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
