import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/state/auth_provider.dart';

/// Reads the exact locally persisted screening and never fetches patient images.
class OfflineValidationScreen extends StatefulWidget {
  const OfflineValidationScreen({super.key, this.caseId});
  final String? caseId;
  @override
  State<OfflineValidationScreen> createState() =>
      _OfflineValidationScreenState();
}

class _OfflineValidationScreenState extends State<OfflineValidationScreen> {
  final _note = TextEditingController();
  List<ValidationCase> _cases = [];
  ValidationCase? _selected;
  Future<XrayImage?>? _image;
  int? _score;
  bool? _doctorPositive;
  bool _loading = true, _saving = false;
  String? _error;
  NumericValidationRepository get _numeric =>
      context.read<ValidationRepository>() as NumericValidationRepository;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    try {
      final rows = await context.read<ValidationRepository>().getCases();
      if (!mounted || profile != auth.profile || !auth.isLoggedIn) return;
      final requested = _selected?.id ?? widget.caseId;
      final matches = rows.where((row) => row.id == requested);
      setState(() {
        _cases = rows;
        _loading = false;
        _error = null;
        if (requested != null && matches.isEmpty) {
          _selected = null;
          _image = null;
          _error = 'Screening yang dipilih tidak tersedia di perangkat ini.';
        } else if (rows.isNotEmpty) {
          _select(matches.isEmpty ? rows.first : matches.first);
        }
      });
    } catch (_) {
      if (mounted && profile == auth.profile) {
        setState(() {
          _loading = false;
          _error = 'Data validation tidak dapat dibaca.';
        });
      }
    }
  }

  void _select(ValidationCase row) {
    _selected = row;
    _score = row.validationScore;
    _doctorPositive = row.status == 'pending' || row.isPositive == null
        ? null
        : (row.status == 'agreed' ? row.isPositive : !row.isPositive!);
    _note.text = row.validationNote ?? '';
    _image = _numeric.loadCaseImage(row.id);
  }

  Future<void> _confirm() async {
    final selected = _selected;
    final score = _score;
    if (selected == null ||
        score == null ||
        _saving ||
        _doctorPositive == null ||
        selected.isPositive == null) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _numeric.submitScore(
        id: selected.id,
        score: score,
        status: _doctorPositive == selected.isPositive ? 'agreed' : 'disagreed',
        note: _note.text,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final row = _selected;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.trRead('Validasi dokter', 'Doctor validation'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          context.trRead(
            'Screening dan validasi tersimpan di perangkat ini.',
            'Screening and validation are stored on this device.',
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_cases.isEmpty)
          Text(
            context.trRead(
              'Belum ada screening lokal. Pilih pasien lalu jalankan screening.',
              'No local screening. Select a patient and run screening first.',
            ),
          ),
        if (_cases.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: row?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.trRead(
                'Pilih screening pasien',
                'Select patient screening',
              ),
              border: const OutlineInputBorder(),
            ),
            items: _cases
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      '${item.name} · ${item.diagnosisDate} · ${item.validationScore == null ? context.trRead("Belum divalidasi", "Pending") : "${item.validationScore}/10"}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (id) => setState(
                    () => _select(_cases.firstWhere((item) => item.id == id)),
                  ),
          ),
        ],
        if (row != null) ...[
          const SizedBox(height: 16),
          Text(
            '${row.name} · ${row.age} · ${row.gender}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 360,
            child: ColoredBox(
              color: Colors.black,
              child: FutureBuilder<XrayImage?>(
                key: ValueKey(row.id),
                future: _image,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final image = snapshot.data;
                  if (image == null || snapshot.hasError) {
                    return Center(
                      child: Text(
                        context.trRead(
                          'X-ray lokal tidak tersedia. Tidak ada gambar pengganti.',
                          'Local X-ray unavailable. No replacement image.',
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  return Image.memory(
                    image.bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: false,
                    errorBuilder: (_, _, _) => const Center(
                      child: Text(
                        'X-ray tidak dapat ditampilkan.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('${context.trRead("Skor AI", "AI score")}: ${row.aiScore}%'),
          Text(
            'Consolidation: ${row.findings.consolidation} · Cavity: ${row.findings.cavity} · Effusion: ${row.findings.effusion} · Fibrotic: ${row.findings.fibrotic} · Calcification: ${row.findings.calcification}',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<bool>(
            key: ValueKey('doctor-decision-${row.id}'),
            initialValue: _doctorPositive,
            decoration: InputDecoration(
              labelText: context.trRead(
                'Hasil skrining menurut dokter',
                'Doctor screening assessment',
              ),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: true,
                child: Text(context.trRead('Positif', 'Positive')),
              ),
              DropdownMenuItem(
                value: false,
                child: Text(context.trRead('Negatif', 'Negative')),
              ),
            ],
            onChanged: _saving || row.hasConflict || row.isMock
                ? null
                : (value) => setState(() => _doctorPositive = value),
          ),
          const SizedBox(height: 16),
          Text(
            '${context.trRead("Skor validasi dokter (0–10)", "Doctor validation score (0–10)")}: ${_score ?? "—"}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            key: const Key('validation-score-slider'),
            min: 0,
            max: 10,
            divisions: 10,
            value: (_score ?? 5).toDouble(),
            label: _score?.toString(),
            onChanged: _saving || row.hasConflict || row.isMock
                ? null
                : (value) => setState(() => _score = value.round()),
          ),
          Text(
            context.trRead(
              'Pilih skor sebelum konfirmasi. Skor dokter terpisah dari skor AI.',
              'Select a score before confirming. The doctor score is separate from the AI score.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            enabled: !_saving,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: context.trRead(
                _doctorPositive != null && _doctorPositive != row.isPositive
                    ? 'Catatan dokter (wajib jika berbeda dari AI)'
                    : 'Catatan dokter (opsional)',
                'Doctor note (optional)',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('confirm-validation-score'),
            onPressed:
                _score == null ||
                    _doctorPositive == null ||
                    row.isPositive == null ||
                    _saving ||
                    row.hasConflict ||
                    row.isMock
                ? null
                : _confirm,
            child: Text(
              _saving
                  ? context.trRead('Menyimpan…', 'Saving…')
                  : context.trRead(
                      'Konfirmasi & simpan offline',
                      'Confirm & save offline',
                    ),
            ),
          ),
          if (row.validationScore != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                context.trRead(
                  'Validasi tersimpan lokal dan menunggu sync teknisi. Skor dikirim setelah API mendukung kontrak terbaru.',
                  'Validation saved locally, awaiting technician sync. Score uploads require the updated API contract.',
                ),
              ),
            ),
          if (row.hasConflict)
            Text(
              context.trRead(
                'Ada konflik data. Validasi baru ditahan sampai konflik diselesaikan.',
                'Data conflict. New validation is held until it is resolved.',
              ),
            ),
        ],
      ],
    );
  }
}
