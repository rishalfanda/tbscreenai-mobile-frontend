import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/state/diagnosis_provider.dart';

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String _gender = 'Gender';
  String _comorbidity = 'Comorbidity';
  String _smoking = 'Smoking Status';
  String _tbContact = 'TB Contact History';
  String _windowsPresence = 'Presence of Windows';
  String _sunlightExposure = 'Direct Sunlight Exposure';
  String _bta = 'Negative';
  String _culture = 'Negative';
  String _xpert = 'Negative';
  String _igra = 'Negative';
  String _tbHistory = 'History of TB';
  String _tbStatus = 'TB Status';
  String _modelType = 'Model Type';

  final List<String> _symptoms = [
    'Fever', 'Cough', 'Fatigue', 'Hemoptysis', 
    'Shortness Of Breath', 'Night Sweats', 
    'Loss Of Appetite', 'Weight Loss', 
    'Chest Pain', 'Other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = context.watch<DiagnosisProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TB Diagnosis',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete patient information and X-ray analysis',
            style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column - Scrollable Form
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(right: BorderSide(color: AppTheme.borderLight, width: 1)),
                    ),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(right: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionCard(
                              title: 'Basic Information',
                              child: Column(
                                children: [
                                  _CustomTextField(
                                    controller: _nameController,
                                    hintText: 'Name / Initial / Nickname',
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CustomDropdown(
                                          value: _gender,
                                          items: const ['Gender', 'Female', 'Male'],
                                          onChanged: (v) => setState(() => _gender = v!),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _CustomTextField(
                                          controller: _ageController,
                                          hintText: 'Age',
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CustomTextField(
                                          controller: _heightController,
                                          hintText: 'Height (cm)',
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _CustomTextField(
                                          controller: _weightController,
                                          hintText: 'Weight (kg)',
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Symptoms',
                              child: GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                childAspectRatio: 4,
                                children: _symptoms.map((s) => _CustomCheckbox(
                                  label: s,
                                  value: diagnosis.symptoms.contains(s),
                                  onChanged: (v) => diagnosis.toggleSymptom(s, v ?? false),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Clinical Background',
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CustomDropdown(
                                          value: _comorbidity,
                                          items: const ['Comorbidity', 'None', 'Diabetes', 'HIV', 'COPD'],
                                          onChanged: (v) => setState(() => _comorbidity = v!),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _CustomDropdown(
                                          value: _smoking,
                                          items: const ['Smoking Status', 'No', 'Former', 'Current'],
                                          onChanged: (v) => setState(() => _smoking = v!),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _CustomDropdown(
                                    value: _tbContact,
                                    items: const ['TB Contact History', 'Unknown', 'No', 'Yes'],
                                    onChanged: (v) => setState(() => _tbContact = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Environment',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _CustomDropdown(
                                      value: _windowsPresence,
                                      items: const ['Presence of Windows', 'Yes', 'No'],
                                      onChanged: (v) => setState(() => _windowsPresence = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _CustomDropdown(
                                      value: _sunlightExposure,
                                      items: const ['Direct Sunlight Exposure', 'Adequate', 'Limited', 'None'],
                                      onChanged: (v) => setState(() => _sunlightExposure = v!),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Bacteriology',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Expel Sputum (BTA)', style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 13)),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      _CustomRadio(label: 'BTA Positive', value: 'Positive', groupValue: _bta, onChanged: (v) => setState(() => _bta = v!)),
                                      _CustomRadio(label: 'BTA Negative', value: 'Negative', groupValue: _bta, onChanged: (v) => setState(() => _bta = v!)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Culture', style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 13)),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      _CustomRadio(label: 'Positive', value: 'Positive', groupValue: _culture, onChanged: (v) => setState(() => _culture = v!)),
                                      _CustomRadio(label: 'Negative', value: 'Negative', groupValue: _culture, onChanged: (v) => setState(() => _culture = v!)),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Xpert MTB/RIF or NAAT', style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 13)),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      _CustomRadio(label: 'Positive', value: 'Positive', groupValue: _xpert, onChanged: (v) => setState(() => _xpert = v!)),
                                      _CustomRadio(label: 'Negative', value: 'Negative', groupValue: _xpert, onChanged: (v) => setState(() => _xpert = v!)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Other Tests',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('IGRA', style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 13)),
                                  const Text('Interferon-Gamma Release Assay', style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 11)),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    children: [
                                      _CustomRadio(label: 'Positive', value: 'Positive', groupValue: _igra, onChanged: (v) => setState(() => _igra = v!)),
                                      _CustomRadio(label: 'Negative', value: 'Negative', groupValue: _igra, onChanged: (v) => setState(() => _igra = v!)),
                                      _CustomRadio(label: 'Other', value: 'Other', groupValue: _igra, onChanged: (v) => setState(() => _igra = v!)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'TB Status',
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _CustomDropdown(
                                          value: _tbHistory,
                                          items: const ['History of TB', 'No', 'Yes'],
                                          onChanged: (v) => setState(() => _tbHistory = v!),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _CustomDropdown(
                                          value: _tbStatus,
                                          items: const ['TB Status', 'Suspected', 'Screening', 'Follow-up'],
                                          onChanged: (v) => setState(() => _tbStatus = v!),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _CustomDropdown(
                                    value: _modelType,
                                    items: const ['Model Type', 'Chest X-ray', 'Hybrid Model', 'Pediatric Model'],
                                    onChanged: (v) => setState(() => _modelType = v!),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Right Column - Sticky X-ray Panel
                const SizedBox(width: 24),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      children: [
                        Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppTheme.borderLight),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'X-ray Image',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.navy),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 360,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.borderLight,
                                      width: 1.5,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: diagnosis.hasImage
                                      ? Center(child: Text(diagnosis.imageLabel!, style: const TextStyle(color: AppTheme.navy)))
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.upload_rounded, size: 48, color: AppTheme.textSecondary),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Upload or capture chest X-ray image',
                                              style: TextStyle(color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => diagnosis.attachMockImage('uploaded_xray.png'),
                                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                                        label: const Text('Upload X-ray Image'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.cyan,
                                          side: const BorderSide(color: AppTheme.cyan),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => context.push('/camera'),
                                        icon: const Icon(Icons.photo_camera_rounded, size: 18),
                                        label: const Text('Capture from Camera'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.cyan,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: diagnosis.hasImage && !diagnosis.isRunning
                                ? () async {
                                    await diagnosis.runDiagnosis();
                                    if (!context.mounted) return;
                                    context.go('/result');
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success,
                              disabledBackgroundColor: AppTheme.success.withValues(alpha: 0.5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: diagnosis.isRunning
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Run AI Diagnosis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Upload an X-ray image to enable analysis',
                          style: TextStyle(color: AppTheme.subtitleGrey, fontSize: 12),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.navy)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _CustomTextField extends StatelessWidget {
  const _CustomTextField({required this.controller, required this.hintText, this.keyboardType});
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.cyan, width: 1.5),
        ),
      ),
    );
  }
}

class _CustomDropdown extends StatelessWidget {
  const _CustomDropdown({required this.value, required this.items, required this.onChanged});
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.borderLight, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.cyan, width: 1.5),
        ),
      ),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: s == items[0] ? AppTheme.textSecondary : AppTheme.navy, fontSize: 14)))).toList(),
      onChanged: onChanged,
    );
  }
}

class _CustomCheckbox extends StatelessWidget {
  const _CustomCheckbox({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.navy,
            side: BorderSide(color: AppTheme.textSecondary, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppTheme.navy, fontSize: 13)),
      ],
    );
  }
}

class _CustomRadio extends StatelessWidget {
  const _CustomRadio({required this.label, required this.value, required this.groupValue, required this.onChanged});
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          // ignore: deprecated_member_use
          groupValue: groupValue,
          // ignore: deprecated_member_use
          onChanged: onChanged,
          activeColor: AppTheme.navy,
          visualDensity: VisualDensity.compact,
        ),
        Text(label, style: const TextStyle(color: AppTheme.navy, fontSize: 13)),
      ],
    );
  }
}
