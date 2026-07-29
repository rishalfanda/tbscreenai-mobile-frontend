import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/domain/models/patient.dart';

/// Server JSON → local row.
LocalPatientsCompanion patientRowFromJson(Map<String, dynamic> json) {
  return LocalPatientsCompanion.insert(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    age: json['age'] as int,
    gender: json['gender'] as String,
    status: Value(json['status'] as String? ?? 'Normal'),
    confidence: Value(json['confidence'] as int?),
    lastVisit: Value(json['last_visit'] as String?),
    history: Value(jsonEncode(json['history'] as List? ?? const [])),
    updatedAt: Value(DateTime.tryParse(json['updated_at'] as String? ?? '')),
  );
}

/// Local row → domain model shown by the UI.
///
/// NOTE: Patient.id carries the human-readable code (TB000001), matching the
/// mock data the screens were built against. The server UUID stays in the
/// local row so sync can still address the right record.
Patient patientFromRow(LocalPatient row) {
  return Patient(
    id: row.code,
    name: row.name,
    age: row.age,
    gender: row.gender,
    status: row.status,
    confidence: row.confidence ?? 0,
    lastVisit: row.lastVisit ?? '-',
    history: (jsonDecode(row.history) as List).cast<String>(),
  );
}

/// Local row → request body for POST /patients (used when flushing the queue).
Map<String, dynamic> patientPayloadFromRow(LocalPatient row) {
  return {
    'code': row.code,
    'name': row.name,
    'age': row.age,
    'gender': row.gender,
    'status': row.status,
    if (row.confidence != null) 'confidence': row.confidence,
    if (row.lastVisit != null) 'last_visit': row.lastVisit,
    'history': jsonDecode(row.history),
  };
}

/// Server JSON → local diagnosis row.
LocalDiagnosesCompanion diagnosisRowFromJson(Map<String, dynamic> json) {
  return LocalDiagnosesCompanion.insert(
    id: json['id'] as String,
    patientId: json['patient_id'] as String,
    isPositive: json['is_positive'] as bool,
    confidence: json['confidence'] as int,
    modelVersion: json['model_version'] as String,
    processingTimeMs: Value(json['processing_time_ms'] as int?),
    findings: Value(jsonEncode(json['findings'] ?? const {})),
    status: Value(json['status'] as String? ?? 'pending'),
    doctorNote: Value(json['doctor_note'] as String?),
    diagnosedAt:
        DateTime.tryParse(json['diagnosed_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt: Value(DateTime.tryParse(json['updated_at'] as String? ?? '')),
  );
}
