import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/connectivity/connectivity_service.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/offline/offline_sync_repository.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/available_model_bundle.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.sp24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Section: Header ===
          Row(
            children: [
              Text(
                'Sync Center',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const Spacer(),
              const _ConnectionChip(),
            ],
          ),
          const SizedBox(height: AppTheme.sp16),
          // === Section: TabBar ===
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.memory_rounded),
                  text: 'Model AI',
                ),
                Tab(
                  icon: Icon(Icons.cloud_upload_rounded),
                  text: 'Data Medis',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.sp16),
          // === Section: Tab Views ===
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _ModelSyncTab(),
                _DataSyncTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === Section: Connection Chip ===

class _ConnectionChip extends StatefulWidget {
  const _ConnectionChip();

  @override
  State<_ConnectionChip> createState() => _ConnectionChipState();
}

class _ConnectionChipState extends State<_ConnectionChip> {
  final _connectivity = ConnectivityService();
  bool _isOnline = true;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _connectivity.checkNow().then((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
    _sub = _connectivity.onStatusChange.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _isOnline;
    return Chip(
      avatar: Icon(
        isOnline ? Icons.circle : Icons.wifi_off_rounded,
        size: 10,
        color: isOnline ? AppTheme.success : AppTheme.textSecondary,
      ),
      label: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOnline ? AppTheme.success : AppTheme.textSecondary,
        ),
      ),
      backgroundColor: isOnline
          ? AppTheme.success.withValues(alpha: 0.1)
          : AppTheme.textSecondary.withValues(alpha: 0.1),
      side: BorderSide(
        color: isOnline ? AppTheme.success : AppTheme.textSecondary,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

// === Section: Tab 1 - Model AI Sync & Management ===

class _ModelSyncTab extends StatefulWidget {
  const _ModelSyncTab();

  @override
  State<_ModelSyncTab> createState() => _ModelSyncTabState();
}

class _ModelSyncTabState extends State<_ModelSyncTab> {
  List<AvailableModelBundle> _models = const [];
  Set<String> _installedKeys = const {};
  String? _activeVersion;
  bool _loading = false;
  String? _errorMessage;

  String _channelFilter = 'all'; // 'all', 'stable', 'beta'
  bool? _quantizedFilter; // null: all, true: quantized, false: unquantized

  String? _downloadingModelId;
  double _downloadProgress = 0.0;
  StreamSubscription<double>? _downloadSub;

  final _connectivity = ConnectivityService();
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _connectivity.checkNow().then((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
    _connectivitySub = _connectivity.onStatusChange.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
    _loadData();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final repository = context.read<SyncRepository>();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final active = await repository.getInstalledModelVersion();
      final installed = await repository.getInstalledModelKeys();
      final models = await repository.getAvailableModels(
        channel: _channelFilter == 'all' ? null : _channelFilter,
        quantized: _quantizedFilter,
      );

      if (!mounted) return;
      setState(() {
        _activeVersion = active;
        _installedKeys = installed.toSet();
        _models = models;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat katalog model: $e';
      });
    }
  }

  void _startDownload(AvailableModelBundle model) {
    if (_downloadingModelId != null) return;
    final repository = context.read<SyncRepository>();

    setState(() {
      _downloadingModelId = model.id;
      _downloadProgress = 0.0;
    });

    _downloadSub = repository.downloadModelBundle(model).listen(
      (progress) {
        if (!mounted) return;
        setState(() => _downloadProgress = progress);
      },
      onDone: () async {
        if (!mounted) return;
        final newActive = await repository.getInstalledModelVersion();
        final newInstalled = await repository.getInstalledModelKeys();
        setState(() {
          _downloadingModelId = null;
          _activeVersion = newActive;
          _installedKeys = newInstalled.toSet();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Model ${model.version} (${model.channel.toUpperCase()}) berhasil diunduh dan diaktifkan.',
              ),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _downloadingModelId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunduh model: $error'),
            backgroundColor: AppTheme.error,
          ),
        );
      },
    );
  }

  Future<void> _activateModel(AvailableModelBundle model) async {
    final repository = context.read<SyncRepository>();
    try {
      await repository.activateModelBundle(model.id);
      final newActive = await repository.getInstalledModelVersion();
      if (!mounted) return;
      setState(() => _activeVersion = newActive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Model ${model.version} (${model.channel.toUpperCase()}) sekarang aktif digunakan.',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengaktifkan model: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  bool _isModelActive(AvailableModelBundle model) {
    final active = _activeVersion;
    if (active == null || active.isEmpty) return false;
    final act = active.toLowerCase().trim();
    final modelId = model.id.toLowerCase().trim();
    final modelVer = model.version.toLowerCase().trim();
    return act == modelId || act == modelVer;
  }

  bool _isModelInstalled(AvailableModelBundle model) {
    if (_isModelActive(model)) return true;
    final keys = _installedKeys.map((k) => k.toLowerCase().trim()).toSet();
    return keys.contains(model.id.toLowerCase().trim()) ||
        keys.contains(model.version.toLowerCase().trim());
  }

  @override
  Widget build(BuildContext context) {
    final activeModel = _models.cast<AvailableModelBundle?>().firstWhere(
      (m) => m != null && _isModelActive(m),
      orElse: () => null,
    );

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. Active Model Card Banner
          _buildActiveModelBanner(activeModel),
          const SizedBox(height: AppTheme.sp16),
          // B. Toolbar & Filters
          _buildToolbar(),
          const SizedBox(height: AppTheme.sp16),
          // C. Available Models List
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Memeriksa server...'),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null && _models.isEmpty)
            _buildErrorState()
          else
            _buildModelList(),
        ],
      ),
    );
  }

  Widget _buildActiveModelBanner(AvailableModelBundle? activeModel) {
    final hasActive = _activeVersion != null && _activeVersion!.isNotEmpty;
    final versionDisplay = activeModel != null
        ? 'v${activeModel.version} (${activeModel.channel.toUpperCase()})'
        : hasActive
            ? 'v$_activeVersion'
            : 'Belum Ada Model Aktif';

    final detailsDisplay = activeModel != null
        ? '${activeModel.quantized ? "Kuantisasi INT8/FP16" : "Full Precision FP32"} • ${activeModel.formattedSize} • Skema v${activeModel.schemaVersion}'
        : hasActive
            ? 'Model terpasang di perangkat'
            : 'Unduh salah satu model di bawah untuk mengaktifkan analisis TB.';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(
          color: hasActive
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.borderLight,
        ),
      ),
      color: hasActive
          ? AppTheme.primary.withValues(alpha: 0.05)
          : Colors.grey.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasActive
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasActive
                    ? Icons.verified_user_rounded
                    : Icons.help_outline_rounded,
                color: hasActive ? AppTheme.primary : AppTheme.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(width: AppTheme.sp16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Model AI Aktif',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hasActive
                              ? AppTheme.primaryDark
                              : AppTheme.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (hasActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SIAP INFERENSI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    versionDisplay,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailsDisplay,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.sp16,
          vertical: AppTheme.sp12,
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Channel filter
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Saluran: ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    _filterChip('Semua', _channelFilter == 'all', () {
                      setState(() => _channelFilter = 'all');
                      _loadData();
                    }),
                    _filterChip('Stable', _channelFilter == 'stable', () {
                      setState(() => _channelFilter = 'stable');
                      _loadData();
                    }),
                    _filterChip('Beta', _channelFilter == 'beta', () {
                      setState(() => _channelFilter = 'beta');
                      _loadData();
                    }),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Quantization filter
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kuantisasi: ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    _filterChip('Semua', _quantizedFilter == null, () {
                      setState(() => _quantizedFilter = null);
                      _loadData();
                    }),
                    _filterChip('Quantized', _quantizedFilter == true, () {
                      setState(() => _quantizedFilter = true);
                      _loadData();
                    }),
                    _filterChip('Full FP32', _quantizedFilter == false, () {
                      setState(() => _quantizedFilter = false);
                      _loadData();
                    }),
                  ],
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _isOnline ? _loadData : null,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Periksa Pembaruan Model'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.navy,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Gagal memuat katalog model.',
              style: const TextStyle(color: AppTheme.error),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelList() {
    if (_models.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.sp24),
          child: Center(
            child: Text(
              _isOnline
                  ? 'Tidak ada model yang sesuai dengan filter.'
                  : 'Mode offline: tidak ada model tersimpan.',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Katalog Model Tersedia (${_models.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _models.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final model = _models[index];
            return _buildModelCard(model);
          },
        ),
      ],
    );
  }

  Widget _buildModelCard(AvailableModelBundle model) {
    final isActive = _isModelActive(model);
    final isInstalled = _isModelInstalled(model);
    final isDownloading = _downloadingModelId == model.id;

    final channelColor = model.channel.toLowerCase() == 'stable'
        ? AppTheme.primary
        : AppTheme.warning;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(
          color: isActive
              ? AppTheme.success.withValues(alpha: 0.6)
              : AppTheme.borderLight,
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Header + Badges + Action Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'v${model.version}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                      ),
                      // Channel Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: channelColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: channelColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          model.channel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: channelColor,
                          ),
                        ),
                      ),
                      // Quantization Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.purple.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          model.quantized ? 'INT8 / FP16' : 'FULL FP32',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                      if (model.isLatest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'TERBARU',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Action Buttons
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.success),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppTheme.success,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Sedang Digunakan',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isInstalled)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Tersimpan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _activateModel(model),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text('Gunakan Model'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: _isOnline && _downloadingModelId == null
                        ? () => _startDownload(model)
                        : null,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Unduh Model'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Row 2: Metadata (Size, Date, Notes)
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _metaText(Icons.sd_storage_outlined, 'Ukuran', model.formattedSize),
                _metaText(
                  Icons.calendar_today_outlined,
                  'Rilis',
                  model.formattedDate,
                ),
                if (model.notes != null && model.notes!.isNotEmpty)
                  _metaText(Icons.notes_rounded, 'Catatan', model.notes!),
              ],
            ),
            // Changelog
            if (model.changelog.isNotEmpty) ...[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  dense: true,
                  title: const Text(
                    'Lihat Catatan Perubahan (Changelog)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  children: [
                    for (final item in model.changelog)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(' • ', style: TextStyle(fontWeight: FontWeight.w800)),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.navy,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            // In-flight progress
            if (isDownloading) ...[
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _downloadProgress >= 1.0
                            ? 'Memverifikasi & menguji model...'
                            : 'Mengunduh bundle... ${(_downloadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _downloadProgress >= 1.0 ? null : _downloadProgress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _downloadProgress >= 1.0 ? null : _downloadProgress,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaText(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.navy,
          ),
        ),
      ],
    );
  }
}

// === Section: Tab 2 - Data Medis Sync & Backup ===

class _DataSyncTab extends StatelessWidget {
  const _DataSyncTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: ClampingScrollPhysics(),
      child: _DataBackupCard(),
    );
  }
}

enum _DataSyncState { idle, selection, uploading, done, error }

class _DataBackupCard extends StatefulWidget {
  const _DataBackupCard();

  @override
  State<_DataBackupCard> createState() => _DataBackupCardState();
}

class _DataBackupCardState extends State<_DataBackupCard> {
  _DataSyncState _state = _DataSyncState.idle;
  final Set<String> _selectedIds = {};
  int _uploadedCount = 0;
  DateTime? _lastSyncDate;
  SyncSummary? _summary;
  List<Patient> _backupCandidates = const [];
  SyncReport? _report;
  StreamSubscription<int>? _uploadSub;

  @override
  void initState() {
    super.initState();
    final repository = context.read<SyncRepository>();
    repository.getSyncSummary().then((summary) {
      if (!mounted) return;
      setState(() => _summary = summary);
    });
    repository.getBackupCandidates().then((patients) {
      if (!mounted) return;
      setState(() => _backupCandidates = patients);
    });
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    super.dispose();
  }

  Future<void> _showConsentDialog() async {
    bool consentChecked = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Konfirmasi Pengiriman Data'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data pasien akan dikirimkan ke server menggunakan enkripsi end-to-end. '
                    'Pastikan Anda memiliki wewenang untuk mengirim data medis ini.',
                  ),
                  const SizedBox(height: AppTheme.sp16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consentChecked,
                    onChanged: (v) =>
                        setDialogState(() => consentChecked = v ?? false),
                    title: const Text(
                      'Saya menyetujui pengiriman data medis ini ke server',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: consentChecked
                      ? () => Navigator.pop(ctx, true)
                      : null,
                  child: const Text('Lanjutkan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (confirmed == true) {
      setState(() {
        _state = _DataSyncState.selection;
        _selectedIds.clear();
      });
    }
  }

  void _startUpload() {
    final repository = context.read<SyncRepository>();
    setState(() {
      _state = _DataSyncState.uploading;
      _uploadedCount = 0;
    });
    _uploadSub = repository
        .uploadPatients(_selectedIds.toList())
        .listen(
          (count) {
            if (!mounted) return;
            setState(() => _uploadedCount = count);
          },
          onDone: () {
            if (!mounted) return;
            final report = repository is OfflineSyncRepository
                ? repository.lastReport
                : null;
            setState(() {
              _state = _DataSyncState.done;
              _report = report;
              _lastSyncDate = DateTime.now();
            });
          },
        );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Belum pernah disinkronkan';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cadangan Data Medis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: AppTheme.sp16),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _DataSyncState.idle:
        return _buildIdle(context);
      case _DataSyncState.selection:
        return _buildSelection(context);
      case _DataSyncState.uploading:
        return _buildUploading();
      case _DataSyncState.done:
        return _buildDone(context);
      case _DataSyncState.error:
        return _buildError(context);
    }
  }

  Widget _buildIdle(BuildContext context) {
    final summary =
        _summary ??
        const SyncSummary(totalPatients: 0, totalDiagnoses: 0, totalSizeMB: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: AppTheme.error,
          ),
          label: const Text(
            'Data Medis Sensitif',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.error,
            ),
          ),
          backgroundColor: AppTheme.error.withValues(alpha: 0.08),
          side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: AppTheme.sp12),
        Text(
          '${summary.totalPatients} Pasien · ${summary.totalDiagnoses} Screening · ~${summary.totalSizeMB} MB',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.sp4),
        Text(
          _formatDate(_lastSyncDate),
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.sp16),
        ElevatedButton.icon(
          onPressed: _showConsentDialog,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text('Pilih Data & Unggah'),
        ),
      ],
    );
  }

  Widget _buildSelection(BuildContext context) {
    final patients = _backupCandidates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Pasien untuk Dicadangkan',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: AppTheme.sp8),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(
                () => _selectedIds.addAll(patients.map((p) => p.id)),
              ),
              child: const Text('Pilih Semua'),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedIds.clear()),
              child: const Text('Batal Pilih'),
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: patients.length,
          itemBuilder: (_, i) {
            final p = patients[i];
            final initials = p.name.split(' ').take(2).map((w) => w[0]).join();
            return CheckboxListTile(
              value: _selectedIds.contains(p.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selectedIds.add(p.id);
                } else {
                  _selectedIds.remove(p.id);
                }
              }),
              secondary: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              title: Text(
                p.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Kunjungan terakhir: ${p.lastVisit}',
                style: const TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.trailing,
            );
          },
        ),
        const SizedBox(height: AppTheme.sp16),
        Row(
          children: [
            Text(
              '${_selectedIds.length} pasien dipilih',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _selectedIds.isEmpty ? null : _startUpload,
              child: const Text('Mulai Unggah'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploading() {
    final total = _selectedIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mengunggah data pasien...',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.sp12),
        LinearProgressIndicator(
          value: total > 0 ? _uploadedCount / total : null,
        ),
        const SizedBox(height: AppTheme.sp8),
        Text(
          'Mengunggah $_uploadedCount/$total pasien...',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final report = _report;
    final hasProblems = report?.hasProblems ?? false;
    final succeeded = report != null
        ? report.applied + report.skipped
        : _uploadedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasProblems
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: hasProblems ? AppTheme.warning : AppTheme.success,
              size: 28,
            ),
            const SizedBox(width: AppTheme.sp8),
            Text(
              hasProblems
                  ? 'Sinkronisasi selesai sebagian'
                  : 'Sinkronisasi selesai',
              style: TextStyle(
                color: hasProblems ? AppTheme.warning : AppTheme.success,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        Text(
          '$succeeded pasien berhasil diunggah',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        if (report != null && report.conflicts > 0) ...[
          const SizedBox(height: AppTheme.sp12),
          Container(
            padding: const EdgeInsets.all(AppTheme.sp12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.merge_type_rounded,
                  color: AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.sp8),
                Expanded(
                  child: Text(
                    '${report.conflicts} data konflik — versi di server lebih baru. '
                    'Data TIDAK ditimpa; perlu ditinjau manual oleh dokter.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.navy),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (report != null && report.failed > 0) ...[
          const SizedBox(height: AppTheme.sp8),
          Text(
            '${report.failed} gagal terkirim — tetap tersimpan di antrean, '
            'akan dicoba lagi saat sinkronisasi berikutnya.',
            style: const TextStyle(fontSize: 13, color: AppTheme.error),
          ),
        ],
        const SizedBox(height: AppTheme.sp16),
        TextButton(
          onPressed: () => setState(() {
            _state = _DataSyncState.idle;
            _selectedIds.clear();
            _uploadedCount = 0;
            _report = null;
          }),
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.error_rounded, color: AppTheme.error, size: 28),
            SizedBox(width: AppTheme.sp8),
            Text(
              'Tidak ada koneksi internet. Hubungkan perangkat dan coba lagi.',
              style: TextStyle(color: AppTheme.error),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp12),
        TextButton(
          onPressed: () => setState(() => _state = _DataSyncState.idle),
          child: const Text('Coba Lagi'),
        ),
      ],
    );
  }
}
