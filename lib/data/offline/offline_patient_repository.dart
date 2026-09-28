import 'dart:async';

import 'package:dio/dio.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/mappers.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/repositories/patient_repository.dart';

/// Reactive offline-first patient cache with bounded server pagination.
class OfflinePatientRepository implements PatientRepository {
  OfflinePatientRepository(this._db, this._client);

  static const int _pageSize = 100;
  static const int _maxPages = 100;

  final AppDatabase _db;
  final ApiClient _client;
  Future<_RefreshResult>? _refreshInFlight;

  @override
  Future<List<Patient>> getPatients() async {
    final session = _db.sessionGeneration;
    final cached = await _db.allPatients();
    if (session != _db.sessionGeneration) return [];

    if (cached.isEmpty) {
      await _refresh(session);
      if (session != _db.sessionGeneration) return [];
      return (await _db.allPatients()).map(patientFromRow).toList();
    }

    unawaited(_refresh(session));
    return cached.map(patientFromRow).toList();
  }

  @override
  Stream<PatientListSnapshot> watchPatientList() {
    late final StreamController<PatientListSnapshot> controller;
    StreamSubscription<List<LocalPatient>>? cacheSubscription;
    var refreshSettled = false;
    _RefreshResult? refreshResult;

    PatientListSnapshot snapshot(List<LocalPatient> rows) {
      final patients = rows.map(patientFromRow).toList();
      if (!refreshSettled) {
        return PatientListSnapshot(
          status: patients.isEmpty
              ? PatientListStatus.loading
              : PatientListStatus.ready,
          patients: patients,
        );
      }
      if (refreshResult!.online) {
        return PatientListSnapshot(
          status: patients.isEmpty
              ? PatientListStatus.empty
              : PatientListStatus.ready,
          patients: patients,
        );
      }
      return PatientListSnapshot(
        status: patients.isEmpty
            ? PatientListStatus.error
            : PatientListStatus.offlineCache,
        patients: patients,
        message: refreshResult!.message,
      );
    }

    controller = StreamController<PatientListSnapshot>(
      onListen: () {
        controller.add(const PatientListSnapshot.loading());
        final session = _db.sessionGeneration;
        cacheSubscription = _db.watchPatients().listen(
          (rows) {
            if (!controller.isClosed) controller.add(snapshot(rows));
          },
          onError: (Object error, StackTrace stack) {
            if (!controller.isClosed) {
              controller.add(
                PatientListSnapshot(
                  status: PatientListStatus.error,
                  patients: const [],
                  message: error.toString(),
                ),
              );
            }
          },
        );
        unawaited(() async {
          try {
            refreshResult = await _refresh(session);
            refreshSettled = true;
            if (!controller.isClosed) {
              controller.add(snapshot(await _db.allPatients()));
            }
          } catch (_) {
            refreshSettled = true;
            refreshResult = const _RefreshResult.offline(
              'Patient cache could not be refreshed.',
            );
            if (!controller.isClosed) {
              controller.add(snapshot(await _db.allPatients()));
            }
          }
        }());
      },
      onCancel: () => cacheSubscription?.cancel(),
    );
    return controller.stream;
  }

  Future<_RefreshResult> _refresh(int session) {
    final running = _refreshInFlight;
    if (running != null) return running;
    final future = _fetchAllPages(session);
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  Future<_RefreshResult> _fetchAllPages(int session) async {
    if (session != _db.sessionGeneration) {
      return const _RefreshResult.offline('Session changed');
    }
    try {
      final rows = <LocalPatientsCompanion>[];
      final seenIds = <String>{};
      var offset = 0;
      for (var pageIndex = 0; pageIndex < _maxPages; pageIndex++) {
        final response = await _client.dio.get<List<dynamic>>(
          '/patients',
          queryParameters: {'offset': offset, 'limit': _pageSize},
        );
        final page = (response.data ?? const []).cast<Map<String, dynamic>>();
        var newRows = 0;
        for (final json in page) {
          final id = json['id'];
          if (id is! String || id.isEmpty) {
            throw const FormatException('Patient response contains invalid ID');
          }
          if (seenIds.add(id)) {
            rows.add(patientRowFromJson(json));
            newRows++;
          }
        }
        if (page.length < _pageSize) break;
        if (newRows == 0) {
          throw const FormatException('Patient pagination did not advance');
        }
        offset += page.length;
        if (pageIndex == _maxPages - 1) {
          throw const FormatException('Patient pagination exceeded safety cap');
        }
      }
      if (session != _db.sessionGeneration) {
        return const _RefreshResult.offline('Session changed');
      }
      await _db.writeForSession(session, () => _db.replacePatientCache(rows));
      return const _RefreshResult.online();
    } on DioException catch (error) {
      return _RefreshResult.offline(
        'Server tidak tersedia (${error.type.name}); menampilkan cache lokal.',
      );
    } on FormatException catch (error) {
      return _RefreshResult.offline(error.message);
    }
  }
}

class _RefreshResult {
  const _RefreshResult.online() : online = true, message = null;
  const _RefreshResult.offline(this.message) : online = false;

  final bool online;
  final String? message;
}
