import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

class SymptomGrid extends StatelessWidget {
  const SymptomGrid({
    super.key,
    required this.symptoms,
    required this.selected,
    required this.onChanged,
    this.labels,
  });

  final List<String> symptoms;
  final Set<String> selected;
  final void Function(String symptom, bool selected) onChanged;
  final Map<String, String>? labels;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 320
            ? 2
            : 1;
        const gap = 12.0;
        final width = ((constraints.maxWidth - gap * (columns - 1)) / columns)
            .clamp(0.0, double.infinity)
            .toDouble();
        return Wrap(
          spacing: gap,
          runSpacing: 6,
          children: symptoms
              .map(
                (symptom) => SizedBox(
                  width: width,
                  child: Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      value: selected.contains(symptom),
                      onChanged: (value) => onChanged(symptom, value ?? false),
                      title: Text(
                        labels?[symptom] ?? symptom,
                        style: const TextStyle(
                          color: diagnosisText,
                          fontSize: 15,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      activeColor: diagnosisAccent,
                      checkColor: diagnosisInput,
                      side: const BorderSide(color: diagnosisMuted, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

