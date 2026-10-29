import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_managed_users_repository.dart';
import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/state/auth_provider.dart';

class LiveUsersScreen extends StatefulWidget {
  const LiveUsersScreen({super.key});
  @override
  State<LiveUsersScreen> createState() => _LiveUsersScreenState();
}

class _LiveUsersScreenState extends State<LiveUsersScreen> {
  final _search = TextEditingController();
  ManagedUserPage? _page;
  String? _error;
  bool _busy = false;
  bool? _active;
  int _request = 0;
  UserProfile? _actor;
  HttpManagedUsersRepository get _repo =>
      HttpManagedUsersRepository(context.read<ApiClient>());
  bool _current(UserProfile actor) =>
      mounted &&
      identical(context.read<AuthProvider>().profile, actor) &&
      context.read<AuthProvider>().isLoggedIn &&
      !actor.mustChangePassword;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final actor =
        auth.isLoggedIn &&
            !auth.mustChangePassword &&
            auth.mobileRole == MobileRole.technician
        ? auth.profile
        : null;
    if (!identical(actor, _actor)) {
      _actor = actor;
      _request++;
      _page = null;
      _error = null;
      _search.clear();
      if (actor != null) _load();
    }
  }

  @override
  void dispose() {
    _request++;
    _search.dispose();
    super.dispose();
  }

  String _message(Object failure) {
    final raw = failure is DioException ? failure.response?.data : null;
    final detail = raw is Map ? raw['detail'] : null;
    final code = detail is Map ? detail['code'] : null;
    return switch (code) {
      'email_taken' => context.trRead(
        'Email sudah digunakan.',
        'Email is already in use.',
      ),
      'user_inactive' => context.trRead(
        'Aktifkan akun sebelum reset password.',
        'Activate the account before resetting its password.',
      ),
      'role_not_allowed' || 'cannot_manage_self' => context.trRead(
        'Akun ini hanya dapat dikelola oleh administrator.',
        'Only an administrator can manage this account.',
      ),
      'user_not_found' => context.trRead(
        'Pengguna tidak ditemukan dalam instansi ini.',
        'User not found in this institution.',
      ),
      _ => context.trRead(
        'Permintaan gagal. Periksa koneksi atau izin akun, lalu coba lagi.',
        'Request failed. Check your connection or account permissions and retry.',
      ),
    };
  }

  Future<void> _load({int offset = 0}) async {
    final actor = _actor;
    if (actor == null) return;
    final request = ++_request;
    _busy = true;
    _error = null;
    _page = null;
    // Initial load runs during didChangeDependencies; subsequent loads rebuild.
    if (mounted) setState(() {});
    try {
      final page = await _repo.list(
        actor.tenantId,
        query: _search.text,
        offset: offset,
        active: _active,
      );
      if (!_current(actor) || request != _request) return;
      setState(() => _page = page);
    } catch (failure) {
      if (_current(actor) && request == _request) {
        setState(() => _error = _message(failure));
      }
    } finally {
      if (_current(actor) && request == _request) setState(() => _busy = false);
    }
  }

  bool _manageable(ManagedUser u) =>
      u.role == 'doctor' && u.id != _actor?.userId;
  Future<void> _issued(IssuedPassword issued, UserProfile actor) async {
    if (!_current(actor)) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => Consumer<AuthProvider>(
        builder: (_, auth, _) {
          if (!auth.isLoggedIn || !identical(auth.profile, actor)) {
            return AlertDialog(
              content: Text(
                context.trRead('Sesi telah berubah.', 'Session changed.'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('OK'),
                ),
              ],
            );
          }
          return AlertDialog(
            title: Text(
              context.trRead(
                'Password sementara · sekali tampil',
                'Temporary password · shown once',
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issued.user.email),
                  const SizedBox(height: 16),
                  SelectableText(
                    issued.password,
                    style: Theme.of(dialog).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.trRead('Berlaku sampai: ', 'Expires: ') +
                        issued.expiresAt.toLocal().toString(),
                  ),
                  Text(
                    context.trRead(
                      'Sampaikan secara pribadi kepada dokter. Password tidak disimpan di aplikasi; dokter wajib menggantinya saat login.',
                      'Give it privately to the doctor. This app does not retain the password; the doctor must replace it at sign-in.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialog),
                child: Text(
                  context.trRead(
                    'Sudah dicatat dengan aman',
                    'Recorded securely',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit([ManagedUser? user]) async {
    final actor = _actor;
    if (actor == null || !_current(actor)) return;
    // Fresh details avoid editing an obsolete paginated row.
    if (user != null) {
      try {
        user = await _repo.detail(actor.tenantId, user.id);
      } catch (failure) {
        if (_current(actor)) setState(() => _error = _message(failure));
        return;
      }
      if (!_current(actor) || !_manageable(user)) return;
    }
    if (!mounted) return;
    final name = TextEditingController(text: user?.name ?? '');
    final email = TextEditingController(text: user?.email ?? '');
    final spec = TextEditingController(text: user?.specialization ?? '');
    final form = GlobalKey<FormState>();
    bool saving = false;
    String? error;
    IssuedPassword? issued;
    final target = user;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => Consumer<AuthProvider>(
        builder: (_, auth, _) => StatefulBuilder(
          builder: (dialog, update) {
            if (!auth.isLoggedIn || !identical(auth.profile, actor)) {
              return AlertDialog(
                content: Text(
                  context.trRead('Sesi telah berubah.', 'Session changed.'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('OK'),
                  ),
                ],
              );
            }
            return PopScope(
              canPop: !saving,
              child: AlertDialog(
                title: Text(
                  context.trRead(
                    target == null ? 'Tambah dokter' : 'Edit dokter',
                    target == null ? 'Add doctor' : 'Edit doctor',
                  ),
                ),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: name,
                            maxLength: 255,
                            decoration: InputDecoration(
                              labelText: context.trRead(
                                'Nama lengkap',
                                'Full name',
                              ),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? context.trRead('Wajib diisi', 'Required')
                                : null,
                          ),
                          TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            validator: (v) =>
                                v == null ||
                                    !RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(v.trim())
                                ? context.trRead(
                                    'Email tidak valid',
                                    'Invalid email',
                                  )
                                : null,
                          ),
                          TextFormField(
                            controller: spec,
                            maxLength: 100,
                            decoration: InputDecoration(
                              labelText: context.trRead(
                                'Spesialisasi (opsional)',
                                'Specialization (optional)',
                              ),
                            ),
                          ),
                          if (target != null)
                            Text(
                              context.trRead(
                                'Perubahan email mengakhiri sesi dokter.',
                                'Changing email ends the doctor\'s sessions.',
                              ),
                            ),
                          if (error != null)
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(dialog),
                    child: Text(context.trRead('Batal', 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!form.currentState!.validate() ||
                                !_current(actor)) {
                              return;
                            }
                            update(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              if (target == null) {
                                issued = await _repo.create(
                                  actor.tenantId,
                                  name: name.text,
                                  email: email.text,
                                  specialization: spec.text.trim().isEmpty
                                      ? null
                                      : spec.text.trim(),
                                );
                              } else {
                                await _repo.update(actor.tenantId, target.id, {
                                  'full_name': name.text.trim(),
                                  'email': email.text.trim(),
                                  'specialization': spec.text.trim().isEmpty
                                      ? null
                                      : spec.text.trim(),
                                });
                              }
                              if (dialog.mounted) Navigator.pop(dialog);
                            } catch (failure) {
                              if (dialog.mounted && _current(actor)) {
                                update(() {
                                  error = _message(failure);
                                  saving = false;
                                });
                              }
                            }
                          },
                    child: Text(
                      context.trRead(
                        saving ? 'Menyimpan…' : 'Simpan',
                        saving ? 'Saving…' : 'Save',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    // Wait for the route exit animation before disposing field controllers.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    email.dispose();
    spec.dispose();
    if (!_current(actor)) return;
    if (issued != null) await _issued(issued!, actor);
    if (_current(actor)) await _load();
  }

  Future<void> _action(ManagedUser user, {bool reset = false}) async {
    final actor = _actor;
    if (actor == null || !_manageable(user) || !_current(actor)) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          context.trRead(
            reset
                ? 'Reset password dokter?'
                : user.active
                ? 'Nonaktifkan dokter?'
                : 'Aktifkan dokter?',
            reset
                ? 'Reset doctor password?'
                : user.active
                ? 'Deactivate doctor?'
                : 'Activate doctor?',
          ),
        ),
        content: Text(
          context.trRead(
            reset
                ? 'Sesi akun akan diakhiri. Password baru hanya tampil sekali.'
                : user.active
                ? 'Login dan sesi akun akan dihentikan. Riwayat screening tetap disimpan.'
                : 'Akun dapat login kembali.',
            reset
                ? 'Sessions will end. The temporary password is shown once.'
                : user.active
                ? 'Login and sessions will be blocked. Screening history is retained.'
                : 'The account can sign in again.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(context.trRead('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(context.trRead('Lanjut', 'Continue')),
          ),
        ],
      ),
    );
    if (yes != true || !_current(actor)) return;
    setState(() => _busy = true);
    try {
      if (reset) {
        final issued = await _repo.reset(actor.tenantId, user.id);
        if (_current(actor)) {
          setState(() => _busy = false);
          await _issued(issued, actor);
        }
      } else {
        await _repo.update(actor.tenantId, user.id, {
          'is_active': !user.active,
        });
      }
      if (_current(actor)) await _load();
    } catch (failure) {
      if (_current(actor)) setState(() => _error = _message(failure));
    } finally {
      if (_current(actor)) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();
    if (_actor == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.trRead('Pengguna instansi', 'Institution users'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.trRead(
            'Teknisi hanya mengelola dokter dalam instansi akun. Akun lain ditampilkan hanya baca.',
            'Technicians manage doctors in their own institution. Other accounts are read-only.',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _search,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: context.trRead(
                    'Cari nama / email',
                    'Search name / email',
                  ),
                ),
                onSubmitted: (_) => _busy ? null : _load(),
              ),
            ),
            DropdownButton<bool?>(
              value: _active,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(context.trRead('Semua status', 'All statuses')),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Text(context.trRead('Aktif', 'Active')),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text(context.trRead('Nonaktif', 'Inactive')),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (v) {
                      setState(() => _active = v);
                      _load();
                    },
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _load(),
              child: Text(
                context.trRead('Cari / muat ulang', 'Search / refresh'),
              ),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _edit(),
              icon: const Icon(Icons.person_add_alt),
              label: Text(context.trRead('Tambah dokter', 'Add doctor')),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (!_busy && _page?.items.isEmpty == true)
          Text(
            context.trRead(
              'Tidak ada pengguna yang sesuai.',
              'No matching users.',
            ),
          ),
        for (final u in _page?.items ?? <ManagedUser>[])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name, style: Theme.of(context).textTheme.titleMedium),
                  Text(u.email),
                  Text(
                    '${u.role} · ${u.active ? context.trRead('Aktif', 'Active') : context.trRead('Nonaktif', 'Inactive')}',
                  ),
                  if (u.specialization?.isNotEmpty == true)
                    Text(u.specialization!),
                  if (u.mustChangePassword)
                    Text(
                      context.trRead(
                        'Wajib ganti password',
                        'Password change required',
                      ),
                    ),
                  if (_manageable(u))
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : () => _edit(u),
                          child: Text(context.trRead('Edit', 'Edit')),
                        ),
                        TextButton(
                          onPressed: _busy || !u.active
                              ? null
                              : () => _action(u, reset: true),
                          child: Text(
                            context.trRead('Reset password', 'Reset password'),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _action(u),
                          child: Text(
                            context.trRead(
                              u.active ? 'Nonaktifkan' : 'Aktifkan',
                              u.active ? 'Deactivate' : 'Activate',
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Text(context.trRead('Hanya baca', 'Read only')),
                ],
              ),
            ),
          ),
        if (_page != null)
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _busy || _page!.offset == 0
                    ? null
                    : () => _load(offset: _page!.offset - 20),
                child: Text(context.trRead('Sebelumnya', 'Previous')),
              ),
              Text(
                '${_page!.items.isEmpty ? 0 : _page!.offset + 1}–${_page!.offset + _page!.items.length} / ${_page!.total}',
              ),
              OutlinedButton(
                onPressed:
                    _busy || _page!.offset + _page!.items.length >= _page!.total
                    ? null
                    : () => _load(offset: _page!.offset + 20),
                child: Text(context.trRead('Berikutnya', 'Next')),
              ),
            ],
          ),
      ],
    );
  }
}
