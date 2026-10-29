import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/domain/models/dataset_page.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/live_dataset_provider.dart';

class DatasetWriteActions extends StatelessWidget {
  const DatasetWriteActions({super.key});
  bool _current(BuildContext context, UserProfile actor) =>
      context.mounted &&
      context.read<AuthProvider>().isLoggedIn &&
      identical(context.read<AuthProvider>().profile, actor);
  Future<void> _edit(
    BuildContext context,
    LiveDatasetProvider state,
    DatasetEntry? entry,
  ) async {
    final actor = context.read<AuthProvider>().profile!;
    final name = TextEditingController(text: entry?.name ?? '');
    final description = TextEditingController(text: entry?.description ?? '');
    final form = GlobalKey<FormState>();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (d) => Consumer<AuthProvider>(
        builder: (_, auth, _) {
          if (!auth.isLoggedIn || !identical(auth.profile, actor)) {
            return const SizedBox.shrink();
          }
          return AlertDialog(
            title: Text(
              context.trRead(
                entry == null ? 'Buat dataset' : 'Edit dataset',
                entry == null ? 'Create dataset' : 'Edit dataset',
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
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: context.trRead(
                            'Nama dataset',
                            'Dataset name',
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? context.trRead('Wajib diisi', 'Required')
                            : null,
                      ),
                      TextFormField(
                        controller: description,
                        maxLength: 2000,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: context.trRead('Deskripsi', 'Description'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d),
                child: Text(context.trRead('Batal', 'Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(d, {
                      'name': name.text.trim(),
                      'description': description.text.trim(),
                    });
                  }
                },
                child: Text(context.trRead('Simpan', 'Save')),
              ),
            ],
          );
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    description.dispose();
    if (values == null || !context.mounted || !_current(context, actor)) return;
    await state.mutate(
      (r) async => entry == null
          ? await r.create(
              name: values['name']!,
              description: values['description'],
            )
          : await r.update(entry.id, values),
    );
  }

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String message,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: Text(message),
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
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();
    final state = context.watch<LiveDatasetProvider>();
    if (!state.canWrite) return const SizedBox.shrink();
    final entry = state.selected;
    final actor = context.read<AuthProvider>().profile!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          if (state.selectedId == null)
            FilledButton.icon(
              onPressed: state.busy ? null : () => _edit(context, state, null),
              icon: const Icon(Icons.add),
              label: Text(context.trRead('Buat dataset', 'Create dataset')),
            ),
          if (entry != null) ...[
            OutlinedButton(
              onPressed: state.busy ? null : () => _edit(context, state, entry),
              child: Text(context.trRead('Edit dataset', 'Edit dataset')),
            ),
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () async {
                      final status = entry.status == 'active'
                          ? 'archived'
                          : 'active';
                      if (!await _confirm(
                            context,
                            context.trRead(
                              status == 'archived'
                                  ? 'Arsipkan dataset?'
                                  : 'Buka kembali dataset?',
                              status == 'archived'
                                  ? 'Archive dataset?'
                                  : 'Reopen dataset?',
                            ),
                            entry.name,
                          ) ||
                          !context.mounted ||
                          !_current(context, actor)) {
                        return;
                      }
                      await state.mutate(
                        (r) => r.update(entry.id, {'status': status}),
                      );
                    },
              child: Text(
                context.trRead(
                  entry.status == 'active' ? 'Arsipkan' : 'Buka kembali',
                  entry.status == 'active' ? 'Archive' : 'Reopen',
                ),
              ),
            ),
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () async {
                      if (!await _confirm(
                            context,
                            context.trRead('Hapus dataset?', 'Delete dataset?'),
                            context.trRead(
                              'Dataset dihapus; hasil screening asal tetap disimpan.',
                              'The dataset is deleted; original screenings are retained.',
                            ),
                          ) ||
                          !context.mounted ||
                          !_current(context, actor)) {
                        return;
                      }
                      await state.mutate((r) async {
                        await r.delete(entry.id);
                        return null;
                      }, deleted: true);
                    },
              child: Text(context.trRead('Hapus dataset', 'Delete dataset')),
            ),
            if (entry.status == 'active')
              FilledButton.icon(
                onPressed: state.busy
                    ? null
                    : () async {
                        final ids = await showDialog<List<String>>(
                          context: context,
                          builder: (_) => _ScreeningPicker(actor: actor),
                        );
                        if (ids == null ||
                            ids.isEmpty ||
                            !context.mounted ||
                            !_current(context, actor)) {
                          return;
                        }
                        await state.mutate((r) async {
                          await r.addItems(entry.id, ids);
                          return null;
                        });
                      },
                icon: const Icon(Icons.playlist_add),
                label: Text(
                  context.trRead('Tambah hasil screening', 'Add screenings'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class RemoveDatasetItem extends StatelessWidget {
  const RemoveDatasetItem({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();
    final state = context.watch<LiveDatasetProvider>();
    if (!state.canWrite || state.selected?.status != 'active') {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: context.trRead('Keluarkan dari dataset', 'Remove from dataset'),
      onPressed: state.busy
          ? null
          : () async {
              final actor = context.read<AuthProvider>().profile;
              final dataset = state.selected!.id;
              final yes = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text(
                    context.trRead('Keluarkan screening?', 'Remove screening?'),
                  ),
                  content: Text(
                    context.trRead(
                      'Hasil screening asal tetap disimpan.',
                      'The original screening is retained.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: Text(context.trRead('Batal', 'Cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: Text(context.trRead('Keluarkan', 'Remove')),
                    ),
                  ],
                ),
              );
              if (yes != true ||
                  !context.mounted ||
                  !identical(context.read<AuthProvider>().profile, actor)) {
                return;
              }
              await state.mutate((r) async {
                await r.removeItem(dataset, id);
                return null;
              });
            },
      icon: const Icon(Icons.remove_circle_outline),
    );
  }
}

class _ScreeningPicker extends StatefulWidget {
  const _ScreeningPicker({required this.actor});
  final UserProfile actor;
  @override
  State<_ScreeningPicker> createState() => _ScreeningPickerState();
}

class _ScreeningPickerState extends State<_ScreeningPicker> {
  List<Map<String, dynamic>> _rows = [];
  final Set<String> _selected = {};
  int _offset = 0, _generation = 0;
  bool _busy = true;
  String? _error;
  bool get _current =>
      mounted &&
      context.read<AuthProvider>().isLoggedIn &&
      identical(context.read<AuthProvider>().profile, widget.actor);
  @override
  void initState() {
    super.initState();
    _load(0);
  }

  @override
  void dispose() {
    _generation++;
    _selected.clear();
    _rows = [];
    super.dispose();
  }

  Future<void> _load(int offset) async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _rows = [];
    });
    try {
      final raw = (await context.read<ApiClient>().dio.get<Object?>(
        '/diagnoses',
        queryParameters: {'limit': 20, 'offset': offset},
      )).data;
      if (!_current || generation != _generation) return;
      if (raw is! List || raw.length > 20) {
        throw const FormatException('Invalid screening list');
      }
      final rows = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is! Map<String, dynamic> ||
            item['tenant_id'] != widget.actor.tenantId ||
            item['id'] is! String ||
            item['patient_id'] is! String ||
            item['diagnosed_at'] is! String ||
            item['is_positive'] is! bool ||
            item['confidence'] is! int) {
          throw const FormatException('Screening institution mismatch');
        }
        DateTime.parse(item['diagnosed_at'] as String);
        rows.add(item);
      }
      setState(() {
        _rows = rows;
        _offset = offset;
      });
    } catch (_) {
      if (_current && generation == _generation) {
        setState(
          () => _error = context.trRead(
            'Daftar screening gagal dimuat. Coba lagi.',
            'Failed to load screenings. Retry.',
          ),
        );
      }
    } finally {
      if (_current && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();
    context.watch<AuthProvider>();
    if (!_current) {
      return AlertDialog(
        content: Text(
          context.trRead('Sesi telah berubah.', 'Session changed.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(context.trRead('Pilih hasil screening', 'Select screenings')),
      content: SizedBox(
        width: 650,
        height: 420,
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (!_busy && _rows.isEmpty && _error == null)
              Text(
                context.trRead(
                  'Tidak ada screening pada halaman ini.',
                  'No screenings on this page.',
                ),
              ),
            Expanded(
              child: ListView(
                children: [
                  for (final row in _rows)
                    CheckboxListTile(
                      value: _selected.contains(row['id']),
                      title: Text(
                        '${DateTime.parse(row['diagnosed_at'] as String).toLocal()} · ${row['is_positive'] == true ? 'AI Positive' : 'AI Negative'} (${row['confidence']}%)',
                      ),
                      subtitle: Text(
                        '${context.trRead('ID pasien', 'Patient ID')}: ${row['patient_id']}',
                      ),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() {
                              if (v == true && _selected.length < 500) {
                                _selected.add(row['id'] as String);
                              } else {
                                _selected.remove(row['id']);
                              }
                            }),
                    ),
                ],
              ),
            ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: _busy || _offset == 0
                      ? null
                      : () => _load(_offset - 20),
                  child: Text(context.trRead('Sebelumnya', 'Previous')),
                ),
                TextButton(
                  onPressed: _busy || _rows.length < 20
                      ? null
                      : () => _load(_offset + 20),
                  child: Text(context.trRead('Berikutnya', 'Next')),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _load(_offset),
                  child: Text(context.trRead('Muat ulang', 'Refresh')),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.trRead('Batal', 'Cancel')),
        ),
        FilledButton(
          onPressed: _busy || _selected.isEmpty
              ? null
              : () => Navigator.pop(context, _selected.toList(growable: false)),
          child: Text(
            '${context.trRead('Tambahkan', 'Add')} (${_selected.length})',
          ),
        ),
      ],
    );
  }
}
