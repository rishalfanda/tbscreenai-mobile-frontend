import 'package:myapp/domain/models/patient.dart';

/// Contract for patient data access.
abstract class PatientRepository {
  Future<List<Patient>> getPatients();
}
