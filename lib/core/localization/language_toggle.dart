import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_language.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppLanguage?>();
    return SegmentedButton<String>(
      key: const Key('dashboard-language-toggle'),
      segments: const [
        ButtonSegment(value: 'id', label: Text('ID')),
        ButtonSegment(value: 'en', label: Text('ENG')),
      ],
      selected: {language?.locale.languageCode ?? 'en'},
      showSelectedIcon: false,
      onSelectionChanged: language == null
          ? null
          : (values) => language.select(values.single),
    );
  }
}
