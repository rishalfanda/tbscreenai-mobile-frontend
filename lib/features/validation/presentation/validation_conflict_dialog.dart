import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/domain/models/clinical_conflict.dart';
import 'package:myapp/domain/repositories/validation_conflict_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';

class ValidationConflictDialog extends StatefulWidget {
  const ValidationConflictDialog({super.key, required this.conflict});

  final ClinicalConflict conflict;

  @override
  State<ValidationConflictDialog> createState() =>
      _ValidationConflictDialogState();
}

class _ValidationConflictDialogState extends State<ValidationConflictDialog> {
  late String _status =
      const {'agreed', 'disagreed'}.contains(widget.conflict.localStatus)
      ? widget.conflict.localStatus
      : 'agreed';
  int? _rating;
  late final TextEditingController _note = TextEditingController(
    text: widget.conflict.localNote,
  );
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rating = widget.conflict.localLesionRating;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _resolve(ConflictDecision decision) async {
    if (_saving ||
        decision != ConflictDecision.cancel &&
            !widget.conflict.hasServerSnapshot) {
      setState(
        () => _error = context.trRead(
          'Sambungkan perangkat dan muat ulang agar versi server dapat diperiksa.',
          'Reconnect and reload so the current server version can be checked.',
        ),
      );
      return;
    }
    if (decision == ConflictDecision.reapplyLocal &&
        !widget.conflict.isDelete &&
        _rating == null) {
      setState(
        () => _error = context.trRead(
          'Pilih rating lesi 0-10. Rating tidak diambil dari skor validasi lama.',
          'Choose a 0-10 lesion rating. It is not inferred from the old validation score.',
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = context.read<ValidationRepository>();
      if (repository is! NumericValidationConflictRepository) {
        throw UnsupportedError('Conflict recovery is unavailable.');
      }
      await (repository as NumericValidationConflictRepository)
          .resolveNumericConflict(
            conflict: widget.conflict,
            decision: decision,
            status: widget.conflict.isDelete ? null : _status,
            lesionRating: widget.conflict.isDelete ? null : _rating,
            note: widget.conflict.isDelete ? null : _note.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflict = widget.conflict;
    return AlertDialog(
      title: Text(
        context.trRead(
          'Selesaikan konflik validasi',
          'Resolve validation conflict',
        ),
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conflict.hasServerSnapshot
                    ? context.trRead(
                        'Data server versi ${conflict.serverVersion} sudah diperiksa. Pilih nilai server atau kirim keputusan dokter sebagai operasi baru.',
                        'Server version ${conflict.serverVersion} was checked. Keep it or submit the clinician decision as a new operation.',
                      )
                    : context.trRead(
                        'Snapshot server belum tersedia. Konflik tetap disimpan; sambungkan perangkat lalu muat ulang.',
                        'The server snapshot is unavailable. The conflict is retained; reconnect and reload.',
                      ),
              ),
              if (conflict.serverDeleted) ...[
                const SizedBox(height: 8),
                Text(
                  context.trRead(
                    'Validasi ini sudah dihapus di server.',
                    'This validation was deleted on the server.',
                  ),
                ),
              ],
              if (!conflict.isDelete) ...[
                const SizedBox(height: 16),
                Text(context.trRead('Keputusan dokter', 'Clinician decision')),
                RadioGroup<String>(
                  groupValue: _status,
                  onChanged: (value) {
                    if (!_saving && value != null) {
                      setState(() => _status = value);
                    }
                  },
                  child: Row(
                    children: const [
                      Expanded(
                        child: RadioListTile(
                          value: 'agreed',
                          title: Text('Agree'),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile(
                          value: 'disagreed',
                          title: Text('Disagree'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.trRead('Rating lesi (0-10)', 'Lesion rating (0-10)'),
                ),
                RadioGroup<int>(
                  groupValue: _rating,
                  onChanged: (value) {
                    if (!_saving) setState(() => _rating = value);
                  },
                  child: Wrap(
                    spacing: 4,
                    children: [
                      for (var value = 0; value <= 10; value++)
                        SizedBox(
                          width: 50,
                          child: RadioListTile<int>(
                            value: value,
                            title: Text('$value'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ),
                TextField(
                  controller: _note,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.trRead(
                      'Catatan dokter (opsional)',
                      'Doctor note (optional)',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.trRead('Nanti', 'Later')),
        ),
        OutlinedButton(
          onPressed: _saving || !conflict.hasServerSnapshot
              ? null
              : () => _resolve(ConflictDecision.keepServer),
          child: Text(context.trRead('Pakai data server', 'Keep server data')),
        ),
        FilledButton(
          onPressed: _saving || !conflict.hasServerSnapshot
              ? null
              : () => _resolve(ConflictDecision.reapplyLocal),
          child: Text(
            conflict.isDelete
                ? context.trRead('Kirim ulang penghapusan', 'Retry deletion')
                : context.trRead(
                    'Kirim keputusan dokter',
                    'Submit clinician decision',
                  ),
          ),
        ),
      ],
    );
  }
}
