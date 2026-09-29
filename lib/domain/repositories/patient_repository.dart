import 'package:myapp/domain/models/patient.dart';

enum PatientListStatus { loading, ready, empty, offlineCache, error }

class PatientListSnapshot {
  const PatientListSnapshot({
    required this.status,
    required this.patients,
    this.message,
  });

  const PatientListSnapshot.loading()
    : status = PatientListStatus.loading,
      patients = const [],
      message = null;

  final PatientListStatus status;
  final List<Patient> patients;
  final String? message;
}

abstract class PatientRepository {
  Future<List<Patient>> getPatients();

  /// Mock/simple repositories emit one snapshot. Offline implementations
  /// override this with a reactive Drift stream and network source status.
  Stream<PatientListSnapshot> watchPatientList() async* {
    yield const PatientListSnapshot.loading();
    try {
      final patients = await getPatients();
      yield PatientListSnapshot(
        status: PatientListStatus.ready,
        patients: patients,
      );
    } catch (error) {
      yield PatientListSnapshot(
        status: PatientListStatus.error,
        patients: const [],
        message: error.toString(),
      );
    }
  }
}
