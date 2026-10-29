import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/features/shared/presentation/widgets/app_card.dart';
import 'package:myapp/features/shared/presentation/widgets/empty_state.dart';
import 'package:myapp/features/shared/presentation/widgets/section_header.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/institution_provider.dart';
import 'package:myapp/core/config/app_config.dart';
import 'live_users_screen.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'institution_overview.dart';
import 'institution_users.dart';
import 'institution_widgets.dart';

class InstitutionScreen extends StatelessWidget {
  const InstitutionScreen({super.key, this.section = 'overview'});
  final String section;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final actor = auth.profile;
    if (!auth.isLoggedIn || actor?.mobileRole != MobileRole.technician) {
      return const SizedBox.shrink();
    }
    if (actor == null) return const SizedBox.shrink();
    if (section == 'overview' || AppConfig.useHttp) {
      if (section == 'users' && AppConfig.useHttp) {
        return const LiveUsersScreen();
      }
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.tr('Ruang kerja teknisi', 'Technician workspace'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              'Kelola akun dokter dan dataset dalam instansi akun. Screening, validasi dan sinkronisasi bukan akses teknisi.',
              'Manage doctor accounts and datasets in your institution. Screening, validation and sync are not technician permissions.',
            ),
          ),
          const SizedBox(height: 24),
          for (final task in [
            (
              '/users',
              context.tr('Kelola akun dokter', 'Manage doctor accounts'),
              Icons.manage_accounts,
            ),
            (
              '/dataset',
              context.tr('Kelola dataset', 'Manage datasets'),
              Icons.table_chart,
            ),
            (
              '/dashboard',
              context.tr(
                'Lihat ringkasan instansi',
                'View institution summary',
              ),
              Icons.dashboard,
            ),
          ])
            Card(
              child: ListTile(
                leading: Icon(task.$3),
                title: Text(task.$2),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(task.$1),
              ),
            ),
        ],
      );
    }
    final store = context.watch<InstitutionProvider>();
    final technician = actor.mobileRole == MobileRole.technician;
    final available =
        store.available && demoInstitutions.containsKey(actor.tenantId);
    final workspace = available ? store.read(actor) : null;
    final title = switch (section) {
      'users' => context.tr('Pengguna instansi', 'Institution users'),
      'models' => context.tr('Kelola model', 'Manage models'),
      _ =>
        technician
            ? context.tr('Ruang kerja teknisi', 'Technician workspace')
            : context.tr('Ringkasan instansi', 'Institution overview'),
    };
    return LayoutBuilder(
      builder: (context, size) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.all(size.maxWidth < 700 ? 16 : 24),
            children: [
              SectionHeader(
                title: title,
                subtitle: technician
                    ? context.tr(
                        'Kelola pengguna, backup data, dan model perangkat instansi.',
                        'Manage users, data backups, and institution device models.',
                      )
                    : context.tr(
                        'Pantau aktivitas TBScreen dalam instansi Anda.',
                        'Monitor TBScreen activity within your institution.',
                      ),
                trailing: Chip(
                  avatar: const Icon(
                    Icons.local_hospital_outlined,
                    size: 18,
                    color: AppTheme.primaryDark,
                  ),
                  label: Text(actor.institution),
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(height: 20),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      available
                          ? Icons.info_outline_rounded
                          : Icons.cloud_off_rounded,
                      color: AppTheme.primaryDark,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        available
                            ? context.tr(
                                'DEMO · Data contoh. Perubahan pengguna dan model hanya berlaku selama demo ini; tidak mengubah akun atau perangkat sungguhan.',
                                'DEMO · Sample data. User and model changes last for this demo only; real accounts and devices are not changed.',
                              )
                            : context.tr(
                                'Layanan instansi belum terhubung. Daftar pengguna dan ringkasan aktivitas belum tersedia.',
                                'Institution service is not connected. User lists and activity summaries are not available.',
                              ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (section == 'overview')
                InstitutionOverview(
                  technician: technician,
                  workspace: workspace,
                ),
              if (section == 'users' && workspace != null)
                InstitutionUsers(workspace: workspace, editable: technician),
              if (section == 'models' && workspace != null)
                _ModelCatalog(actor: actor, workspace: workspace),
              if (section != 'overview' && workspace == null)
                AppCard(
                  child: EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: context.tr(
                      'Data belum tersedia',
                      'Data not available',
                    ),
                    message: context.tr(
                      'Coba kembali setelah layanan instansi terhubung.',
                      'Try again when the institution service is connected.',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelCatalog extends StatelessWidget {
  const _ModelCatalog({required this.actor, required this.workspace});
  final UserProfile actor;
  final InstitutionWorkspace workspace;
  @override
  Widget build(BuildContext context) => InstitutionPanel(
    title: context.tr('Model pada instansi', 'Institution models'),
    subtitle: context.tr(
      'Katalog demo. Pemeriksaan pembaruan dilakukan pada setiap perangkat.',
      'Demo catalog. Check for updates on each device.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (workspace.models.isEmpty)
          EmptyState(
            icon: Icons.memory_rounded,
            title: context.tr('Belum ada model', 'No models yet'),
            message: context.tr(
              'Tidak ada model dalam katalog demo instansi ini.',
              'No models in this institution’s demo catalog.',
            ),
          ),
        for (final model in workspace.models)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const InstitutionIcon(Icons.memory_rounded),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr(
                          'Katalog demo · bukan model terpasang',
                          'Demo catalog · not an installed model',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Hapus model', 'Delete model'),
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppTheme.errorDark,
                  onPressed: () async {
                    final store = context.read<InstitutionProvider>();
                    final confirmed = await confirmInstitutionAction(
                      context,
                      context.tr('Hapus model demo?', 'Delete demo model?'),
                      context.tr(
                        'Model ini dihapus dari katalog simulasi instansi ini.',
                        'This removes the model from this institution’s simulated catalog.',
                      ),
                    );
                    if (confirmed &&
                        context.mounted &&
                        context.read<AuthProvider>().profile == actor) {
                      store.deleteModel(actor, model);
                    }
                  },
                ),
              ],
            ),
          ),
        const Divider(),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => context.go('/sync'),
            icon: const Icon(Icons.system_update_alt_rounded),
            label: Text(
              context.tr('Buka pusat sinkronisasi', 'Open sync center'),
            ),
          ),
        ),
      ],
    ),
  );
}
