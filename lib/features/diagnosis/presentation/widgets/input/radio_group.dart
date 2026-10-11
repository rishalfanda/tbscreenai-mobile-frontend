import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

class DarkRadioGroup extends StatelessWidget {
  const DarkRadioGroup({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
    this.horizontal = false,
    this.labels,
  });

  final String label;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onChanged;
  final bool horizontal;

  /// Optional display-text override per option value.
  final Map<String, String>? labels;

  @override
  Widget build(BuildContext context) {
    final options = values.map((value) => _option(value)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: diagnosisText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        if (horizontal)
          Wrap(spacing: 8, runSpacing: 2, children: options)
        else
          ...options,
      ],
    );
  }

  Widget _option(String value) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<String>(
            value: value,
            // ignore: deprecated_member_use
            groupValue: selected,
            // ignore: deprecated_member_use
            onChanged: onChanged,
            activeColor: diagnosisAccent,
            fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? diagnosisAccent
                  : const Color(0xFFE5E7EB),
            ),
            visualDensity: VisualDensity.compact,
          ),
          Flexible(
            child: Text(
              labels?[value] ?? value,
              maxLines: 2,
              style: const TextStyle(color: diagnosisText, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
