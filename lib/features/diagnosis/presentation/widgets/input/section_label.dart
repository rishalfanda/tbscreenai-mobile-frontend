import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFFD7DEE8)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: diagnosisText,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

