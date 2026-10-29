import 'package:myapp/core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 19, color: const Color(0xFFD7DEE8)),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: AppText(
            text,
            maxLines: 2,
            style: const TextStyle(
              color: diagnosisText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
