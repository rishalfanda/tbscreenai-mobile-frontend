import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/theme/app_theme.dart';
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
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
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

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
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
          result = a.diagnosisDate.compareTo(b.diagnosisDate);
        case 'highest':
          result = b.aiScore.compareTo(a.aiScore);
        case 'lowest':
          result = a.aiScore.compareTo(b.aiScore);
        case 'latest':
          result = b.diagnosisDate.compareTo(a.diagnosisDate);
        default:
          result = (a.status == 'pending' ? 0 : 1).compareTo(
            b.status == 'pending' ? 0 : 1,
          );
          if (result == 0) result = b.diagnosisDate.compareTo(a.diagnosisDate);
      }
      return result == 0 ? a.id.compareTo(b.id) : result;
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final rows = _visible;
    return Padding(
      padding: const EdgeInsets.all(16),
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
                : LayoutBuilder(
                    builder: (context, constraints) => Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: SingleChildScrollView(
                            controller: _verticalScrollController,
                            child: DataTable(
                              showCheckboxColumn: false,
                              headingRowColor: WidgetStatePropertyAll(
                                Theme.of(context).colorScheme.primaryContainer,
                              ),
                              headingTextStyle: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                              dataTextStyle: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppTheme.textPrimary),
                              dataRowMinHeight: 64,
                              dataRowMaxHeight: 84,
                              horizontalMargin: 8,
                              columnSpacing: 8,
                              columns: [
                                _buildColumn(
                                  context.trRead('Nama pasien', 'Patient name'),
                                  maxWidth: 100,
                                ),
                                _buildColumn(
                                  context.trRead(
                                    'Tanggal screening',
                                    'Screening date',
                                  ),
                                  maxWidth: 80,
                                ),
                                _buildColumn(
                                  'AI Screening Result',
                                  maxWidth: 96,
                                ),
                                _buildColumn(
                                  'Validation screening',
                                  maxWidth: 90,
                                ),
                                _buildColumn(
                                  context.trRead(
                                    'Rating lesi (0-10)',
                                    'Lesion rating (0-10)',
                                  ),
                                  maxWidth: 90,
                                ),
                                _buildColumn('Doctor notes', maxWidth: 85),
                                _buildColumn(context.trRead('Aksi', 'Actions')),
                              ],
                              rows: [
                                for (final row in rows)
                                  DataRow(
                                    key: ValueKey('validation-case-${row.id}'),
                                    onSelectChanged: (_) => _open(
                                      row,
                                      readOnly: row.hasConflict || row.isMock,
                                    ),
                                    cells: [
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 100,
                                          ),
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
                                      DataCell(Text(row.diagnosisDate)),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 96,
                                          ),
                                          child: Text(
                                            '${row.isPositive == null
                                                ? "-"
                                                : row.isPositive!
                                                ? context.trRead("Positif", "Positive")
                                                : context.trRead("Negatif", "Negative")} / ${row.aiScore}%',
                                            maxLines: 2,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        _buildValidationStatusChip(row.status),
                                      ),
                                      DataCell(
                                        Text(
                                          row.lesionRating == null
                                              ? '-'
                                              : '${row.lesionRating}/10',
                                        ),
                                      ),
                                      DataCell(
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 90,
                                          ),
                                          child: Text(
                                            row.validationNote ??
                                                row.doctorNote ??
                                                '-',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      DataCell(_buildActionsCell(context, row)),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildColumn(String label, {double? maxWidth}) {
    final text = Text(label, softWrap: true, maxLines: 2);
    return DataColumn(
      label: maxWidth == null
          ? text
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: text,
            ),
    );
  }

  Widget _buildValidationStatusChip(String status) {
    final (String label, Color fg, Color bg, Color border) = switch (status) {
      'agreed' => (
        'Agree',
        AppTheme.successDark,
        AppTheme.success.withValues(alpha: 0.14),
        AppTheme.success.withValues(alpha: 0.45),
      ),
      'disagreed' => (
        'Disagree',
        AppTheme.errorDark,
        AppTheme.error.withValues(alpha: 0.14),
        AppTheme.error.withValues(alpha: 0.45),
      ),
      _ => (
        'Unvalidated',
        const Color(0xFF92400E),
        AppTheme.warning.withValues(alpha: 0.18),
        AppTheme.warning.withValues(alpha: 0.50),
      ),
    };
    return Chip(
      backgroundColor: bg,
      side: BorderSide(color: border),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: TextStyle(
        color: fg,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      label: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _buildActionsCell(BuildContext context, ValidationCase row) {
    final canOpenForm = !row.hasConflict && !row.isMock;
    final canDelete =
        !_deleting &&
        !row.hasConflict &&
        !row.isMock &&
        context.read<ValidationRepository>() is ValidationResetRepository;
    final compactIconStyle = IconButton.styleFrom(
      minimumSize: const Size(34, 34),
      padding: const EdgeInsets.all(2),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (row.status == 'pending')
          FilledButton.icon(
            key: ValueKey('validate-${row.id}'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: canOpenForm ? () => _open(row) : null,
            icon: const Icon(Icons.fact_check_outlined, size: 15),
            label: Text(context.trRead('Validasi', 'Validate')),
          )
        else
          OutlinedButton.icon(
            key: ValueKey('edit-${row.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.navy,
              side: BorderSide(
                color: canOpenForm ? AppTheme.navy : Colors.grey.shade400,
              ),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: canOpenForm ? () => _open(row) : null,
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: Text(context.trRead('Edit', 'Edit')),
          ),
        const SizedBox(width: 2),
        IconButton(
          key: ValueKey('view-${row.id}'),
          style: compactIconStyle,
          tooltip: context.trRead('Lihat', 'View'),
          visualDensity: VisualDensity.compact,
          onPressed: () => _open(row, readOnly: true),
          icon: const Icon(Icons.visibility_outlined, size: 19),
        ),
        IconButton(
          key: ValueKey('delete-${row.id}'),
          style: compactIconStyle,
          tooltip: context.trRead('Hapus', 'Delete'),
          visualDensity: VisualDensity.compact,
          onPressed: canDelete ? () => _deleteValidation(row) : null,
          icon: const Icon(Icons.delete_outline, size: 19),
        ),
      ],
    );
  }
}
