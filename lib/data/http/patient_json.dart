import 'package:myapp/domain/models/patient.dart';

/// Maps a backend patient JSON object to the domain model.
///
/// NOTE: the UI's Patient.id carries the human-readable code (TB000001) —
/// same as the mock data. The server-side UUID becomes relevant in FASE 4
/// when local writes must reference server rows; the local DB will keep both.
Patient patientFromJson(Map<String, dynamic> json) {
  return Patient(
    id: json['code'] as String,
    name: json['name'] as String,
    age: json['age'] as int,
    gender: json['gender'] as String,
    status: json['status'] as String? ?? 'Normal',
    confidence: json['confidence'] as int? ?? 0,
    lastVisit: json['last_visit'] as String? ?? '-',
    history: List<String>.from(json['history'] as List? ?? const []),
  );
}
