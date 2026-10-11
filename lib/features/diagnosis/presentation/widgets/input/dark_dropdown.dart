import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/input/dark_input_decoration.dart';

class DarkDropdown extends StatelessWidget {
  const DarkDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.validator,
    this.labels,
  });

  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  /// Optional display-text override per item value; the stored `value`
  /// itself is unchanged so domain/data logic never sees the translation.
  final Map<String, String>? labels;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: key == null ? ValueKey('$hint-${value ?? 'empty'}') : null,
      initialValue: value,
      isExpanded: true,
      dropdownColor: diagnosisInput,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: diagnosisMuted,
      ),
      style: const TextStyle(color: diagnosisText, fontSize: 15),
      decoration: darkInputDecoration(),
      hint: Text(
        hint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: diagnosisText, fontSize: 15),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                labels?[item] ?? item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

