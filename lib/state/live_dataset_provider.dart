import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/models/dataset_page.dart';
import 'package:myapp/domain/repositories/dataset_repository.dart';
import 'auth_provider.dart';

class LiveDatasetProvider extends ChangeNotifier {
  LiveDatasetProvider(this._repository, this._session) {
    _session.addListener(_sessionChanged);
    _sessionChanged();
  }
  final DatasetReadRepository _repository;
  final AuthProvider _session;
  String? _owner;
  int _generation = 0;
  bool _disposed = false;
  bool busy = false;
  String? error;
  String query = '';
  String? selectedId;
  int _listOffset = 0;
  int _itemsOffset = 0;
  DatasetPage<DatasetEntry>? page;
  DatasetEntry? selected;
  DatasetPage<DatasetScreening>? screenings;

  void _sessionChanged() {
    final owner =
        _session.isLoggedIn &&
            !_session.mustChangePassword &&
            _session.mobileRole.allows('/dataset')
        ? '${_session.userId}:${_session.tenantId}'
        : null;
    if (owner == _owner) return;
    _owner = owner;
    _generation++;
    _clear();
    query = '';
    selectedId = null;
    _listOffset = 0;
    _itemsOffset = 0;
    if (owner == null) {
      notifyListeners();
    } else {
      loadList();
    }
  }

  void _clear() {
    page = null;
    selected = null;
    screenings = null;
    error = null;
    busy = false;
  }

  Future<void> loadList({String? search, int offset = 0}) async {
    if (_disposed || _owner == null) return;
    query = search ?? query;
    _listOffset = offset;
    selectedId = null;
    final generation = ++_generation;
    _clear();
    busy = true;
    notifyListeners();
    try {
      final result = await _repository.list(query: query, offset: offset);
      if (!_current(generation)) return;
      for (final row in result.items) {
        _verifyTenant(row);
      }
      page = result;
    } catch (failure) {
      if (!_current(generation)) return;
      error = _message(failure);
    }
    if (!_current(generation)) return;
    busy = false;
    notifyListeners();
  }

  Future<void> open(String id, {int offset = 0}) async {
    if (_disposed || _owner == null) return;
    selectedId = id;
    _itemsOffset = offset;
    final generation = ++_generation;
    _clear();
    busy = true;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _repository.detail(id),
        _repository.items(id, offset: offset),
      ]);
      if (!_current(generation)) return;
      final entry = results[0] as DatasetEntry;
      _verifyTenant(entry);
      if (entry.id != id) {
        throw const FormatException('Dataset identity mismatch');
      }
      selected = entry;
      screenings = results[1] as DatasetPage<DatasetScreening>;
    } catch (failure) {
      if (!_current(generation)) return;
      error = _message(failure);
    }
    if (!_current(generation)) return;
    busy = false;
    notifyListeners();
  }

  Future<void> refresh() => selectedId == null
      ? loadList(offset: _listOffset)
      : open(selectedId!, offset: _itemsOffset);

  bool get canWrite =>
      !_disposed &&
      _owner != null &&
      _session.mobileRole == MobileRole.technician &&
      _repository is DatasetWriteRepository;
  Future<bool> mutate(
    Future<DatasetEntry?> Function(DatasetWriteRepository) operation, {
    bool deleted = false,
  }) async {
    if (!canWrite || busy) return false;
    final generation = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final entry = await operation(_repository as DatasetWriteRepository);
      if (!_current(generation)) return false;
      if (entry != null) _verifyTenant(entry);
      busy = false;
      if (deleted || selectedId == null) {
        await loadList();
      } else {
        await open(selectedId!);
      }
      return true;
    } catch (failure) {
      if (!_current(generation)) return false;
      error = _writeMessage(failure);
      busy = false;
      notifyListeners();
      return false;
    }
  }

  String _writeMessage(Object failure) {
    final raw = failure is DioException ? failure.response?.data : null;
    final detail = raw is Map ? raw['detail'] : null;
    final code = detail is Map ? detail['code'] : null;
    return switch (code) {
      'dataset_archived' =>
        'Dataset diarsipkan. Buka kembali sebelum mengubah item.',
      'diagnosis_unknown' =>
        'Sebagian hasil screening tidak ditemukan dalam instansi ini. Tidak ada item ditambahkan.',
      _ =>
        'Perubahan dataset gagal. Periksa koneksi, data dan izin akun lalu coba lagi.',
    };
  }

  void _verifyTenant(DatasetEntry entry) {
    if (entry.tenantId != _session.tenantId) {
      throw const FormatException('Dataset institution mismatch');
    }
  }

  bool _current(int generation) =>
      !_disposed && _owner != null && generation == _generation;
  String _message(Object failure) => switch (failure) {
    DioException(response: final response) when response?.statusCode == 403 =>
      'Akses dataset ditolak untuk akun ini.',
    DioException(response: final response) when response?.statusCode == 404 =>
      'Dataset tidak ditemukan. Muat ulang daftar dataset.',
    _ => 'Dataset tidak dapat dimuat. Periksa koneksi dan coba lagi.',
  };

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _session.removeListener(_sessionChanged);
    super.dispose();
  }
}
