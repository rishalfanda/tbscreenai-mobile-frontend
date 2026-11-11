import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/state/auth_provider.dart';
import 'validation_review_dialog.dart';

class OfflineValidationScreen extends StatefulWidget {
  const OfflineValidationScreen({super.key, this.caseId});
  final String? caseId;
  @override
  State<OfflineValidationScreen> createState() =>
      _OfflineValidationScreenState();
}

class _OfflineValidationScreenState extends State<OfflineValidationScreen> {
  List<ValidationCase> _cases = [];
  String _search = '', _status = 'all', _sort = 'pending';
  bool _loading = true;
  String? _error;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load(openRequested: true));
  }

  Future<void> _load({bool openRequested = false}) async {
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    try {
      final rows = await context.read<ValidationRepository>().getCases();
      if (!mounted || profile != auth.profile || !auth.isLoggedIn) return;
      setState(() {
        _cases = rows;
        _loading = false;
        _error = null;
      });
      if (openRequested && widget.caseId != null) {
        final requested = rows
            .where((row) => row.id == widget.caseId)
            .firstOrNull;
        if (requested != null) {
          await _open(requested);
        } else {
          setState(
            () => _error = context.trRead(
              'Screening tidak tersedia di perangkat ini.',
              'Screening unavailable on this device.',
            ),
          );
        }
      }
    } catch (_) {
      if (mounted && profile == auth.profile) {
        setState(() {
          _loading = false;
          _error = context.trRead(
            'Data validasi tidak dapat dibaca.',
            'Unable to load validation data.',
          );
        });
      }
    }
  }

  Future<void> _open(ValidationCase row, {bool readOnly = false}) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValidationReviewDialog(row: row, readOnly: readOnly),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _deleteValidation(ValidationCase row) async {
    if (_deleting) return;
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          context.trRead('Hapus validasi dokter?', 'Delete doctor validation?'),
        ),
        content: Text(
          context.trRead(
            'Validasi akan dihapus dari daftar; riwayatnya tetap disimpan untuk audit. Screening dan X-ray tetap tersimpan. Barisnya akan hilang dari daftar Validasi.',
            'The validation will leave the list; its history is retained for audit. The screening and X-ray are retained. The row will be removed from the Validation list.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.trRead('Batal', 'Cancel')),
          ),
          FilledButton(
            key: const Key('confirm-delete-validation'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.trRead('Hapus validasi', 'Delete validation')),
          ),
        ],
      ),
    );
    if (!mounted ||
        confirmed != true ||
        profile != auth.profile ||
        !auth.isLoggedIn ||
        auth.role != 'doctor') {
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await (context.read<ValidationRepository>() as ValidationResetRepository)
          .resetValidation(row.id);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.trRead(
            'Validasi belum dihapus. Pastikan validasi sebelumnya sudah disinkronkan dan tidak ada konflik data.',
            'Validation was not deleted. Sync the previous validation and resolve any data conflict first.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  int _compareScreeningTime(
    ValidationCase a,
    ValidationCase b, {
    bool newestFirst = true,
  }) {
    final left = a.diagnosedAt ?? DateTime.tryParse(a.diagnosisDate);
    final right = b.diagnosedAt ?? DateTime.tryParse(b.diagnosisDate);
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return newestFirst ? right.compareTo(left) : left.compareTo(right);
  }

  List<ValidationCase> get _visible {
    final rows = _cases
        .where(
          (row) =>
              row.name.toLowerCase().contains(_search.trim().toLowerCase()) &&
              (_status == 'all' || row.status == _status),
        )
        .toList();
    rows.sort((a, b) {
      int result;
      switch (_sort) {
        case 'earliest':
          result = _compareScreeningTime(a, b, newestFirst: false);
        case 'highest':
          result = b.aiScore.compareTo(a.aiScore);
        case 'lowest':
          result = a.aiScore.compareTo(b.aiScore);
        case 'latest':
          result = _compareScreeningTime(a, b);
        default:
          result = (a.status == 'pending' ? 0 : 1).compareTo(
            b.status == 'pending' ? 0 : 1,
          );
          if (result == 0) result = _compareScreeningTime(a, b);
      }
      if (result == 0) result = _compareScreeningTime(a, b);
      return result == 0 ? a.id.compareTo(b.id) : result;
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final rows = _visible;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.trRead('Validasi screening', 'Screening validation'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  key: const Key('validation-search'),
                  decoration: InputDecoration(
                    labelText: context.trRead(
                      'Cari nama pasien',
                      'Search patient name',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('validation-status-filter'),
                  initialValue: _status,
                  decoration: InputDecoration(
                    labelText: context.trRead(
                      'Status validasi',
                      'Validation status',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(context.trRead('Semua', 'All')),
                    ),
                    const DropdownMenuItem(
                      value: 'pending',
                      child: Text('Unvalidated'),
                    ),
                    const DropdownMenuItem(
                      value: 'agreed',
                      child: Text('Agree'),
                    ),
                    const DropdownMenuItem(
                      value: 'disagreed',
                      child: Text('Disagree'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _status = value!),
                ),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: const Key('validation-sort'),
                  initialValue: _sort,
                  decoration: InputDecoration(
                    labelText: context.trRead('Urutkan', 'Sort by'),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text(
                        context.trRead(
                          'Belum divalidasi dulu',
                          'Unvalidated first',
                        ),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'earliest',
                      child: Text('Earliest'),
                    ),
                    const DropdownMenuItem(
                      value: 'latest',
                      child: Text('Latest'),
                    ),
                    DropdownMenuItem(
                      value: 'highest',
                      child: Text(
                        context.trRead('Skor AI tertinggi', 'Highest AI score'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'lowest',
                      child: Text(
                        context.trRead('Skor AI terendah', 'Lowest AI score'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _sort = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Text('${rows.length} ${context.trRead("screening", "screenings")}'),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text(
                      context.trRead(
                        'Tidak ada screening yang sesuai.',
                        'No matching screenings.',
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStatePropertyAll(
                          Theme.of(context).colorScheme.primaryContainer,
                        ),
                        dataRowMinHeight: 64,
                        dataRowMaxHeight: 84,
                        columnSpacing: 24,
                        columns: [
                          for (final label in [
                            context.trRead('Nama pasien', 'Patient name'),
                            context.trRead(
                              'Tanggal & jam screening (lokal)',
                              'Screening date & time (local)',
                            ),
                            'AI Screening Result',
                            'Validation screening',
                            context.trRead(
                              'Rating lesi (0-10)',
                              'Lesion rating (0-10)',
                            ),
                            "Doctor notes",
                            context.trRead('Aksi', 'Actions'),
                          ])
                            DataColumn(label: Text(label)),
                        ],
                        rows: [
                          for (final row in rows)
                            DataRow(
                              key: ValueKey('validation-case-${row.id}'),
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      row.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(row.screeningDateTimeLabel)),
                                DataCell(
                                  Text(
                                    '${row.isPositive == null
                                        ? "-"
                                        : row.isPositive!
                                        ? context.trRead("Positif", "Positive")
                                        : context.trRead("Negatif", "Negative")} / ${row.aiScore}%',
                                  ),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      row.status == 'agreed'
                                          ? 'Agree'
                                          : row.status == 'disagreed'
                                          ? 'Disagree'
                                          : 'Unvalidated',
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    row.lesionRating == null
                                        ? '-'
                                        : '${row.lesionRating}/10',
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 160,
                                    child: Text(
                                      row.validationNote ??
                                          row.doctorNote ??
                                          '-',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        key: ValueKey('validate-${row.id}'),
                                        tooltip: context.trRead(
                                          'Validasi',
                                          'Validate',
                                        ),
                                        onPressed:
                                            row.status == 'pending' &&
                                                !row.hasConflict &&
                                                !row.isMock
                                            ? () => _open(row)
                                            : null,
                                        icon: const Icon(
                                          Icons.fact_check_outlined,
                                        ),
                                      ),
                                      IconButton(
                                        key: ValueKey('view-${row.id}'),
                                        tooltip: context.trRead(
                                          'Lihat',
                                          'View',
                                        ),
                                        onPressed: () =>
                                            _open(row, readOnly: true),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                        ),
                                      ),
                                      IconButton(
                                        key: ValueKey('edit-${row.id}'),
                                        tooltip: context.trRead(
                                          'Edit validasi',
                                          'Edit validation',
                                        ),
                                        onPressed:
                                            row.status != 'pending' &&
                                                !row.hasConflict &&
                                                !row.isMock
                                            ? () => _open(row)
                                            : null,
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        key: ValueKey('delete-${row.id}'),
                                        tooltip: context.trRead(
                                          'Hapus',
                                          'Delete',
                                        ),
                                        onPressed:
                                            !_deleting &&
                                                !row.hasConflict &&
                                                !row.isMock &&
                                                context
                                                        .read<
                                                          ValidationRepository
                                                        >()
                                                    is ValidationResetRepository
                                            ? () => _deleteValidation(row)
                                            : null,
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
