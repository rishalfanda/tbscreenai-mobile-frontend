import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';

// === Dark palette (Result tab only) ===
const Color kResultBgColor = Color(0xFF0F1117);
const Color kResultSurfaceColor = Color(0xFF1A1E2B);
const Color kResultSurfaceAltColor = Color(0xFF232838);
const Color kResultBorderColor = Color(0x1FFFFFFF); // white 12%
const Color kResultTextHiColor = Color(0xFFF1F5F9);
const Color kResultTextLoColor = Color(0xFF94A3B8);

const Map<String, String> kGenderLabels = {
  'Female': 'Perempuan',
  'Male': 'Laki-laki',
};

const Map<String, String> kSymptomLabels = {
  'Fever': 'Demam',
  'Cough': 'Batuk',
  'Night Sweats': 'Keringat Malam',
  'Weight Loss': 'Penurunan Berat Badan',
  'Shortness of Breath': 'Sesak Napas',
  'Fatigue': 'Kelelahan',
  'Loss of Appetite': 'Kehilangan Nafsu Makan',
  'Chest Pain': 'Nyeri Dada',
  'Hemoptysis/Coughing Blood': 'Batuk Darah (Hemoptisis)',
  'Other': 'Lainnya',
};

/// Display-label translation for known lesion classes. `entry.name` itself
/// (sourced from the bundle manifest) stays in English — only what's shown
/// is Bahasa Indonesia; an unrecognized class name just falls back as-is.
const Map<String, String> kLesionNameLabels = {
  'consolidation': 'Konsolidasi',
  'cavity': 'Kavitas',
  'effusion': 'Efusi',
  'fibrotic': 'Fibrotik',
  'calcification': 'Kalsifikasi',
};

/// Dark surface card used across the Result tab.
class DarkCard extends StatelessWidget {
  const DarkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kResultSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: kResultBorderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.fontSize = 16});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: kResultTextHiColor,
      ),
    );
  }
}

