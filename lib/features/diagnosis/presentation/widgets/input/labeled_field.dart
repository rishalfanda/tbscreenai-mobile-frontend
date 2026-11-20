import 'dark_text_field.dart';
import 'dark_dropdown.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/input/field_label.dart';

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.icon,
  });

  final String label;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final field = child;
    if (field is DarkTextField) {
      return field.withLabel(localize(context, label), icon);
    }
    if (field is DarkDropdown) {
      return field.withLabel(localize(context, label), icon);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(text: label, icon: icon),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}
