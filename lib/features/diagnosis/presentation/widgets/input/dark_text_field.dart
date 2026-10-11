import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/input/dark_input_decoration.dart';

class DarkTextField extends StatelessWidget {
  const DarkTextField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.enabled = true,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(color: diagnosisText, fontSize: 15),
      cursorColor: diagnosisAccent,
      decoration: darkInputDecoration().copyWith(
        fillColor: enabled
            ? diagnosisInput
            : diagnosisInput.withValues(alpha: 0.55),
      ),
    );
  }
}

