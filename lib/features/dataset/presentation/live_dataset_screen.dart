import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/localization/app_text.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/dataset_page.dart';
import 'package:myapp/domain/repositories/dataset_repository.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/live_dataset_provider.dart';
import 'dataset_write_actions.dart';

class LiveDatasetScreen extends StatelessWidget {
  const LiveDatasetScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repository = context.read<DatasetRepository>();
    if (repository is! DatasetReadRepository) {
      return const Center(child: AppText('Dataset belum tersedia.'));
    }
    return ChangeNotifierProvider(
      create: (_) => LiveDatasetProvider(
        repository as DatasetReadRepository,
        context.read<AuthProvider>(),
      ),
      child: const _DatasetBody(),
    );
  }
}

class _DatasetBody extends StatefulWidget {
  const _DatasetBody();
  @override
  State<_DatasetBody> createState() => _DatasetBodyState();
}

class _DatasetBodyState extends State<_DatasetBody> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LiveDatasetProvider>();
    final detail = state.selectedId != null;
    final entry = state.selected;
    return ListView(
      key: const Key('live-dataset-content'),
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 16 : 28),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 8,
          children: [
            AppText(
              detail ? 'Dataset Details' : 'Datasets',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (detail)
              OutlinedButton.icon(
                onPressed: () => state.loadList(),
                icon: const Icon(Icons.arrow_back),
                label: const AppText('Back to Datasets'),
              ),
            IconButton(
              tooltip: context.tr('Muat ulang dataset', 'Refresh datasets'),
              onPressed: state.busy ? null : state.refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const AppText('Data mengikuti instansi akun yang sedang login.'),
        const DatasetWriteActions(),
        const SizedBox(height: 20),
        if (!detail)
          TextField(
            controller: _search,
            maxLength: 120,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => state.loadList(search: value.trim()),
            decoration: InputDecoration(
              labelText: context.tr('Cari dataset', 'Search datasets'),
              suffixIcon: IconButton(
                tooltip: context.tr('Cari', 'Search'),
                icon: const Icon(Icons.search),
                onPressed: state.busy
                    ? null
                    : () => state.loadList(search: _search.text.trim()),
              ),
            ),
          ),
        if (state.busy)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.error != null) ...[
          AppText(state.error!),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: state.refresh,
              child: const AppText('Coba Lagi'),
            ),
          ),
        ] else if (detail && entry != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (entry.description?.isNotEmpty == true)
                    Text(entry.description!),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      AppText(entry.status == 'active' ? 'Active' : 'Archived'),
                      Text(
                        '${entry.itemCount} screening · ${_size(entry.sizeBytes)}',
                      ),
                      Text(
                        entry.lastUpdated.toLocal().toIso8601String().substring(
                          0,
                          10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const AppText('Screenings in this dataset'),
          if (state.screenings!.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: AppText('Dataset ini belum memiliki hasil screening.'),
            ),
          for (final item in state.screenings!.items)
            Card(
              child: ListTile(
                title: Text(item.patientCode),
                trailing: RemoveDatasetItem(id: item.diagnosisId),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(item.isPositive ? 'AI Positive' : 'AI Negative'),
                    Text(
                      '${item.confidence}% · ${item.diagnosedAt.toLocal().toIso8601String().substring(0, 10)}',
                    ),
                    Text(item.modelVersion),
                    AppText(switch (item.status) {
                      'agreed' => 'Agreed',
                      'disagreed' => 'Disagreed',
                      _ => 'Pending',
                    }),
                  ],
                ),
              ),
            ),
          _pages(
            state.screenings!,
            (offset) => state.open(entry.id, offset: offset),
          ),
        ] else if (!detail && state.page != null) ...[
          if (state.page!.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: AppText('Tidak ada dataset yang sesuai.'),
            ),
          for (final dataset in state.page!.items)
            Card(
              child: ListTile(
                title: Text(dataset.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dataset.description?.isNotEmpty == true)
                      Text(dataset.description!),
                    Text(
                      '${dataset.itemCount} screening · ${_size(dataset.sizeBytes)}',
                    ),
                    AppText(dataset.status == 'active' ? 'Active' : 'Archived'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.navy),
                onTap: () => state.open(dataset.id),
              ),
            ),
          _pages(state.page!, (offset) => state.loadList(offset: offset)),
        ],
      ],
    );
  }

  Widget _pages<T>(DatasetPage<T> page, void Function(int) go) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: page.offset == 0
              ? null
              : () => go(
                  page.offset >= page.limit ? page.offset - page.limit : 0,
                ),
          child: const AppText('Previous'),
        ),
        Text(
          page.items.isEmpty
              ? '0 / ${page.total}'
              : '${page.offset + 1}–${page.offset + page.items.length} / ${page.total}',
        ),
        OutlinedButton(
          onPressed: page.hasMore ? () => go(page.offset + page.limit) : null,
          child: const AppText('Next'),
        ),
      ],
    ),
  );
  String _size(int bytes) => bytes < 1024 * 1024
      ? '$bytes B'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
