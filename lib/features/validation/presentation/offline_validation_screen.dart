import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/models/clinical_conflict.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/state/auth_provider.dart';
import 'validation_review_dialog.dart';
import 'validation_conflict_dialog.dart';

class OfflineValidationScreen extends StatefulWidget {
  const OfflineValidationScreen({super.key, this.caseId});
  final String? caseId;
  @override
  State<OfflineValidationScreen> createState() =>
      _OfflineValidationScreenState();
}

class _OfflineValidationScreenState extends State<OfflineValidationScreen> {
  static const double _minTableWidth = 898.0;
  static const int _flexName = 110;
  static const int _flexDate = 128;
  static const int _flexAiResult = 104;
  static const int _flexStatus = 106;
  static const int _flexRating = 86;
  static const int _flexNotes = 96;
  static const double _colActionsWidth = 204.0;

  static final ButtonStyle _validateButtonStyle = FilledButton.styleFrom(
    backgroundColor: AppTheme.navy,
    foregroundColor: Colors.white,
    minimumSize: const Size(0, 34),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  static final ButtonStyle _editEnabledButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: AppTheme.navy,
    side: const BorderSide(color: AppTheme.navy),
    minimumSize: const Size(0, 34),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  static final ButtonStyle _editDisabledButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: AppTheme.navy,
    side: BorderSide(color: Colors.grey.shade400),
    minimumSize: const Size(0, 34),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  static final ButtonStyle _compactIconStyle = IconButton.styleFrom(
    minimumSize: const Size(34, 34),
    padding: const EdgeInsets.all(2),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ValueNotifier<List<ValidationCase>> _visibleNotifier =
      ValueNotifier<List<ValidationCase>>(const []);
  List<ValidationCase> _cases = [];
  Map<String, String> _caseNamesById = const {};
  List<ClinicalConflict> _conflicts = [];
  String _search = '', _status = 'all', _sort = 'pending';
  List<ValidationCase>? _cachedSource;
  String? _cachedSearch, _cachedStatus, _cachedSort;
  bool _loading = true;
  String? _error;
  bool _deleting = false;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load(openRequested: true));
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _visibleNotifier.dispose();
    super.dispose();
  }

  Future<void> _load({
    bool openRequested = false,
    bool includeConflicts = true,
  }) async {
    final generation = ++_loadGeneration;
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    try {
      final repository = context.read<ValidationRepository>();
      final Future<List<ClinicalConflict>>? conflictsFuture = includeConflicts
          ? repository.getConflicts()
          : null;
      final rows = await repository.getCases();
      if (!mounted ||
          generation != _loadGeneration ||
          profile != auth.profile ||
          !auth.isLoggedIn) {
        return;
      }
      _cases = rows;
      _caseNamesById = {for (final row in rows) row.id: row.name};
      _syncVisibleCases(force: true);
      setState(() {
        _loading = false;
        _error = null;
      });
      if (conflictsFuture != null) {
        unawaited(() async {
          try {
            final conflicts = await conflictsFuture;
            if (!mounted ||
                generation != _loadGeneration ||
                profile != auth.profile ||
                !auth.isLoggedIn) {
              return;
            }
            setState(() => _conflicts = conflicts);
          } catch (_) {
            // Keep local cases visible even if conflict HTTP hydration fails.
          }
        }());
      }
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
      if (mounted &&
          generation == _loadGeneration &&
          profile == auth.profile) {
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

  Future<void> _openConflict(ClinicalConflict conflict) async {
    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    if (!auth.isLoggedIn || auth.role != 'doctor') return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValidationConflictDialog(conflict: conflict),
    );
    if (changed == true && mounted && profile == auth.profile) await _load();
  }

  Future<void> _open(ValidationCase row, {bool readOnly = false}) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ValidationReviewDialog(row: row, readOnly: readOnly),
    );
    if (changed == true && mounted) {
      await _load(includeConflicts: _conflicts.isNotEmpty || row.hasConflict);
    }
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
      if (mounted) await _load(includeConflicts: _conflicts.isNotEmpty);
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

  void _syncVisibleCases({bool force = false}) {
    final normalizedSearch = _search.trim().toLowerCase();
    if (!force &&
        identical(_cachedSource, _cases) &&
        _cachedSearch == normalizedSearch &&
        _cachedStatus == _status &&
        _cachedSort == _sort) {
      return;
    }
    _cachedSource = _cases;
    _cachedSearch = normalizedSearch;
    _cachedStatus = _status;
    _cachedSort = _sort;

    final rows = _cases
        .where(
          (row) =>
              (normalizedSearch.isEmpty ||
                  row.name.toLowerCase().contains(normalizedSearch)) &&
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
    _visibleNotifier.value = List<ValidationCase>.unmodifiable(rows);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final canDeleteRepo =
        context.read<ValidationRepository>() is ValidationResetRepository;
    final screeningsUnit = context.trRead('screening', 'screenings');
    final noMatchingText = context.trRead(
      'Tidak ada screening yang sesuai.',
      'No matching screenings.',
    );
    final positiveLabel = context.trRead('Positif', 'Positive');
    final negativeLabel = context.trRead('Negatif', 'Negative');
    final validateLabel = context.trRead('Validasi', 'Validate');
    final editLabel = context.trRead('Edit', 'Edit');
    final viewTooltip = context.trRead('Lihat', 'View');
    final deleteTooltip = context.trRead('Hapus', 'Delete');
    final headerLabels = _ValidationHeaderLabels(
      name: context.trRead('Nama pasien', 'Patient name'),
      dateTime: context.trRead(
        'Tanggal & jam screening (lokal)',
        'Screening date & time (local)',
      ),
      aiResult: 'AI Screening Result',
      validationStatus: 'Validation screening',
      lesionRating: context.trRead('Rating lesi (0-10)', 'Lesion rating (0-10)'),
      notes: 'Doctor notes',
      actions: context.trRead('Aksi', 'Actions'),
    );

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
                  onChanged: (value) {
                    _search = value;
                    _syncVisibleCases();
                  },
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
                  onChanged: (value) {
                    _status = value ?? 'all';
                    _syncVisibleCases();
                  },
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
                  onChanged: (value) {
                    _sort = value ?? 'pending';
                    _syncVisibleCases();
                  },
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
          if (_conflicts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.trRead(
                        '${_conflicts.length} konflik validasi perlu keputusan dokter',
                        '${_conflicts.length} validation conflicts need clinician review',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final conflict in _conflicts)
                      ListTile(
                        key: ValueKey(
                          'validation-conflict-${conflict.clientOpId}',
                        ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          conflict.isDelete
                              ? Icons.delete_outline
                              : Icons.sync_problem,
                        ),
                        title: Text(
                          _caseNamesById[conflict.diagnosisId] ??
                              context.trRead(
                                'Screening ${conflict.diagnosisId}',
                                'Screening ${conflict.diagnosisId}',
                              ),
                        ),
                        subtitle: Text(
                          conflict.hasServerSnapshot
                              ? context.trRead(
                                  'Versi server ${conflict.serverVersion} siap diperiksa.',
                                  'Server version ${conflict.serverVersion} is ready for review.',
                                )
                              : context.trRead(
                                  'Offline / snapshot server belum tersedia. Sambungkan lalu muat ulang.',
                                  'Offline / server snapshot unavailable. Reconnect and reload.',
                                ),
                        ),
                        trailing: FilledButton.tonal(
                          key: ValueKey(
                            'resolve-validation-conflict-${conflict.clientOpId}',
                          ),
                          onPressed: () => _openConflict(conflict),
                          child: Text(context.trRead('Selesaikan', 'Resolve')),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: ValueListenableBuilder<List<ValidationCase>>(
              valueListenable: _visibleNotifier,
              builder: (context, rows, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${rows.length} $screeningsUnit'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text(noMatchingText))
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final tableWidth = math.max(
                                _minTableWidth,
                                constraints.maxWidth,
                              );
                              final textScale = MediaQuery.textScalerOf(
                                context,
                              ).scale(14.0);
                              final rowHeight = math.max(
                                72.0,
                                40.0 + textScale * 2.4,
                              );
                              final dataTextStyle = Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppTheme.textPrimary);
                              final dividerColor = Theme.of(
                                context,
                              ).dividerColor;
                              return Scrollbar(
                                controller: _horizontalScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _horizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    height: constraints.maxHeight,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildHeaderRow(context, headerLabels),
                                        Expanded(
                                          child: Scrollbar(
                                            controller:
                                                _verticalScrollController,
                                            child: ListView.builder(
                                              controller:
                                                  _verticalScrollController,
                                              itemExtent: rowHeight,
                                              itemCount: rows.length,
                                              itemBuilder: (context, index) =>
                                                  _buildRowTile(
                                                    rows[index],
                                                    dataTextStyle:
                                                        dataTextStyle,
                                                    dividerColor: dividerColor,
                                                    canDeleteRepo:
                                                        canDeleteRepo,
                                                    positiveLabel:
                                                        positiveLabel,
                                                    negativeLabel:
                                                        negativeLabel,
                                                    validateLabel:
                                                        validateLabel,
                                                    editLabel: editLabel,
                                                    viewTooltip: viewTooltip,
                                                    deleteTooltip:
                                                        deleteTooltip,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    _ValidationHeaderLabels labels,
  ) {
    final theme = Theme.of(context);
    final headerTextStyle = theme.textTheme.titleSmall?.copyWith(
      color: theme.colorScheme.onPrimaryContainer,
      fontWeight: FontWeight.w700,
    );
    return DecoratedBox(
      key: const Key('validation-table-header'),
      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: DefaultTextStyle(
          style: headerTextStyle ?? const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          child: Row(
            children: [
              Expanded(flex: _flexName, child: Text(labels.name)),
              const SizedBox(width: 8),
              Expanded(flex: _flexDate, child: Text(labels.dateTime)),
              const SizedBox(width: 8),
              Expanded(flex: _flexAiResult, child: Text(labels.aiResult)),
              const SizedBox(width: 8),
              Expanded(
                flex: _flexStatus,
                child: Text(labels.validationStatus),
              ),
              const SizedBox(width: 8),
              Expanded(flex: _flexRating, child: Text(labels.lesionRating)),
              const SizedBox(width: 8),
              Expanded(flex: _flexNotes, child: Text(labels.notes)),
              const SizedBox(width: 8),
              SizedBox(width: _colActionsWidth, child: Text(labels.actions)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRowTile(
    ValidationCase row, {
    required TextStyle? dataTextStyle,
    required Color dividerColor,
    required bool canDeleteRepo,
    required String positiveLabel,
    required String negativeLabel,
    required String validateLabel,
    required String editLabel,
    required String viewTooltip,
    required String deleteTooltip,
  }) {
    final aiLabel = row.isPositive == null
        ? '-'
        : row.isPositive!
        ? positiveLabel
        : negativeLabel;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('validation-case-${row.id}'),
        onTap: () => _open(row, readOnly: row.hasConflict || row.isMock),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: dividerColor, width: 0.75)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DefaultTextStyle(
              style: dataTextStyle ?? const TextStyle(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: _flexName,
                    child: Text(
                      row.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: _flexDate,
                    child: Text(
                      row.screeningDateTimeLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: _flexAiResult,
                    child: Text('$aiLabel / ${row.aiScore}%', maxLines: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: _flexStatus,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildValidationStatusPill(row.status),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: _flexRating,
                    child: Text(
                      row.lesionRating == null ? '-' : '${row.lesionRating}/10',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: _flexNotes,
                    child: Text(
                      row.validationNote ?? row.doctorNote ?? '-',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: _colActionsWidth,
                    child: _buildActionsCell(
                      row,
                      canDeleteRepo: canDeleteRepo,
                      validateLabel: validateLabel,
                      editLabel: editLabel,
                      viewTooltip: viewTooltip,
                      deleteTooltip: deleteTooltip,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValidationStatusPill(String status) {
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActionsCell(
    ValidationCase row, {
    required bool canDeleteRepo,
    required String validateLabel,
    required String editLabel,
    required String viewTooltip,
    required String deleteTooltip,
  }) {
    final canOpenForm = !row.hasConflict && !row.isMock;
    final canDelete =
        !_deleting && !row.hasConflict && !row.isMock && canDeleteRepo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (row.status == 'pending')
          FilledButton.icon(
            key: ValueKey('validate-${row.id}'),
            style: _validateButtonStyle,
            onPressed: canOpenForm ? () => _open(row) : null,
            icon: const Icon(Icons.fact_check_outlined, size: 15),
            label: Text(validateLabel),
          )
        else
          OutlinedButton.icon(
            key: ValueKey('edit-${row.id}'),
            style: canOpenForm
                ? _editEnabledButtonStyle
                : _editDisabledButtonStyle,
            onPressed: canOpenForm ? () => _open(row) : null,
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: Text(editLabel),
          ),
        const SizedBox(width: 2),
        IconButton(
          key: ValueKey('view-${row.id}'),
          style: _compactIconStyle,
          tooltip: viewTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: () => _open(row, readOnly: true),
          icon: const Icon(Icons.visibility_outlined, size: 19),
        ),
        IconButton(
          key: ValueKey('delete-${row.id}'),
          style: _compactIconStyle,
          tooltip: deleteTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: canDelete ? () => _deleteValidation(row) : null,
          icon: const Icon(Icons.delete_outline, size: 19),
        ),
      ],
    );
  }
}

class _ValidationHeaderLabels {
  const _ValidationHeaderLabels({
    required this.name,
    required this.dateTime,
    required this.aiResult,
    required this.validationStatus,
    required this.lesionRating,
    required this.notes,
    required this.actions,
  });

  final String name;
  final String dateTime;
  final String aiResult;
  final String validationStatus;
  final String lesionRating;
  final String notes;
  final String actions;
}
