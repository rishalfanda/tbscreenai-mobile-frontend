import 'package:flutter/foundation.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/repositories/patient_repository.dart';

/// Mock patients — same list the screens rendered before, returned
/// synchronously so there is no loading flash.
class MockPatientRepository implements PatientRepository {
  @override
  Future<List<Patient>> getPatients() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.patients));
}
