import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/application/xray_image_picker.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:provider/provider.dart';

const Color _page = Color(0xFF111827);
const Color _panel = Color(0xFF1E293B);
const Color _input = Color(0xFF0F172A);
const Color _border = Color(0xFF475569);
const Color _text = Color(0xFFF8FAFC);
const Color _muted = Color(0xFF94A3B8);
const Color _accent = Color(0xFF4F9BFF);
const Color _action = Color(0xFF2463EB);

// Display-label translations. Dropdown/radio `value`s stay in English (the
// domain/data-layer contract); only what's rendered is Bahasa Indonesia.
const Map<String, String> _yesNoLabels = {'Yes': 'Ya', 'No': 'Tidak'};
const Map<String, String> _yesNoUnknownLabels = {
  'Unknown': 'Tidak Diketahui',
  'No': 'Tidak',
  'Yes': 'Ya',
};
const Map<String, String> _positiveNegativeLabels = {
  'Positive': 'Positif',
  'Negative': 'Negatif',
};
const Map<String, String> _positiveNegativeOtherLabels = {
  'Positive': 'Positif',
  'Negative': 'Negatif',
  'Other': 'Lainnya',
};
const Map<String, String> _btaLabels = {
  'BTA Positive': 'BTA Positif',
  'BTA Negative': 'BTA Negatif',
};
const Map<String, String> _genderLabels = {
  'Female': 'Perempuan',
  'Male': 'Laki-laki',
};
const Map<String, String> _comorbidityLabels = {
  'None': 'Tidak Ada',
  'Diabetes Mellitus': 'Diabetes Melitus',
  'HIV/AIDS': 'HIV/AIDS',
  'Other Immunocompromised Conditions': 'Kondisi Imun Lemah Lainnya',
};
const Map<String, String> _smokingLabels = {
  'Never': 'Tidak Pernah',
  'Former': 'Mantan Perokok',
  'Current': 'Perokok Aktif',
};
const Map<String, String> _tbStatusLabels = {
  'Suspected': 'Diduga',
  'Screening': 'Skrining',
  'Follow-up': 'Tindak Lanjut',
};
const Map<String, String> _modelTypeLabels = {
  'Disability': 'Disabilitas',
  'Non Disability': 'Non-Disabilitas',
};
const Map<String, String> _symptomLabels = {
  'Fever': 'Demam',
  'Cough': 'Batuk',
  'Night Sweats': 'Keringat Malam',
  'Weight Loss': 'Penurunan Berat Badan',
  'Shortness of Breath': 'Sesak Napas',
  'Fatigue': 'Kelelahan',
  'Loss of Appetite': 'Kehilangan Nafsu Makan',
  'Chest Pain': 'Nyeri Dada',
  'Hemoptysis/Coughing Blood': 'Batuk Darah (Hemoptisis)',
  'Other': 'Lainnya',
};

typedef PickXrayImage = Future<XrayImage?> Function();

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key, this.pickImage, this.hasModelOverride});

  /// Injection point used by widget tests; production uses [XrayImagePicker].
  final PickXrayImage? pickImage;

  /// Test-only override for whether an on-device AI model is installed.
  /// Left null in production, which reads the real
  /// `OnnxInferenceEngine.hasBundle` from the provider tree; set by widget
  /// tests that don't wire up an [OnnxInferenceEngine] provider.
  final bool? hasModelOverride;

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _pediatricController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = XrayImagePicker();
  bool _initialized = false;
  bool _pickingImage = false;

  static const _symptoms = <String>[
    'Fever',
    'Cough',
    'Night Sweats',
    'Weight Loss',
    'Shortness of Breath',
    'Fatigue',
    'Loss of Appetite',
    'Chest Pain',
    'Hemoptysis/Coughing Blood',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final draft = context.read<DiagnosisProvider>().draft;
    _nameController.text = draft.patientName;
    _ageController.text = draft.age?.toString() ?? '';
    _heightController.text = _numberText(draft.heightCm);
    _weightController.text = _numberText(draft.weightKg);
    _pediatricController.text = draft.pediatricScore?.toString() ?? '';
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _pediatricController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final image =
          await (widget.pickImage?.call() ?? _imagePicker.pickFromGallery());
      if (image != null && mounted) {
        context.read<DiagnosisProvider>().attachImage(image);
      }
    } on XrayImageValidationException catch (error) {
      if (mounted) _showMessage(error.message, isError: true);
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage(
          error.message ?? 'Galeri gambar tidak dapat dibuka.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Citra rontgen tidak dapat dibuka.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    final provider = context.read<DiagnosisProvider>();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showMessage('Lengkapi data pasien yang wajib diisi.', isError: true);
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (!provider.hasImage) {
      _showMessage(
        'Unggah atau ambil foto rontgen dada sebelum analisis.',
        isError: true,
      );
      return;
    }

    final success = await provider.runDiagnosis();
    if (!mounted) return;
    if (success && provider.lastOutcome != null) {
      context.go('/result');
    } else {
      _showMessage(
        provider.lastError ?? 'Analisis gagal. Coba lagi.',
        isError: true,
      );
    }
  }

  void _showMessage(String message, {required bool isError}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFB91C1C) : _panel,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = context.watch<DiagnosisProvider>();
    final hasModel =
        widget.hasModelOverride ??
        context.read<OnnxInferenceEngine>().hasBundle;

    return ColoredBox(
      color: _page,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'Analisis Rontgen TB dengan AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _accent,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final left = _leftFormColumn(diagnosis);
                          final right = _rightImageColumn(diagnosis, hasModel);
                          if (constraints.maxWidth >= 800) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: left),
                                const SizedBox(width: 32),
                                Expanded(child: right),
                              ],
                            );
                          }
                          return Column(
                            children: [left, const SizedBox(height: 24), right],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leftFormColumn(DiagnosisProvider diagnosis) {
    final draft = diagnosis.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topFields(diagnosis),
        const SizedBox(height: 18),
        _OptionalFieldsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(
                icon: Icons.coronavirus_outlined,
                text: 'Jenis Gejala',
              ),
              const SizedBox(height: 6),
              _SymptomGrid(
                symptoms: _symptoms,
                selected: draft.symptoms,
                onChanged: diagnosis.toggleSymptom,
              ),
              const SizedBox(height: 14),
              _clinicalDropdowns(diagnosis),
              const SizedBox(height: 14),
              _pediatricField(diagnosis),
              const SizedBox(height: 20),
              _leftClinicalColumn(diagnosis),
              const SizedBox(height: 18),
              _LabeledField(
                label: 'Jenis Model',
                icon: Icons.psychology_outlined,
                child: _DarkDropdown(
                  key: const Key('model-type-dropdown'),
                  value: draft.modelType,
                  hint: 'Pilih Jenis Model',
                  items: const ['Disability', 'Non Disability'],
                  labels: _modelTypeLabels,
                  onChanged: diagnosis.updateModelType,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topFields(DiagnosisProvider diagnosis) {
    final name = _LabeledField(
      label: 'Nama/Inisial/Nama Panggilan',
      child: _DarkTextField(
        key: const Key('patient-name'),
        controller: _nameController,
        textInputAction: TextInputAction.next,
        onChanged: diagnosis.updatePatientName,
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Nama wajib diisi' : null,
      ),
    );
    final gender = _LabeledField(
      label: 'Jenis Kelamin',
      child: _DarkDropdown(
        key: const Key('gender'),
        value: diagnosis.draft.gender,
        hint: 'Pilih Jenis Kelamin',
        items: const ['Female', 'Male'],
        labels: _genderLabels,
        onChanged: diagnosis.updateGender,
        validator: (value) =>
            value == null ? 'Jenis kelamin wajib dipilih' : null,
      ),
    );
    final age = _numberField(
      label: 'Usia',
      key: const Key('age'),
      controller: _ageController,
      onChanged: (value) => diagnosis.updateAge(int.tryParse(value)),
      min: 1,
      max: 130,
    );
    final height = _numberField(
      label: 'Tinggi Badan (cm)',
      key: const Key('height'),
      controller: _heightController,
      onChanged: (value) => diagnosis.updateHeight(double.tryParse(value)),
      min: 20,
      max: 260,
      decimal: true,
    );
    final weight = _numberField(
      label: 'Berat Badan (kg)',
      key: const Key('weight'),
      controller: _weightController,
      onChanged: (value) => diagnosis.updateWeight(double.tryParse(value)),
      min: 1,
      max: 400,
      decimal: true,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        name,
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: gender),
            const SizedBox(width: 16),
            Expanded(child: age),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: height),
            const SizedBox(width: 16),
            Expanded(child: weight),
          ],
        ),
      ],
    );
  }

  Widget _numberField({
    required String label,
    required Key key,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required double min,
    required double max,
    bool decimal = false,
  }) {
    return _LabeledField(
      label: label,
      child: _DarkTextField(
        key: key,
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            decimal ? RegExp(r'^\d*\.?\d{0,2}') : RegExp(r'^\d*'),
          ),
        ],
        onChanged: onChanged,
        validator: (value) {
          final parsed = double.tryParse(value ?? '');
          if (parsed == null) return 'Wajib diisi';
          if (parsed < min || parsed > max) return '$min–$max';
          return null;
        },
      ),
    );
  }

  Widget _clinicalDropdowns(DiagnosisProvider diagnosis) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          _LabeledField(
            label: 'Komorbiditas',
            icon: Icons.medical_information_outlined,
            child: _DarkDropdown(
              value: diagnosis.draft.comorbidity,
              hint: 'Pilih Komorbiditas',
              items: const [
                'None',
                'Diabetes Mellitus',
                'HIV/AIDS',
                'Other Immunocompromised Conditions',
              ],
              labels: _comorbidityLabels,
              onChanged: diagnosis.updateComorbidity,
            ),
          ),
          _LabeledField(
            label: 'Merokok',
            icon: Icons.smoking_rooms_outlined,
            child: _DarkDropdown(
              value: diagnosis.draft.smoking,
              hint: 'Pilih Status Merokok',
              items: const ['Never', 'Former', 'Current'],
              labels: _smokingLabels,
              onChanged: diagnosis.updateSmoking,
            ),
          ),
          _LabeledField(
            label: 'Riwayat Kontak dengan TB',
            icon: Icons.history_rounded,
            child: _DarkDropdown(
              value: diagnosis.draft.tbContact,
              hint: 'Pilih Riwayat',
              items: const ['Unknown', 'No', 'Yes'],
              labels: _yesNoUnknownLabels,
              onChanged: diagnosis.updateTbContact,
            ),
          ),
        ];

        if (constraints.maxWidth >= 800) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[0]),
              const SizedBox(width: 20),
              Expanded(child: fields[1]),
              const SizedBox(width: 20),
              Expanded(child: fields[2]),
            ],
          );
        }
        return Column(
          children: [
            fields[0],
            const SizedBox(height: 14),
            fields[1],
            const SizedBox(height: 14),
            fields[2],
          ],
        );
      },
    );
  }

  Widget _pediatricField(DiagnosisProvider diagnosis) {
    final enabled = diagnosis.requiresPediatricScore;
    return FractionallySizedBox(
      widthFactor: 0.48,
      alignment: Alignment.centerLeft,
      child: _LabeledField(
        label: 'Jika Usia < 18 Tahun, Skor TB Anak',
        child: _DarkTextField(
          key: ValueKey('pediatric-${enabled ? 'enabled' : 'disabled'}'),
          controller: _pediatricController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) =>
              diagnosis.updatePediatricScore(int.tryParse(value)),
          validator: (value) {
            if (!enabled || value == null || value.isEmpty) return null;
            final parsed = int.tryParse(value);
            return parsed == null || parsed < 0 || parsed > 13
                ? 'Masukkan skor 0 sampai 13'
                : null;
          },
        ),
      ),
    );
  }

  Widget _leftClinicalColumn(DiagnosisProvider diagnosis) {
    final draft = diagnosis.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(icon: Icons.home_rounded, text: 'Lingkungan'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Keberadaan Jendela',
                icon: Icons.window_rounded,
                child: _DarkDropdown(
                  value: draft.windowsPresence,
                  hint: 'Pilih Opsi',
                  items: const ['Yes', 'No'],
                  labels: _yesNoLabels,
                  onChanged: diagnosis.updateWindowsPresence,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _LabeledField(
                label: 'Paparan Sinar Matahari Langsung',
                icon: Icons.light_mode_outlined,
                child: _DarkDropdown(
                  key: const Key('sunlight-dropdown'),
                  value: draft.sunlightExposure,
                  hint: 'Pilih Opsi',
                  items: const ['Yes', 'No'],
                  labels: _yesNoLabels,
                  onChanged: diagnosis.updateSunlightExposure,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'A. Bakteriologi',
          style: TextStyle(
            color: _text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RadioGroup(
                label: 'Pemeriksaan Dahak (BTA):',
                values: const ['BTA Positive', 'BTA Negative'],
                selected: draft.bta == null ? null : 'BTA ${draft.bta}',
                labels: _btaLabels,
                onChanged: (value) => diagnosis.updateBta(
                  value == 'BTA Positive' ? 'Positive' : 'Negative',
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _RadioGroup(
                label: 'Kultur:',
                values: const ['Positive', 'Negative'],
                selected: draft.culture,
                labels: _positiveNegativeLabels,
                onChanged: diagnosis.updateCulture,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _RadioGroup(
                label: 'Xpert MTB/Rif atau NAAT:',
                values: const ['Positive', 'Negative'],
                selected: draft.xpert,
                labels: _positiveNegativeLabels,
                onChanged: diagnosis.updateXpert,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'B. Lainnya',
          style: TextStyle(
            color: _text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _RadioGroup(
          label: 'IGRA:',
          values: const ['Positive', 'Negative', 'Other'],
          selected: draft.igra,
          horizontal: true,
          labels: _positiveNegativeOtherLabels,
          onChanged: diagnosis.updateIgra,
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Riwayat TB',
                child: _DarkDropdown(
                  value: draft.tbHistory,
                  hint: 'Pilih Riwayat TB',
                  items: const ['No', 'Yes'],
                  labels: _yesNoLabels,
                  onChanged: diagnosis.updateTbHistory,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _LabeledField(
                label: 'Status TB',
                child: _DarkDropdown(
                  value: draft.tbStatus,
                  hint: 'Pilih Status TB',
                  items: const ['Suspected', 'Screening', 'Follow-up'],
                  labels: _tbStatusLabels,
                  onChanged: diagnosis.updateTbStatus,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rightImageColumn(DiagnosisProvider diagnosis, bool hasModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasModel) ...[
          _NoModelBanner(onGoToSync: () => context.go('/sync')),
          const SizedBox(height: 18),
        ],
        const _FieldLabel(text: 'Unggah Citra Rontgen'),
        const SizedBox(height: 8),
        SizedBox(
          height: 420,
          width: double.infinity,
          child: _DashedUploadPanel(
            image: diagnosis.image,
            loading: _pickingImage,
            onUpload: _pickImage,
            onCamera: () => context.push('/camera'),
            onRemove: diagnosis.hasImage ? diagnosis.clearImage : null,
          ),
        ),
        const SizedBox(height: 24),
        if (diagnosis.lastError != null) ...[
          _InlineError(message: diagnosis.lastError!),
          const SizedBox(height: 18),
        ],
        SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton(
            key: const Key('analyze-button'),
            onPressed: (!hasModel || diagnosis.isRunning) ? null : _analyze,
            style: FilledButton.styleFrom(
              backgroundColor: _action,
              disabledBackgroundColor: _action.withValues(alpha: 0.55),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: diagnosis.isRunning
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Text(
                    'Analisis',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ],
    );
  }
}

class _OptionalFieldsPanel extends StatelessWidget {
  const _OptionalFieldsPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('optional-fields-panel'),
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 14),
          iconColor: _accent,
          collapsedIconColor: _muted,
          textColor: _text,
          collapsedTextColor: _text,
          title: const Text(
            'Informasi Tambahan (Opsional)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'Gejala, lingkungan, dan hasil pemeriksaan klinis',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _NoModelBanner extends StatelessWidget {
  const _NoModelBanner({required this.onGoToSync});

  final VoidCallback onGoToSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        border: Border.all(color: _accent),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: _accent),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Model AI belum terpasang di perangkat ini. Unduh model dari '
                  'Pusat Sinkronisasi sebelum menjalankan analisis.',
                  style: TextStyle(color: _text, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onGoToSync,
              style: TextButton.styleFrom(foregroundColor: _accent),
              child: const Text('Buka Pusat Sinkronisasi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SymptomGrid extends StatelessWidget {
  const _SymptomGrid({
    required this.symptoms,
    required this.selected,
    required this.onChanged,
  });

  final List<String> symptoms;
  final Set<String> selected;
  final void Function(String symptom, bool selected) onChanged;

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
                        _symptomLabels[symptom] ?? symptom,
                        style: const TextStyle(color: _text, fontSize: 15),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      activeColor: _accent,
                      checkColor: _input,
                      side: const BorderSide(color: _muted, width: 1.5),
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child, this.icon});

  final String label;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(text: label, icon: icon),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, this.icon});

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
          child: Text(
            text,
            maxLines: 2,
            style: const TextStyle(
              color: _text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFFD7DEE8)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: _text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
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
      style: const TextStyle(color: _text, fontSize: 15),
      cursorColor: _accent,
      decoration: _decoration().copyWith(
        fillColor: enabled ? _input : _input.withValues(alpha: 0.55),
      ),
    );
  }
}

class _DarkDropdown extends StatelessWidget {
  const _DarkDropdown({
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
      dropdownColor: _input,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
      style: const TextStyle(color: _text, fontSize: 15),
      decoration: _decoration(),
      hint: Text(
        hint,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _text, fontSize: 15),
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

InputDecoration _decoration() {
  return InputDecoration(
    filled: true,
    fillColor: _input,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11),
    border: _outline(_border),
    enabledBorder: _outline(_border),
    disabledBorder: _outline(_border.withValues(alpha: 0.55)),
    focusedBorder: _outline(_accent, width: 1.7),
    errorBorder: _outline(const Color(0xFFEF4444)),
    focusedErrorBorder: _outline(const Color(0xFFEF4444), width: 1.7),
  );
}

OutlineInputBorder _outline(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color, width: width),
  );
}

class _RadioGroup extends StatelessWidget {
  const _RadioGroup({
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
            color: _text,
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
            activeColor: _accent,
            fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? _accent
                  : const Color(0xFFE5E7EB),
            ),
            visualDensity: VisualDensity.compact,
          ),
          Flexible(
            child: Text(
              labels?[value] ?? value,
              maxLines: 2,
              style: const TextStyle(color: _text, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedUploadPanel extends StatelessWidget {
  const _DashedUploadPanel({
    required this.image,
    required this.loading,
    required this.onUpload,
    required this.onCamera,
    required this.onRemove,
  });

  final XrayImage? image;
  final bool loading;
  final VoidCallback onUpload;
  final VoidCallback onCamera;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: _input,
          child: image == null ? _emptyState() : _preview(),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const CircularProgressIndicator(color: _accent)
          else
            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 52,
              color: _muted,
            ),
          const SizedBox(height: 16),
          const Text(
            'Unggah Citra Rontgen',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'PNG, JPG, JPEG · Maksimal 25 MB',
            style: TextStyle(color: Color(0xFF71809A), fontSize: 12),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                key: const Key('upload-xray'),
                onPressed: loading ? null : onUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 19),
                label: const Text('Pilih Gambar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                ),
              ),
              FilledButton.icon(
                key: const Key('capture-xray'),
                onPressed: loading ? null : onCamera,
                icon: const Icon(Icons.photo_camera_rounded, size: 19),
                label: const Text('Gunakan Kamera'),
                style: FilledButton.styleFrom(backgroundColor: _action),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Gunakan citra rontgen digital asli jika tersedia. Pengambilan foto '
            'dengan kamera dapat menurunkan kualitas gambar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final current = image!;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (current.canPreview)
          Image.memory(
            current.bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _fileFallback(current),
          )
        else
          _fileFallback(current),
        Positioned(
          left: 12,
          right: 58,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${current.filename} · ${_formatBytes(current.sizeBytes)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: IconButton(
            tooltip: 'Hapus Rontgen',
            onPressed: onRemove,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.72),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ],
    );
  }

  Widget _fileFallback(XrayImage current) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monitor_heart_outlined, size: 64, color: _muted),
          const SizedBox(height: 12),
          Text(
            current.filename,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _text),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 7.0;
    const gap = 5.0;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final paint = Paint()
      ..color = _border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF7F1D1D),
          border: Border.all(color: const Color(0xFFEF4444)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFFCA5A5)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: _text, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _numberText(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
