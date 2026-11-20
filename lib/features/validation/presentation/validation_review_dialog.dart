import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/models/segmentation_overlays.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/result/xray_image_card.dart';

class ValidationReviewDialog extends StatefulWidget {
  const ValidationReviewDialog({
    super.key,
    required this.row,
    this.readOnly = false,
  });
  final ValidationCase row;
  final bool readOnly;
  @override
  State<ValidationReviewDialog> createState() => _ValidationReviewDialogState();
}

class _ValidationReviewDialogState extends State<ValidationReviewDialog> {
  late final UserProfile? _profile;
  late final TextEditingController _note;
  late final Future<XrayImage?> _image;
  late final Future<SegmentationOverlays?> _segmentation;
  late int? _score;
  late String? _verdict;
  bool _saving = false;
  String? _error;
  bool get _locked =>
      widget.readOnly || widget.row.hasConflict || widget.row.isMock || _saving;

  @override
  void initState() {
    super.initState();
    _profile = context.read<AuthProvider>().profile;
    final row = widget.row;
    _note = TextEditingController(
      text: row.validationNote ?? row.doctorNote ?? '',
    );
    _score = row.lesionRating;
    _verdict = const {'agreed', 'disagreed'}.contains(row.status)
        ? row.status
        : null;
    final repo = context.read<ValidationRepository>();
    _image = (repo as NumericValidationRepository).loadCaseImage(row.id);
    _segmentation = repo is SegmentationValidationRepository
        ? (repo as SegmentationValidationRepository).loadCaseSegmentation(
            row.id,
          )
        : Future.value(null);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_locked || _verdict == null || _score == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (context.read<ValidationRepository>()
              as LesionRatingValidationRepository)
          .submitLesionRating(
            id: widget.row.id,
            rating: _score!,
            status: _verdict!,
            note: _note.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.trRead(
            'Validasi belum tersimpan. Periksa status sinkronisasi atau konflik data, lalu coba lagi.',
            'Validation was not saved. Check sync or data conflict status, then retry.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn ||
        auth.profile != _profile ||
        auth.mustChangePassword ||
        auth.role != 'doctor') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).removeRoute(ModalRoute.of(context)!);
      });
      return const SizedBox.shrink();
    }
    final row = widget.row;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.trRead(
                          widget.readOnly
                              ? 'Detail screening'
                              : 'Validasi screening',
                          widget.readOnly
                              ? 'Screening details'
                              : 'Screening validation',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: context.trRead('Tutup', 'Close'),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _patientHeader(context, row),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColoredBox(
                            color: const Color(0xFF101827),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: FutureBuilder<XrayImage?>(
                                future: _image,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState !=
                                      ConnectionState.done) {
                                    return const SizedBox(
                                      height: 320,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError ||
                                      snapshot.data == null) {
                                    return SizedBox(
                                      height: 160,
                                      child: Center(
                                        child: Text(
                                          context.trRead(
                                            'X-ray lokal tidak tersedia.',
                                            'Local X-ray unavailable.',
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return FutureBuilder<SegmentationOverlays?>(
                                    future: _segmentation,
                                    builder: (context, masks) => XrayImageCard(
                                      key: ValueKey('image-${row.id}'),
                                      image: snapshot.data,
                                      segmentation: masks.data,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _panel(
                          context,
                          Text(
                            '${context.trRead("Hasil AI", "AI result")}: ${row.isPositive == null
                                ? "-"
                                : row.isPositive!
                                ? context.trRead("Positif TB", "TB positive")
                                : context.trRead("Negatif TB", "TB negative")} / ${row.aiScore}%',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.trRead(
                            'Validasi screening',
                            'Validation screening',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        RadioGroup<String>(
                          groupValue: _verdict,
                          onChanged: (value) {
                            if (!_locked) setState(() => _verdict = value);
                          },
                          child: Wrap(
                            children: [
                              for (final entry in const {
                                'agreed': 'Agree',
                                'disagreed': 'Disagree',
                              }.entries)
                                SizedBox(
                                  width: 180,
                                  child: RadioListTile<String>(
                                    key: ValueKey('verdict-${entry.key}'),
                                    value: entry.key,
                                    title: Text(entry.value),
                                    enabled: !_locked,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (row.validationScore != null &&
                            row.lesionRating == null)
                          Text(
                            context.trRead(
                              'Skor kepercayaan lama bukan rating lesi. Pilih rating lesi baru.',
                              'The previous trust score is not a lesion rating. Select a new lesion rating.',
                            ),
                          ),
                        Text(
                          context.trRead(
                            'Rating hasil lesi (0-10)',
                            'Lesion result rating (0-10)',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        RadioGroup<int>(
                          groupValue: _score,
                          onChanged: (value) {
                            if (!_locked) setState(() => _score = value);
                          },
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 8,
                            children: [
                              for (var value = 0; value <= 10; value++)
                                _ratingOption(value),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('validation-note'),
                          controller: _note,
                          enabled: !_locked,
                          maxLength: 500,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: context.trRead(
                              'Catatan dokter (opsional)',
                              'Doctor note (optional)',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        if (row.hasConflict)
                          Text(
                            context.trRead(
                              'Selesaikan konflik data sebelum mengubah validasi.',
                              'Resolve the data conflict before editing validation.',
                            ),
                          ),
                        if (_error != null)
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!widget.readOnly) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('confirm-validation-score'),
                      onPressed: _locked || _verdict == null || _score == null
                          ? null
                          : _save,
                      child: Text(
                        _saving
                            ? context.trRead('Menyimpan...', 'Saving...')
                            : context.trRead(
                                'Konfirmasi & simpan offline',
                                'Confirm & save offline',
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ratingOption(int value) {
    final color = HSVColor.fromAHSV(1, value * 12.0, .85, .72).toColor();
    return SizedBox(
      width: 62,
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color,
            foregroundColor: Colors.white,
            child: Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Radio<int>(
            key: ValueKey('lesion-rating-$value'),
            value: value,
            enabled: !_locked,
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );

  Widget _patientHeader(BuildContext context, ValidationCase row) => _panel(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.name,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '${row.age} · ${row.gender}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 20,
          runSpacing: 6,
          children: [
            if (row.patientCode != null)
              Text(
                '${context.trRead("Kode pasien", "Patient code")}: ${row.patientCode}',
              ),
            if (row.heightCm != null || row.weightKg != null)
              Text('${row.heightCm ?? "—"} cm · ${row.weightKg ?? "—"} kg'),
          ],
        ),
        if (row.symptoms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${context.trRead("Gejala", "Symptoms")}: ${row.symptoms.join(", ")}',
          ),
        ],
      ],
    ),
  );
}
