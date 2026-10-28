import 'package:myapp/core/localization/app_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/application/prepare_inference_image.dart';
import 'package:myapp/features/diagnosis/application/xray_image_picker.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_palette.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/input/widgets.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:provider/provider.dart';

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

/// The "Input Data" tab of the combined diagnosis screen — the patient
/// form, X-ray upload/capture panel, and Analyze/Reset actions. Locks (goes
/// read-only) once an outcome exists; [DiagnosisScreen] gates which tab is
/// reachable and switches tabs via [onAnalyzeSuccess].
class DiagnosisInputTab extends StatefulWidget {
  const DiagnosisInputTab({
    super.key,
    required this.onAnalyzeSuccess,
    this.pickImage,
    this.hasModelOverride,
  });

  /// Called right after a successful analysis, so the tab host can switch
  /// to the result tab.
  final VoidCallback onAnalyzeSuccess;

  /// Injection point used by widget tests; production uses [XrayImagePicker].
  final PickXrayImage? pickImage;

  /// Test-only override for whether an on-device AI model is installed.
  /// Left null in production, which reads the real
  /// `OnnxInferenceEngine.hasBundle` from the provider tree; set by widget
  /// tests that don't wire up an [OnnxInferenceEngine] provider.
  final bool? hasModelOverride;

  @override
  State<DiagnosisInputTab> createState() => _DiagnosisInputTabState();
}

class _DiagnosisInputTabState extends State<DiagnosisInputTab> {
  // Reassigned (not final) on reset: `FormState.reset()` re-syncs each
  // TextFormField's controller from a stale `widget.initialValue` snapshot
  // taken at the *previous* build — which would stomp the controllers we
  // just cleared back to their old values. Swapping the key instead tears
  // down and recreates every FormFieldState from scratch, so no stale
  // snapshot survives.
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _pediatricController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = XrayImagePicker();
  bool _initialized = false;
  bool _pickingImage = false;
  String _imageLoadingMessage = 'Sedang memproses citra rontgen...';

  // `OnnxInferenceEngine.hasBundle` reads `false` until its startup `init()`
  // finishes loading the active bundle from disk. Reading it straight away
  // on a cold app start — before that resolves — wrongly reports "no model"
  // even when one is installed; awaiting `ready` first avoids that race.
  bool _checkingModel = true;
  bool _hasModelReady = false;

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
  void initState() {
    super.initState();
    if (AppConfig.useHttp || widget.hasModelOverride != null) {
      _checkingModel = false;
    } else {
      context.read<OnnxInferenceEngine>().ready.then((_) {
        if (!mounted) return;
        setState(() {
          _hasModelReady = context.read<OnnxInferenceEngine>().hasBundle;
          _checkingModel = false;
        });
      });
    }
  }

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
    setState(() {
      _pickingImage = true;
      _imageLoadingMessage = 'Sedang memproses citra rontgen...';
    });
    try {
      final image =
          await (widget.pickImage?.call() ?? _imagePicker.pickFromGallery());
      if (image != null && mounted) {
        setState(() {
          _imageLoadingMessage = 'Sedang memproses citra rontgen...';
        });
        final normalized = await prepareInferenceImage(image);
        if (mounted) {
          context.read<DiagnosisProvider>().attachImage(normalized);
        }
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

    // Captured before the `await` so the dialog can still be dismissed even
    // if this screen is unmounted (e.g. the user navigates away) mid-run.
    final navigator = Navigator.of(context, rootNavigator: true);
    _showAnalyzingDialog();
    final success = await provider.runDiagnosis();
    navigator.pop();
    if (!mounted) return;
    if (success && provider.lastOutcome != null) {
      widget.onAnalyzeSuccess();
    } else {
      _showMessage(
        provider.lastError ?? 'Analisis gagal. Coba lagi.',
        isError: true,
      );
    }
  }

  void _showAnalyzingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: diagnosisPanel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: diagnosisAccent),
                SizedBox(height: 18),
                AppText(
                  'Menganalisis citra rontgen...',
                  style: TextStyle(
                    color: diagnosisText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a confirmation dialog before [_resetForm] actually clears
  /// anything — resetting (especially after an analysis exists) is
  /// destructive and irreversible, so it must not fire on a single tap.
  Future<void> _confirmAndReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('reset-confirm-dialog'),
        backgroundColor: diagnosisPanel,
        title: const AppText(
          'Konfirmasi Atur Ulang',
          style: TextStyle(color: diagnosisText),
        ),
        content: const AppText(
          'Apakah Anda yakin ingin mengatur ulang data? Seluruh data pasien '
          'yang telah diisi dan hasil analisis (jika ada) akan dihapus dan '
          'tidak dapat dikembalikan.',
          style: TextStyle(color: diagnosisMuted),
        ),
        actions: [
          TextButton(
            key: const Key('reset-confirm-cancel-button'),
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: diagnosisMuted),
            child: const AppText('Batal'),
          ),
          FilledButton(
            key: const Key('reset-confirm-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
            ),
            child: const AppText('Ya, Atur Ulang'),
          ),
        ],
      ),
    );
    if (confirmed == true) _resetForm();
  }

  void _resetForm() {
    FocusScope.of(context).unfocus();
    context.read<DiagnosisProvider>().resetForNewDiagnosis();
    _nameController.clear();
    _ageController.clear();
    _heightController.clear();
    _weightController.clear();
    _pediatricController.clear();
    // Swap the key rather than calling `_formKey.currentState?.reset()` —
    // see the field doc above.
    setState(() => _formKey = GlobalKey<FormState>());
  }

  void _showMessage(String message, {required bool isError}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message),
          backgroundColor: isError ? const Color(0xFFB91C1C) : diagnosisPanel,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = context.watch<DiagnosisProvider>();
    final hasModel =
        AppConfig.useHttp || (widget.hasModelOverride ?? _hasModelReady);
    final checkingModel =
        !AppConfig.useHttp && widget.hasModelOverride == null && _checkingModel;
    final locked = diagnosis.lastOutcome != null;

    return ColoredBox(
      key: const Key('diagnosis-input-content'),
      color: diagnosisPage,
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                      decoration: BoxDecoration(
                        color: diagnosisPanel,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final left = IgnorePointer(
                                ignoring: locked,
                                child: Opacity(
                                  opacity: locked ? 0.55 : 1,
                                  child: _leftFormColumn(diagnosis),
                                ),
                              );
                              final right = _rightImageColumn(
                                diagnosis,
                                hasModel,
                                checkingModel,
                                locked,
                              );
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
                                children: [
                                  left,
                                  const SizedBox(height: 24),
                                  right,
                                ],
                              );
                            },
                          ),
                        ],
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
        OptionalFieldsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel(
                icon: Icons.coronavirus_outlined,
                text: 'Jenis Gejala',
              ),
              const SizedBox(height: 6),
              SymptomGrid(
                symptoms: _symptoms,
                selected: draft.symptoms,
                labels: _symptomLabels,
                onChanged: diagnosis.toggleSymptom,
              ),
              const SizedBox(height: 14),
              _clinicalDropdowns(diagnosis),
              const SizedBox(height: 14),
              _pediatricField(diagnosis),
              const SizedBox(height: 20),
              _leftClinicalColumn(diagnosis),
              const SizedBox(height: 18),
              LabeledField(
                label: 'Jenis Model',
                icon: Icons.psychology_outlined,
                child: DarkDropdown(
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
    final name = LabeledField(
      label: 'Nama/Inisial/Nama Panggilan',
      child: DarkTextField(
        key: const Key('patient-name'),
        controller: _nameController,
        textInputAction: TextInputAction.next,
        onChanged: diagnosis.updatePatientName,
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Nama wajib diisi' : null,
      ),
    );
    final gender = LabeledField(
      label: 'Jenis Kelamin',
      child: DarkDropdown(
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
    return LabeledField(
      label: label,
      child: DarkTextField(
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
          LabeledField(
            label: 'Komorbiditas',
            icon: Icons.medical_information_outlined,
            child: DarkDropdown(
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
          LabeledField(
            label: 'Merokok',
            icon: Icons.smoking_rooms_outlined,
            child: DarkDropdown(
              value: diagnosis.draft.smoking,
              hint: 'Pilih Status Merokok',
              items: const ['Never', 'Former', 'Current'],
              labels: _smokingLabels,
              onChanged: diagnosis.updateSmoking,
            ),
          ),
          LabeledField(
            label: 'Riwayat Kontak dengan TB',
            icon: Icons.history_rounded,
            child: DarkDropdown(
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
      child: LabeledField(
        label: 'Jika Usia < 18 Tahun, Skor TB Anak',
        child: DarkTextField(
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
        const SectionLabel(icon: Icons.home_rounded, text: 'Lingkungan'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Keberadaan Jendela',
                icon: Icons.window_rounded,
                child: DarkDropdown(
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
              child: LabeledField(
                label: 'Paparan Sinar Matahari Langsung',
                icon: Icons.light_mode_outlined,
                child: DarkDropdown(
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
        const AppText(
          'A. Bakteriologi',
          style: TextStyle(
            color: diagnosisText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DarkRadioGroup(
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
              child: DarkRadioGroup(
                label: 'Kultur:',
                values: const ['Positive', 'Negative'],
                selected: draft.culture,
                labels: _positiveNegativeLabels,
                onChanged: diagnosis.updateCulture,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DarkRadioGroup(
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
        const AppText(
          'B. Lainnya',
          style: TextStyle(
            color: diagnosisText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        DarkRadioGroup(
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
              child: LabeledField(
                label: 'Riwayat TB',
                child: DarkDropdown(
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
              child: LabeledField(
                label: 'Status TB',
                child: DarkDropdown(
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

  Widget _rightImageColumn(
    DiagnosisProvider diagnosis,
    bool hasModel,
    bool checkingModel,
    bool locked,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!checkingModel && !hasModel) ...[
          const NoModelBanner(),
          const SizedBox(height: 18),
        ],
        IgnorePointer(
          ignoring: locked,
          child: Opacity(
            opacity: locked ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel(text: 'Unggah Citra Rontgen'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 420,
                  width: double.infinity,
                  child: DashedUploadPanel(
                    image: diagnosis.image,
                    loading: _pickingImage,
                    loadingMessage: _imageLoadingMessage,
                    onUpload: _pickImage,
                    onCamera: () => context.push('/camera'),
                    onRemove: diagnosis.hasImage ? diagnosis.clearImage : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (diagnosis.lastError != null) ...[
          InlineError(message: diagnosis.lastError!),
          const SizedBox(height: 18),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 60,
                child: OutlinedButton(
                  key: const Key('reset-button'),
                  onPressed: diagnosis.isRunning ? null : _confirmAndReset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: diagnosisText,
                    side: const BorderSide(color: diagnosisBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const AppText(
                    'Atur Ulang',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 60,
                child: FilledButton(
                  key: const Key('analyze-button'),
                  onPressed: (!hasModel || diagnosis.isRunning || locked)
                      ? null
                      : _analyze,
                  style: FilledButton.styleFrom(
                    backgroundColor: diagnosisAction,
                    disabledBackgroundColor: diagnosisAction.withValues(
                      alpha: 0.55,
                    ),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const AppText(
                    'Analisis',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _numberText(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
