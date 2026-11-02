import 'package:flutter/material.dart';
import 'package:myapp/core/localization/app_language.dart';

class SecretFormField extends StatefulWidget {
  const SecretFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.enabled = true,
    this.maxLength,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool enabled;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;
  @override
  State<SecretFormField> createState() => _SecretFormFieldState();
}

class _SecretFormFieldState extends State<SecretFormField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: _hidden,
    enabled: widget.enabled,
    enableSuggestions: false,
    autocorrect: false,
    maxLength: widget.maxLength,
    validator: widget.validator,
    onFieldSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        tooltip: context.trRead(
          _hidden ? 'Tampilkan teks' : 'Sembunyikan teks',
          _hidden ? 'Show text' : 'Hide text',
        ),
        onPressed: widget.enabled
            ? () => setState(() => _hidden = !_hidden)
            : null,
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
