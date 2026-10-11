import 'package:flutter/material.dart';
import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'result_theme.dart';

/// Card B: Concise 2-line patient identity summary.
class PatientIdentityCard extends StatelessWidget {
  const PatientIdentityCard({super.key, required this.snapshot});

  final DiagnosisDraft snapshot;

  @override
  Widget build(BuildContext context) {
    return DarkCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 20, color: kResultTextLoColor),
              SizedBox(width: 6),
              SectionTitle('Identitas Pasien', fontSize: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.patientName.isEmpty ? '-' : snapshot.patientName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kResultTextHiColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${kGenderLabels[snapshot.gender] ?? snapshot.gender ?? "-"} · '
            '${snapshot.age != null ? "${snapshot.age} Tahun" : "-"}',
            style: const TextStyle(
              fontSize: 15,
              color: kResultTextLoColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${snapshot.weightKg != null ? "${snapshot.weightKg} kg" : "-"} / '
            '${snapshot.heightCm != null ? "${snapshot.heightCm} cm" : "-"} '
            '(BMI: ${snapshot.bmi?.toStringAsFixed(1) ?? "-"})',
            style: const TextStyle(
              fontSize: 14.5,
              color: kResultTextLoColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

