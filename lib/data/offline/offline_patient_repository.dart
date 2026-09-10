import 'package:dio/dio.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/mappers.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/repositories/patient_repository.dart';

/// Offline-first patients: the local cache is the source of truth for the UI,
/// the network is a background refresh. The app stays usable with no signal —
/// the whole point of the tablet being offline-first.
class OfflinePatientRepository implements PatientRepository {
  OfflinePatientRepository(this._db, this._client);

  final AppDatabase _db;
  final ApiClient _client;

  @override
  Future<List<Patient>> getPatients() async {
    final session = _db.sessionGeneration;
    final cached = await _db.allPatients();
    if (session != _db.sessionGeneration) return [];

    // Cache empty (first run) → we must wait for the server to have anything
    // to show. Otherwise serve the cache now and refresh in the background.
    if (cached.isEmpty) {
      await _refresh(session);
      if (session != _db.sessionGeneration) return [];
      final fetched = await _db.allPatients();
      if (session != _db.sessionGeneration) return [];
      return fetched.map(patientFromRow).toList();
    }

    unawaited(_refresh(session));
    return cached.map(patientFromRow).toList();
  }

  /// Pulls the server list into the cache. Network failure is not an error
  /// here — offline is a normal state, and the cache is still valid.
  Future<void> _refresh(int session) async {
    if (session != _db.sessionGeneration) return;
    try {
      final response = await _client.dio.get<List<dynamic>>('/patients');
      final rows = (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(patientRowFromJson)
          .toList();
      await _db.writeForSession(session, () => _db.replacePatientCache(rows));
    } on DioException {
      // Stay on cached data.
    }
  }
}

/// Fire-and-forget without importing dart:async at the call site.
void unawaited(Future<void> future) {
  future.catchError((_) {});
}
