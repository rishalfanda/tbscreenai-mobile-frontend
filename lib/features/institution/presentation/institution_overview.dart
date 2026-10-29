import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/state/institution_provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/features/shared/presentation/widgets/empty_state.dart';
import 'institution_widgets.dart';

class InstitutionOverview extends StatelessWidget {
  const InstitutionOverview({
    super.key,
    required this.technician,
    this.workspace,
  });
  final bool technician;
  final InstitutionWorkspace? workspace;
  @override
  Widget build(BuildContext context) {
    final pending = context.tr('Belum tersedia', 'Not available');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InstitutionGrid(
          maxColumns: technician ? 3 : 4,
          children: [
            InstitutionMetric(
              icon: Icons.people_alt_rounded,
              label: context.tr('Pengguna instansi', 'Institution users'),
              value: workspace == null ? '—' : '${workspace!.users.length}',
              caption: context.tr(
                'Dokter & tenaga kesehatan',
                'Doctors & health workers',
              ),
              color: AppTheme.lightBlue,
            ),
            if (technician)
              InstitutionMetric(
                icon: Icons.memory_rounded,
                label: context.tr('Katalog model', 'Model catalog'),
                value: workspace == null ? '—' : '${workspace!.models.length}',
                caption: context.tr(
                  'Model dalam katalog demo',
                  'Models in the demo catalog',
                ),
              )
            else ...[
              InstitutionMetric(
                icon: Icons.monitor_heart_rounded,
                label: context.tr('Hasil screening', 'Screening results'),
                value: '—',
                caption: pending,
              ),
              InstitutionMetric(
                icon: Icons.analytics_rounded,
                label: context.tr('Ringkasan hasil AI', 'AI result summary'),
                value: '—',
                caption: pending,
                color: AppTheme.successDark,
              ),
            ],
            InstitutionMetric(
              icon: Icons.cloud_done_rounded,
              label: context.tr('Aktivitas sync data', 'Data sync activity'),
              value: '—',
              caption: pending,
              color: AppTheme.warning,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (technician) ...[
          Text(
            context.tr('Kelola perangkat & pengguna', 'Manage devices & users'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          InstitutionGrid(
            maxColumns: 3,
            children: [
              InstitutionTask(
                icon: Icons.cloud_upload_rounded,
                title: context.tr(
                  'Backup dataset screening',
                  'Back up screening datasets',
                ),
                description: context.tr(
                  'Sinkronkan data pada perangkat yang sedang digunakan. Backup lintas pengguna belum tersedia.',
                  'Sync data on the device currently in use. Cross-user backup is not available yet.',
                ),
                action: context.tr('Buka sinkronisasi', 'Open sync center'),
                route: '/sync',
              ),
              InstitutionTask(
                icon: Icons.system_update_alt_rounded,
                title: context.tr(
                  'Pembaruan model per perangkat',
                  'Model updates per device',
                ),
                description: context.tr(
                  'Periksa pembaruan dan kelola katalog model untuk instansi Anda.',
                  'Check updates and manage your institution’s model catalog.',
                ),
                action: context.tr('Kelola model', 'Manage models'),
                route: '/models',
              ),
              InstitutionTask(
                icon: Icons.manage_accounts_rounded,
                title: context.tr(
                  'Dokter & tenaga kesehatan',
                  'Doctors & health workers',
                ),
                description: context.tr(
                  'Kelola pengguna dan bantu pemulihan akun dalam satu tempat.',
                  'Manage users and help with account recovery in one place.',
                ),
                action: context.tr('Kelola pengguna', 'Manage users'),
                route: '/users',
              ),
            ],
          ),
        ] else ...[
          InstitutionGrid(
            maxColumns: 2,
            equalHeight: false,
            children: [
              InstitutionPanel(
                title: context.tr(
                  'Ringkasan screening & AI',
                  'Screening & AI summary',
                ),
                subtitle: context.tr(
                  'Hanya aktivitas dalam instansi Anda',
                  'Activity within your institution only',
                ),
                child: EmptyState(
                  icon: Icons.monitor_heart_outlined,
                  title: context.tr(
                    'Ringkasan belum tersedia',
                    'Summary not available',
                  ),
                  message: context.tr(
                    'Ringkasan hasil screening dan AI akan tampil setelah layanan instansi terhubung.',
                    'Screening and AI summaries will appear when the institution service is connected.',
                  ),
                ),
              ),
              InstitutionPanel(
                title: context.tr('Riwayat backup data', 'Data backup history'),
                subtitle: context.tr(
                  'Status sinkronisasi perangkat instansi',
                  'Institution device sync status',
                ),
                child: EmptyState(
                  icon: Icons.cloud_sync_outlined,
                  title: context.tr(
                    'Riwayat belum tersedia',
                    'History not available',
                  ),
                  message: context.tr(
                    'Aktivitas backup akan tampil setelah data sinkronisasi instansi tersedia.',
                    'Backup activity will appear when institution sync data is available.',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          InstitutionTask(
            icon: Icons.people_alt_rounded,
            title: context.tr(
              'Lihat pengguna instansi',
              'View institution users',
            ),
            description: context.tr(
              'Lihat dokter dan tenaga kesehatan yang menggunakan TBScreen di instansi Anda.',
              'View the doctors and health workers using TBScreen in your institution.',
            ),
            action: context.tr('Lihat pengguna', 'View users'),
            route: '/users',
          ),
        ],
        const SizedBox(height: 24),
        InstitutionPanel(
          title: context.tr(
            'Aktivitas administrasi demo',
            'Demo administration activity',
          ),
          child: workspace == null || workspace!.events.isEmpty
              ? EmptyState(
                  icon: Icons.history_rounded,
                  title: context.tr('Belum ada aktivitas', 'No activity yet'),
                  message: context.tr(
                    'Perubahan pengguna dan katalog model demo akan ditampilkan di sini.',
                    'Demo user and model catalog changes will appear here.',
                  ),
                )
              : Column(
                  children: [
                    for (final event in workspace!.events.take(10))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const InstitutionIcon(Icons.history_rounded),
                        title: Text(switch (event) {
                          'user_saved' => context.tr(
                            'Pengguna demo disimpan',
                            'Demo user saved',
                          ),
                          'user_deleted' => context.tr(
                            'Pengguna demo dihapus',
                            'Demo user deleted',
                          ),
                          'password_reset' => context.tr(
                            'Permintaan pemulihan demo dicatat; email tidak dikirim',
                            'Demo recovery request recorded; no email sent',
                          ),
                          _ => context.tr(
                            'Model demo dihapus',
                            'Demo model deleted',
                          ),
                        }),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
