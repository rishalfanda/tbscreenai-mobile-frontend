import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

class OptionalFieldsPanel extends StatelessWidget {
  const OptionalFieldsPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('optional-fields-panel'),
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 14),
          iconColor: diagnosisAccent,
          collapsedIconColor: diagnosisMuted,
          textColor: diagnosisText,
          collapsedTextColor: diagnosisText,
          title: const Text(
            'Informasi Tambahan (Opsional)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Gejala, lingkungan, dan hasil pemeriksaan klinis',
            style: TextStyle(color: diagnosisMuted, fontSize: 12),
          ),
          children: [child],
        ),
      ),
    );
  }
}

