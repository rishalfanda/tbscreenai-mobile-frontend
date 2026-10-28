import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/institution_provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/features/shared/presentation/widgets/empty_state.dart';
import 'institution_widgets.dart';

Future<bool> confirmInstitutionAction(
  BuildContext context,
  String title,
  String description,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Lanjutkan', 'Continue')),
          ),
        ],
      ),
    ) ??
    false;

class InstitutionUsers extends StatefulWidget {
  const InstitutionUsers({
    super.key,
    required this.workspace,
    required this.editable,
  });
  final InstitutionWorkspace workspace;
  final bool editable;
  @override
  State<InstitutionUsers> createState() => _InstitutionUsersState();
}

class _InstitutionUsersState extends State<InstitutionUsers> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final users = widget.workspace.users.where(
      (u) =>
          '${u.name} ${u.email}'.toLowerCase().contains(_search.toLowerCase()),
    );
    return InstitutionPanel(
      title: context.tr('Daftar pengguna', 'User directory'),
      subtitle: context.tr(
        '${widget.workspace.users.length} pengguna dalam instansi Anda',
        '${widget.workspace.users.length} users in your institution',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.editable) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _UserForm(),
                ),
                icon: const Icon(Icons.person_add_alt),
                label: Text(context.tr('Tambah pengguna', 'Add user')),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            decoration: InputDecoration(
              hintText: context.tr(
                'Cari nama atau email',
                'Search name or email',
              ),
              prefixIcon: const Icon(Icons.search),
              fillColor: AppTheme.background,
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
          const SizedBox(height: 16),
          if (users.isEmpty)
            EmptyState(
              icon: Icons.people_alt_outlined,
              title: context.tr(
                'Belum ada pengguna yang cocok dalam instansi ini.',
                'No matching users in this institution.',
              ),
              message: _search.isNotEmpty
                  ? context.tr(
                      'Coba nama atau email lain.',
                      'Try another name or email.',
                    )
                  : context.tr(
                      'Pengguna yang ditambahkan akan tampil di sini.',
                      'Added users will appear here.',
                    ),
            ),
          for (final user in users)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const InstitutionIcon(Icons.person_outline_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Chip(
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        label: Text(
                          user.role == 'doctor'
                              ? context.tr('Dokter', 'Doctor')
                              : context.tr('Tenaga kesehatan', 'Health worker'),
                        ),
                      ),
                      if (user.resetRequested)
                        Text(
                          context.tr(
                            'Simulasi pemulihan dicatat · email tidak dikirim',
                            'Recovery simulated · no email sent',
                          ),
                        ),
                      if (widget.editable)
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: Text(
                                context.tr(
                                  'Backup dataset pengguna',
                                  'Back up user datasets',
                                ),
                              ),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    context.tr(
                                      'Backup dataset pengguna',
                                      'Back up user datasets',
                                    ),
                                  ),
                                  content: Text(
                                    context.tr(
                                      'Backup seluruh hasil screening pengguna ini memerlukan API backup instansi. Data akun dokter tidak dibuka atau dipindahkan ke akun teknisi oleh aplikasi ini.',
                                      'Backing up all screening results for this user requires an institution backup API. This app does not open or transfer the doctor account cache into the technician account.',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(context.tr('Tutup', 'Close')),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(context.tr('Edit', 'Edit')),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => _UserForm(user: user),
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.lock_reset),
                              label: Text(
                                context.tr(
                                  'Bantu lupa password',
                                  'Password recovery',
                                ),
                              ),
                              onPressed: () async {
                                final actor = context
                                    .read<AuthProvider>()
                                    .profile!;
                                final store = context
                                    .read<InstitutionProvider>();
                                final confirmed = await confirmInstitutionAction(
                                  context,
                                  context.tr(
                                    'Simulasikan pemulihan?',
                                    'Simulate recovery?',
                                  ),
                                  context.tr(
                                    'Permintaan demo akan dicatat. Tidak ada password yang diubah atau email yang dikirim.',
                                    'A demo request will be recorded. No password is changed and no email is sent.',
                                  ),
                                );
                                if (confirmed &&
                                    context.mounted &&
                                    context.read<AuthProvider>().profile ==
                                        actor) {
                                  store.resetPassword(actor, user.id);
                                }
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              label: Text(context.tr('Hapus', 'Delete')),
                              onPressed: () async {
                                final actor = context
                                    .read<AuthProvider>()
                                    .profile!;
                                final store = context
                                    .read<InstitutionProvider>();
                                final confirmed = await confirmInstitutionAction(
                                  context,
                                  context.tr(
                                    'Hapus pengguna demo?',
                                    'Delete demo user?',
                                  ),
                                  context.tr(
                                    'Hapus akun dari daftar simulasi instansi ini. Data screening tidak dihapus.',
                                    'Remove this account from this institution’s simulated directory. Screening records are not deleted.',
                                  ),
                                );
                                if (confirmed &&
                                    context.mounted &&
                                    context.read<AuthProvider>().profile ==
                                        actor) {
                                  store.deleteUser(actor, user.id);
                                }
                              },
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

class _UserForm extends StatefulWidget {
  const _UserForm({this.user});
  final InstitutionUser? user;
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name);
  late final _email = TextEditingController(text: widget.user?.email);
  late String _role = widget.user?.role ?? 'doctor';
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.user == null
          ? context.tr('Tambah pengguna demo', 'Add demo user')
          : context.tr('Edit pengguna demo', 'Edit demo user'),
    ),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(
                  'Instansi mengikuti akun teknisi. Akun ini hanya untuk pratinjau, tidak dapat dipakai login.',
                  'Institution follows the technician account. This is a preview account and cannot sign in.',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: context.tr('Nama lengkap', 'Full name'),
                ),
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? context.tr('Nama wajib diisi', 'Name is required')
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) =>
                    !RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(v?.trim() ?? '')
                    ? context.tr('Email belum valid', 'Invalid email')
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _role,
                decoration: InputDecoration(
                  labelText: context.tr('Peran', 'Role'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'doctor',
                    child: Text(context.tr('Dokter', 'Doctor')),
                  ),
                  DropdownMenuItem(
                    value: 'health_worker',
                    child: Text(
                      context.tr('Tenaga kesehatan', 'Health worker'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _role = v!),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('Batal', 'Cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (!_key.currentState!.validate()) return;
          try {
            context.read<InstitutionProvider>().saveUser(
              context.read<AuthProvider>().profile!,
              id: widget.user?.id,
              name: _name.text,
              email: _email.text,
              role: _role,
            );
            Navigator.pop(context);
          } catch (_) {
            setState(
              () => _error = context.tr(
                'Gagal menyimpan. Periksa email duplikat atau akses akun.',
                'Could not save. Check duplicate email or account access.',
              ),
            );
          }
        },
        child: Text(context.tr('Simpan demo', 'Save demo')),
      ),
    ],
  );
}
