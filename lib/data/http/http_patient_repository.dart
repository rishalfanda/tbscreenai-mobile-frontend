import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/patient_json.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/repositories/patient_repository.dart';

/// Live patients from GET /patients (tenant-scoped by the JWT server-side).
class HttpPatientRepository implements PatientRepository {
  HttpPatientRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Patient>> getPatients() async {
    final response = await _client.dio.get<List<dynamic>>('/patients');
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(patientFromJson)
        .toList();
  }
}
