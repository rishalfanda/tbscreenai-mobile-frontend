import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';

/// Standard dark input decoration used across diagnosis form fields.
InputDecoration darkInputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: diagnosisInput,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
    border: darkOutlineBorder(diagnosisBorder),
    enabledBorder: darkOutlineBorder(diagnosisBorder),
    disabledBorder: darkOutlineBorder(diagnosisBorder.withValues(alpha: 0.55)),
    focusedBorder: darkOutlineBorder(diagnosisAccent, width: 1.7),
    errorBorder: darkOutlineBorder(const Color(0xFFEF4444)),
    focusedErrorBorder: darkOutlineBorder(const Color(0xFFEF4444), width: 1.7),
  );
}

/// Outline border generator for dark-themed input fields.
OutlineInputBorder darkOutlineBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: width),
  );
}

