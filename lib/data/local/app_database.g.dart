// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalPatientsTable extends LocalPatients
    with TableInfo<$LocalPatientsTable, LocalPatient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPatientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Normal'),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<int> confidence = GeneratedColumn<int>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastVisitMeta = const VerificationMeta(
    'lastVisit',
  );
  @override
  late final GeneratedColumn<String> lastVisit = GeneratedColumn<String>(
    'last_visit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _historyMeta = const VerificationMeta(
    'history',
  );
  @override
  late final GeneratedColumn<String> history = GeneratedColumn<String>(
    'history',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasConflictMeta = const VerificationMeta(
    'hasConflict',
  );
  @override
  late final GeneratedColumn<bool> hasConflict = GeneratedColumn<bool>(
    'has_conflict',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_conflict" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    age,
    gender,
    status,
    confidence,
    lastVisit,
    history,
    updatedAt,
    hasConflict,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_patients';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPatient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    } else if (isInserting) {
      context.missing(_ageMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    } else if (isInserting) {
      context.missing(_genderMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('last_visit')) {
      context.handle(
        _lastVisitMeta,
        lastVisit.isAcceptableOrUnknown(data['last_visit']!, _lastVisitMeta),
      );
    }
    if (data.containsKey('history')) {
      context.handle(
        _historyMeta,
        history.isAcceptableOrUnknown(data['history']!, _historyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('has_conflict')) {
      context.handle(
        _hasConflictMeta,
        hasConflict.isAcceptableOrUnknown(
          data['has_conflict']!,
          _hasConflictMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPatient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPatient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence'],
      ),
      lastVisit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_visit'],
      ),
      history: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}history'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      hasConflict: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_conflict'],
      )!,
    );
  }

  @override
  $LocalPatientsTable createAlias(String alias) {
    return $LocalPatientsTable(attachedDatabase, alias);
  }
}

class LocalPatient extends DataClass implements Insertable<LocalPatient> {
  /// Server UUID, or a client-generated UUID for rows created offline.
  final String id;
  final String code;
  final String name;
  final int age;
  final String gender;
  final String status;
  final int? confidence;
  final String? lastVisit;

  /// JSON-encoded `List<String>`.
  final String history;

  /// Server-side updated_at this cache was built from — the basis for
  /// conflict detection on the next push.
  final DateTime? updatedAt;

  /// Set when the server rejected our change because its version is newer.
  /// Medical data is never auto-overwritten; a doctor reviews it manually.
  final bool hasConflict;
  const LocalPatient({
    required this.id,
    required this.code,
    required this.name,
    required this.age,
    required this.gender,
    required this.status,
    this.confidence,
    this.lastVisit,
    required this.history,
    this.updatedAt,
    required this.hasConflict,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['age'] = Variable<int>(age);
    map['gender'] = Variable<String>(gender);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<int>(confidence);
    }
    if (!nullToAbsent || lastVisit != null) {
      map['last_visit'] = Variable<String>(lastVisit);
    }
    map['history'] = Variable<String>(history);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['has_conflict'] = Variable<bool>(hasConflict);
    return map;
  }

  LocalPatientsCompanion toCompanion(bool nullToAbsent) {
    return LocalPatientsCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      age: Value(age),
      gender: Value(gender),
      status: Value(status),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      lastVisit: lastVisit == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVisit),
      history: Value(history),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      hasConflict: Value(hasConflict),
    );
  }

  factory LocalPatient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPatient(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      age: serializer.fromJson<int>(json['age']),
      gender: serializer.fromJson<String>(json['gender']),
      status: serializer.fromJson<String>(json['status']),
      confidence: serializer.fromJson<int?>(json['confidence']),
      lastVisit: serializer.fromJson<String?>(json['lastVisit']),
      history: serializer.fromJson<String>(json['history']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      hasConflict: serializer.fromJson<bool>(json['hasConflict']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'age': serializer.toJson<int>(age),
      'gender': serializer.toJson<String>(gender),
      'status': serializer.toJson<String>(status),
      'confidence': serializer.toJson<int?>(confidence),
      'lastVisit': serializer.toJson<String?>(lastVisit),
      'history': serializer.toJson<String>(history),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'hasConflict': serializer.toJson<bool>(hasConflict),
    };
  }

  LocalPatient copyWith({
    String? id,
    String? code,
    String? name,
    int? age,
    String? gender,
    String? status,
    Value<int?> confidence = const Value.absent(),
    Value<String?> lastVisit = const Value.absent(),
    String? history,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? hasConflict,
  }) => LocalPatient(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    age: age ?? this.age,
    gender: gender ?? this.gender,
    status: status ?? this.status,
    confidence: confidence.present ? confidence.value : this.confidence,
    lastVisit: lastVisit.present ? lastVisit.value : this.lastVisit,
    history: history ?? this.history,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    hasConflict: hasConflict ?? this.hasConflict,
  );
  LocalPatient copyWithCompanion(LocalPatientsCompanion data) {
    return LocalPatient(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      age: data.age.present ? data.age.value : this.age,
      gender: data.gender.present ? data.gender.value : this.gender,
      status: data.status.present ? data.status.value : this.status,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      lastVisit: data.lastVisit.present ? data.lastVisit.value : this.lastVisit,
      history: data.history.present ? data.history.value : this.history,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      hasConflict: data.hasConflict.present
          ? data.hasConflict.value
          : this.hasConflict,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPatient(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('age: $age, ')
          ..write('gender: $gender, ')
          ..write('status: $status, ')
          ..write('confidence: $confidence, ')
          ..write('lastVisit: $lastVisit, ')
          ..write('history: $history, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hasConflict: $hasConflict')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    age,
    gender,
    status,
    confidence,
    lastVisit,
    history,
    updatedAt,
    hasConflict,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPatient &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.age == this.age &&
          other.gender == this.gender &&
          other.status == this.status &&
          other.confidence == this.confidence &&
          other.lastVisit == this.lastVisit &&
          other.history == this.history &&
          other.updatedAt == this.updatedAt &&
          other.hasConflict == this.hasConflict);
}

class LocalPatientsCompanion extends UpdateCompanion<LocalPatient> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<int> age;
  final Value<String> gender;
  final Value<String> status;
  final Value<int?> confidence;
  final Value<String?> lastVisit;
  final Value<String> history;
  final Value<DateTime?> updatedAt;
  final Value<bool> hasConflict;
  final Value<int> rowid;
  const LocalPatientsCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.age = const Value.absent(),
    this.gender = const Value.absent(),
    this.status = const Value.absent(),
    this.confidence = const Value.absent(),
    this.lastVisit = const Value.absent(),
    this.history = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.hasConflict = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPatientsCompanion.insert({
    required String id,
    required String code,
    required String name,
    required int age,
    required String gender,
    this.status = const Value.absent(),
    this.confidence = const Value.absent(),
    this.lastVisit = const Value.absent(),
    this.history = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.hasConflict = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       age = Value(age),
       gender = Value(gender);
  static Insertable<LocalPatient> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? age,
    Expression<String>? gender,
    Expression<String>? status,
    Expression<int>? confidence,
    Expression<String>? lastVisit,
    Expression<String>? history,
    Expression<DateTime>? updatedAt,
    Expression<bool>? hasConflict,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (status != null) 'status': status,
      if (confidence != null) 'confidence': confidence,
      if (lastVisit != null) 'last_visit': lastVisit,
      if (history != null) 'history': history,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (hasConflict != null) 'has_conflict': hasConflict,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPatientsCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<int>? age,
    Value<String>? gender,
    Value<String>? status,
    Value<int?>? confidence,
    Value<String?>? lastVisit,
    Value<String>? history,
    Value<DateTime?>? updatedAt,
    Value<bool>? hasConflict,
    Value<int>? rowid,
  }) {
    return LocalPatientsCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      lastVisit: lastVisit ?? this.lastVisit,
      history: history ?? this.history,
      updatedAt: updatedAt ?? this.updatedAt,
      hasConflict: hasConflict ?? this.hasConflict,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<int>(confidence.value);
    }
    if (lastVisit.present) {
      map['last_visit'] = Variable<String>(lastVisit.value);
    }
    if (history.present) {
      map['history'] = Variable<String>(history.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (hasConflict.present) {
      map['has_conflict'] = Variable<bool>(hasConflict.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPatientsCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('age: $age, ')
          ..write('gender: $gender, ')
          ..write('status: $status, ')
          ..write('confidence: $confidence, ')
          ..write('lastVisit: $lastVisit, ')
          ..write('history: $history, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hasConflict: $hasConflict, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDiagnosesTable extends LocalDiagnoses
    with TableInfo<$LocalDiagnosesTable, LocalDiagnose> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDiagnosesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _patientIdMeta = const VerificationMeta(
    'patientId',
  );
  @override
  late final GeneratedColumn<String> patientId = GeneratedColumn<String>(
    'patient_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPositiveMeta = const VerificationMeta(
    'isPositive',
  );
  @override
  late final GeneratedColumn<bool> isPositive = GeneratedColumn<bool>(
    'is_positive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_positive" IN (0, 1))',
    ),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<int> confidence = GeneratedColumn<int>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelVersionMeta = const VerificationMeta(
    'modelVersion',
  );
  @override
  late final GeneratedColumn<String> modelVersion = GeneratedColumn<String>(
    'model_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processingTimeMsMeta = const VerificationMeta(
    'processingTimeMs',
  );
  @override
  late final GeneratedColumn<int> processingTimeMs = GeneratedColumn<int>(
    'processing_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _findingsMeta = const VerificationMeta(
    'findings',
  );
  @override
  late final GeneratedColumn<String> findings = GeneratedColumn<String>(
    'findings',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _doctorNoteMeta = const VerificationMeta(
    'doctorNote',
  );
  @override
  late final GeneratedColumn<String> doctorNote = GeneratedColumn<String>(
    'doctor_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diagnosedAtMeta = const VerificationMeta(
    'diagnosedAt',
  );
  @override
  late final GeneratedColumn<DateTime> diagnosedAt = GeneratedColumn<DateTime>(
    'diagnosed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasConflictMeta = const VerificationMeta(
    'hasConflict',
  );
  @override
  late final GeneratedColumn<bool> hasConflict = GeneratedColumn<bool>(
    'has_conflict',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_conflict" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    patientId,
    isPositive,
    confidence,
    modelVersion,
    processingTimeMs,
    findings,
    status,
    doctorNote,
    diagnosedAt,
    updatedAt,
    hasConflict,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_diagnoses';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDiagnose> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('patient_id')) {
      context.handle(
        _patientIdMeta,
        patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_patientIdMeta);
    }
    if (data.containsKey('is_positive')) {
      context.handle(
        _isPositiveMeta,
        isPositive.isAcceptableOrUnknown(data['is_positive']!, _isPositiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isPositiveMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('model_version')) {
      context.handle(
        _modelVersionMeta,
        modelVersion.isAcceptableOrUnknown(
          data['model_version']!,
          _modelVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelVersionMeta);
    }
    if (data.containsKey('processing_time_ms')) {
      context.handle(
        _processingTimeMsMeta,
        processingTimeMs.isAcceptableOrUnknown(
          data['processing_time_ms']!,
          _processingTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('findings')) {
      context.handle(
        _findingsMeta,
        findings.isAcceptableOrUnknown(data['findings']!, _findingsMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('doctor_note')) {
      context.handle(
        _doctorNoteMeta,
        doctorNote.isAcceptableOrUnknown(data['doctor_note']!, _doctorNoteMeta),
      );
    }
    if (data.containsKey('diagnosed_at')) {
      context.handle(
        _diagnosedAtMeta,
        diagnosedAt.isAcceptableOrUnknown(
          data['diagnosed_at']!,
          _diagnosedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_diagnosedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('has_conflict')) {
      context.handle(
        _hasConflictMeta,
        hasConflict.isAcceptableOrUnknown(
          data['has_conflict']!,
          _hasConflictMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalDiagnose map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDiagnose(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      patientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}patient_id'],
      )!,
      isPositive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_positive'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confidence'],
      )!,
      modelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_version'],
      )!,
      processingTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}processing_time_ms'],
      ),
      findings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}findings'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      doctorNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}doctor_note'],
      ),
      diagnosedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}diagnosed_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      hasConflict: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_conflict'],
      )!,
    );
  }

  @override
  $LocalDiagnosesTable createAlias(String alias) {
    return $LocalDiagnosesTable(attachedDatabase, alias);
  }
}

class LocalDiagnose extends DataClass implements Insertable<LocalDiagnose> {
  final String id;
  final String patientId;
  final bool isPositive;
  final int confidence;
  final String modelVersion;
  final int? processingTimeMs;

  /// JSON-encoded findings map (consolidation, cavity, effusion, ...).
  final String findings;
  final String status;
  final String? doctorNote;
  final DateTime diagnosedAt;
  final DateTime? updatedAt;
  final bool hasConflict;
  const LocalDiagnose({
    required this.id,
    required this.patientId,
    required this.isPositive,
    required this.confidence,
    required this.modelVersion,
    this.processingTimeMs,
    required this.findings,
    required this.status,
    this.doctorNote,
    required this.diagnosedAt,
    this.updatedAt,
    required this.hasConflict,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['patient_id'] = Variable<String>(patientId);
    map['is_positive'] = Variable<bool>(isPositive);
    map['confidence'] = Variable<int>(confidence);
    map['model_version'] = Variable<String>(modelVersion);
    if (!nullToAbsent || processingTimeMs != null) {
      map['processing_time_ms'] = Variable<int>(processingTimeMs);
    }
    map['findings'] = Variable<String>(findings);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || doctorNote != null) {
      map['doctor_note'] = Variable<String>(doctorNote);
    }
    map['diagnosed_at'] = Variable<DateTime>(diagnosedAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    map['has_conflict'] = Variable<bool>(hasConflict);
    return map;
  }

  LocalDiagnosesCompanion toCompanion(bool nullToAbsent) {
    return LocalDiagnosesCompanion(
      id: Value(id),
      patientId: Value(patientId),
      isPositive: Value(isPositive),
      confidence: Value(confidence),
      modelVersion: Value(modelVersion),
      processingTimeMs: processingTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(processingTimeMs),
      findings: Value(findings),
      status: Value(status),
      doctorNote: doctorNote == null && nullToAbsent
          ? const Value.absent()
          : Value(doctorNote),
      diagnosedAt: Value(diagnosedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      hasConflict: Value(hasConflict),
    );
  }

  factory LocalDiagnose.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDiagnose(
      id: serializer.fromJson<String>(json['id']),
      patientId: serializer.fromJson<String>(json['patientId']),
      isPositive: serializer.fromJson<bool>(json['isPositive']),
      confidence: serializer.fromJson<int>(json['confidence']),
      modelVersion: serializer.fromJson<String>(json['modelVersion']),
      processingTimeMs: serializer.fromJson<int?>(json['processingTimeMs']),
      findings: serializer.fromJson<String>(json['findings']),
      status: serializer.fromJson<String>(json['status']),
      doctorNote: serializer.fromJson<String?>(json['doctorNote']),
      diagnosedAt: serializer.fromJson<DateTime>(json['diagnosedAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      hasConflict: serializer.fromJson<bool>(json['hasConflict']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'patientId': serializer.toJson<String>(patientId),
      'isPositive': serializer.toJson<bool>(isPositive),
      'confidence': serializer.toJson<int>(confidence),
      'modelVersion': serializer.toJson<String>(modelVersion),
      'processingTimeMs': serializer.toJson<int?>(processingTimeMs),
      'findings': serializer.toJson<String>(findings),
      'status': serializer.toJson<String>(status),
      'doctorNote': serializer.toJson<String?>(doctorNote),
      'diagnosedAt': serializer.toJson<DateTime>(diagnosedAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'hasConflict': serializer.toJson<bool>(hasConflict),
    };
  }

  LocalDiagnose copyWith({
    String? id,
    String? patientId,
    bool? isPositive,
    int? confidence,
    String? modelVersion,
    Value<int?> processingTimeMs = const Value.absent(),
    String? findings,
    String? status,
    Value<String?> doctorNote = const Value.absent(),
    DateTime? diagnosedAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    bool? hasConflict,
  }) => LocalDiagnose(
    id: id ?? this.id,
    patientId: patientId ?? this.patientId,
    isPositive: isPositive ?? this.isPositive,
    confidence: confidence ?? this.confidence,
    modelVersion: modelVersion ?? this.modelVersion,
    processingTimeMs: processingTimeMs.present
        ? processingTimeMs.value
        : this.processingTimeMs,
    findings: findings ?? this.findings,
    status: status ?? this.status,
    doctorNote: doctorNote.present ? doctorNote.value : this.doctorNote,
    diagnosedAt: diagnosedAt ?? this.diagnosedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    hasConflict: hasConflict ?? this.hasConflict,
  );
  LocalDiagnose copyWithCompanion(LocalDiagnosesCompanion data) {
    return LocalDiagnose(
      id: data.id.present ? data.id.value : this.id,
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      isPositive: data.isPositive.present
          ? data.isPositive.value
          : this.isPositive,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      modelVersion: data.modelVersion.present
          ? data.modelVersion.value
          : this.modelVersion,
      processingTimeMs: data.processingTimeMs.present
          ? data.processingTimeMs.value
          : this.processingTimeMs,
      findings: data.findings.present ? data.findings.value : this.findings,
      status: data.status.present ? data.status.value : this.status,
      doctorNote: data.doctorNote.present
          ? data.doctorNote.value
          : this.doctorNote,
      diagnosedAt: data.diagnosedAt.present
          ? data.diagnosedAt.value
          : this.diagnosedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      hasConflict: data.hasConflict.present
          ? data.hasConflict.value
          : this.hasConflict,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDiagnose(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('isPositive: $isPositive, ')
          ..write('confidence: $confidence, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('processingTimeMs: $processingTimeMs, ')
          ..write('findings: $findings, ')
          ..write('status: $status, ')
          ..write('doctorNote: $doctorNote, ')
          ..write('diagnosedAt: $diagnosedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hasConflict: $hasConflict')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    patientId,
    isPositive,
    confidence,
    modelVersion,
    processingTimeMs,
    findings,
    status,
    doctorNote,
    diagnosedAt,
    updatedAt,
    hasConflict,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDiagnose &&
          other.id == this.id &&
          other.patientId == this.patientId &&
          other.isPositive == this.isPositive &&
          other.confidence == this.confidence &&
          other.modelVersion == this.modelVersion &&
          other.processingTimeMs == this.processingTimeMs &&
          other.findings == this.findings &&
          other.status == this.status &&
          other.doctorNote == this.doctorNote &&
          other.diagnosedAt == this.diagnosedAt &&
          other.updatedAt == this.updatedAt &&
          other.hasConflict == this.hasConflict);
}

class LocalDiagnosesCompanion extends UpdateCompanion<LocalDiagnose> {
  final Value<String> id;
  final Value<String> patientId;
  final Value<bool> isPositive;
  final Value<int> confidence;
  final Value<String> modelVersion;
  final Value<int?> processingTimeMs;
  final Value<String> findings;
  final Value<String> status;
  final Value<String?> doctorNote;
  final Value<DateTime> diagnosedAt;
  final Value<DateTime?> updatedAt;
  final Value<bool> hasConflict;
  final Value<int> rowid;
  const LocalDiagnosesCompanion({
    this.id = const Value.absent(),
    this.patientId = const Value.absent(),
    this.isPositive = const Value.absent(),
    this.confidence = const Value.absent(),
    this.modelVersion = const Value.absent(),
    this.processingTimeMs = const Value.absent(),
    this.findings = const Value.absent(),
    this.status = const Value.absent(),
    this.doctorNote = const Value.absent(),
    this.diagnosedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.hasConflict = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDiagnosesCompanion.insert({
    required String id,
    required String patientId,
    required bool isPositive,
    required int confidence,
    required String modelVersion,
    this.processingTimeMs = const Value.absent(),
    this.findings = const Value.absent(),
    this.status = const Value.absent(),
    this.doctorNote = const Value.absent(),
    required DateTime diagnosedAt,
    this.updatedAt = const Value.absent(),
    this.hasConflict = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       patientId = Value(patientId),
       isPositive = Value(isPositive),
       confidence = Value(confidence),
       modelVersion = Value(modelVersion),
       diagnosedAt = Value(diagnosedAt);
  static Insertable<LocalDiagnose> custom({
    Expression<String>? id,
    Expression<String>? patientId,
    Expression<bool>? isPositive,
    Expression<int>? confidence,
    Expression<String>? modelVersion,
    Expression<int>? processingTimeMs,
    Expression<String>? findings,
    Expression<String>? status,
    Expression<String>? doctorNote,
    Expression<DateTime>? diagnosedAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? hasConflict,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (patientId != null) 'patient_id': patientId,
      if (isPositive != null) 'is_positive': isPositive,
      if (confidence != null) 'confidence': confidence,
      if (modelVersion != null) 'model_version': modelVersion,
      if (processingTimeMs != null) 'processing_time_ms': processingTimeMs,
      if (findings != null) 'findings': findings,
      if (status != null) 'status': status,
      if (doctorNote != null) 'doctor_note': doctorNote,
      if (diagnosedAt != null) 'diagnosed_at': diagnosedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (hasConflict != null) 'has_conflict': hasConflict,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDiagnosesCompanion copyWith({
    Value<String>? id,
    Value<String>? patientId,
    Value<bool>? isPositive,
    Value<int>? confidence,
    Value<String>? modelVersion,
    Value<int?>? processingTimeMs,
    Value<String>? findings,
    Value<String>? status,
    Value<String?>? doctorNote,
    Value<DateTime>? diagnosedAt,
    Value<DateTime?>? updatedAt,
    Value<bool>? hasConflict,
    Value<int>? rowid,
  }) {
    return LocalDiagnosesCompanion(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      isPositive: isPositive ?? this.isPositive,
      confidence: confidence ?? this.confidence,
      modelVersion: modelVersion ?? this.modelVersion,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      findings: findings ?? this.findings,
      status: status ?? this.status,
      doctorNote: doctorNote ?? this.doctorNote,
      diagnosedAt: diagnosedAt ?? this.diagnosedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasConflict: hasConflict ?? this.hasConflict,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (patientId.present) {
      map['patient_id'] = Variable<String>(patientId.value);
    }
    if (isPositive.present) {
      map['is_positive'] = Variable<bool>(isPositive.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<int>(confidence.value);
    }
    if (modelVersion.present) {
      map['model_version'] = Variable<String>(modelVersion.value);
    }
    if (processingTimeMs.present) {
      map['processing_time_ms'] = Variable<int>(processingTimeMs.value);
    }
    if (findings.present) {
      map['findings'] = Variable<String>(findings.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (doctorNote.present) {
      map['doctor_note'] = Variable<String>(doctorNote.value);
    }
    if (diagnosedAt.present) {
      map['diagnosed_at'] = Variable<DateTime>(diagnosedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (hasConflict.present) {
      map['has_conflict'] = Variable<bool>(hasConflict.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDiagnosesCompanion(')
          ..write('id: $id, ')
          ..write('patientId: $patientId, ')
          ..write('isPositive: $isPositive, ')
          ..write('confidence: $confidence, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('processingTimeMs: $processingTimeMs, ')
          ..write('findings: $findings, ')
          ..write('status: $status, ')
          ..write('doctorNote: $doctorNote, ')
          ..write('diagnosedAt: $diagnosedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('hasConflict: $hasConflict, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientOpIdMeta = const VerificationMeta(
    'clientOpId',
  );
  @override
  late final GeneratedColumn<String> clientOpId = GeneratedColumn<String>(
    'client_op_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUpdatedAtMeta = const VerificationMeta(
    'baseUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> baseUpdatedAt =
      GeneratedColumn<DateTime>(
        'base_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientOpId,
    entityType,
    entityId,
    operation,
    payload,
    baseUpdatedAt,
    status,
    detail,
    createdAt,
    syncedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_op_id')) {
      context.handle(
        _clientOpIdMeta,
        clientOpId.isAcceptableOrUnknown(
          data['client_op_id']!,
          _clientOpIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientOpIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('base_updated_at')) {
      context.handle(
        _baseUpdatedAtMeta,
        baseUpdatedAt.isAcceptableOrUnknown(
          data['base_updated_at']!,
          _baseUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientOpId};
  @override
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      clientOpId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_op_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      baseUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}base_updated_at'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  /// Client-generated UUID sent as `client_op_id`. The backend's
  /// UNIQUE(tenant_id, client_op_id) makes a retry a no-op instead of a
  /// duplicate — so this column IS the idempotency key.
  final String clientOpId;

  /// 'patient' | 'diagnosis'
  final String entityType;
  final String entityId;

  /// 'create' | 'update'
  final String operation;

  /// JSON-encoded request body.
  final String payload;

  /// Server version the edit was based on — omitted for creates.
  final DateTime? baseUpdatedAt;

  /// pending | synced | conflict | failed
  final String status;

  /// Server explanation for conflict/failed.
  final String? detail;
  final DateTime createdAt;
  final DateTime? syncedAt;
  const SyncQueueData({
    required this.clientOpId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.baseUpdatedAt,
    required this.status,
    this.detail,
    required this.createdAt,
    this.syncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_op_id'] = Variable<String>(clientOpId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || baseUpdatedAt != null) {
      map['base_updated_at'] = Variable<DateTime>(baseUpdatedAt);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      clientOpId: Value(clientOpId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(payload),
      baseUpdatedAt: baseUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(baseUpdatedAt),
      status: Value(status),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory SyncQueueData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      clientOpId: serializer.fromJson<String>(json['clientOpId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      baseUpdatedAt: serializer.fromJson<DateTime?>(json['baseUpdatedAt']),
      status: serializer.fromJson<String>(json['status']),
      detail: serializer.fromJson<String?>(json['detail']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientOpId': serializer.toJson<String>(clientOpId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'baseUpdatedAt': serializer.toJson<DateTime?>(baseUpdatedAt),
      'status': serializer.toJson<String>(status),
      'detail': serializer.toJson<String?>(detail),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
    };
  }

  SyncQueueData copyWith({
    String? clientOpId,
    String? entityType,
    String? entityId,
    String? operation,
    String? payload,
    Value<DateTime?> baseUpdatedAt = const Value.absent(),
    String? status,
    Value<String?> detail = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> syncedAt = const Value.absent(),
  }) => SyncQueueData(
    clientOpId: clientOpId ?? this.clientOpId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    baseUpdatedAt: baseUpdatedAt.present
        ? baseUpdatedAt.value
        : this.baseUpdatedAt,
    status: status ?? this.status,
    detail: detail.present ? detail.value : this.detail,
    createdAt: createdAt ?? this.createdAt,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
  );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      clientOpId: data.clientOpId.present
          ? data.clientOpId.value
          : this.clientOpId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      baseUpdatedAt: data.baseUpdatedAt.present
          ? data.baseUpdatedAt.value
          : this.baseUpdatedAt,
      status: data.status.present ? data.status.value : this.status,
      detail: data.detail.present ? data.detail.value : this.detail,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('clientOpId: $clientOpId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('baseUpdatedAt: $baseUpdatedAt, ')
          ..write('status: $status, ')
          ..write('detail: $detail, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    clientOpId,
    entityType,
    entityId,
    operation,
    payload,
    baseUpdatedAt,
    status,
    detail,
    createdAt,
    syncedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.clientOpId == this.clientOpId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.baseUpdatedAt == this.baseUpdatedAt &&
          other.status == this.status &&
          other.detail == this.detail &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<String> clientOpId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<DateTime?> baseUpdatedAt;
  final Value<String> status;
  final Value<String?> detail;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<int> rowid;
  const SyncQueueCompanion({
    this.clientOpId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.baseUpdatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.detail = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    required String clientOpId,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
    this.baseUpdatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.detail = const Value.absent(),
    required DateTime createdAt,
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : clientOpId = Value(clientOpId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<SyncQueueData> custom({
    Expression<String>? clientOpId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<DateTime>? baseUpdatedAt,
    Expression<String>? status,
    Expression<String>? detail,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientOpId != null) 'client_op_id': clientOpId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (baseUpdatedAt != null) 'base_updated_at': baseUpdatedAt,
      if (status != null) 'status': status,
      if (detail != null) 'detail': detail,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncQueueCompanion copyWith({
    Value<String>? clientOpId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? payload,
    Value<DateTime?>? baseUpdatedAt,
    Value<String>? status,
    Value<String?>? detail,
    Value<DateTime>? createdAt,
    Value<DateTime?>? syncedAt,
    Value<int>? rowid,
  }) {
    return SyncQueueCompanion(
      clientOpId: clientOpId ?? this.clientOpId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      baseUpdatedAt: baseUpdatedAt ?? this.baseUpdatedAt,
      status: status ?? this.status,
      detail: detail ?? this.detail,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientOpId.present) {
      map['client_op_id'] = Variable<String>(clientOpId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (baseUpdatedAt.present) {
      map['base_updated_at'] = Variable<DateTime>(baseUpdatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('clientOpId: $clientOpId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('baseUpdatedAt: $baseUpdatedAt, ')
          ..write('status: $status, ')
          ..write('detail: $detail, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalPatientsTable localPatients = $LocalPatientsTable(this);
  late final $LocalDiagnosesTable localDiagnoses = $LocalDiagnosesTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localPatients,
    localDiagnoses,
    syncQueue,
    appSettings,
  ];
}

typedef $$LocalPatientsTableCreateCompanionBuilder =
    LocalPatientsCompanion Function({
      required String id,
      required String code,
      required String name,
      required int age,
      required String gender,
      Value<String> status,
      Value<int?> confidence,
      Value<String?> lastVisit,
      Value<String> history,
      Value<DateTime?> updatedAt,
      Value<bool> hasConflict,
      Value<int> rowid,
    });
typedef $$LocalPatientsTableUpdateCompanionBuilder =
    LocalPatientsCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<int> age,
      Value<String> gender,
      Value<String> status,
      Value<int?> confidence,
      Value<String?> lastVisit,
      Value<String> history,
      Value<DateTime?> updatedAt,
      Value<bool> hasConflict,
      Value<int> rowid,
    });

class $$LocalPatientsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPatientsTable> {
  $$LocalPatientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastVisit => $composableBuilder(
    column: $table.lastVisit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get history => $composableBuilder(
    column: $table.history,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalPatientsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPatientsTable> {
  $$LocalPatientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastVisit => $composableBuilder(
    column: $table.lastVisit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get history => $composableBuilder(
    column: $table.history,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalPatientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPatientsTable> {
  $$LocalPatientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastVisit =>
      $composableBuilder(column: $table.lastVisit, builder: (column) => column);

  GeneratedColumn<String> get history =>
      $composableBuilder(column: $table.history, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => column,
  );
}

class $$LocalPatientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPatientsTable,
          LocalPatient,
          $$LocalPatientsTableFilterComposer,
          $$LocalPatientsTableOrderingComposer,
          $$LocalPatientsTableAnnotationComposer,
          $$LocalPatientsTableCreateCompanionBuilder,
          $$LocalPatientsTableUpdateCompanionBuilder,
          (
            LocalPatient,
            BaseReferences<_$AppDatabase, $LocalPatientsTable, LocalPatient>,
          ),
          LocalPatient,
          PrefetchHooks Function()
        > {
  $$LocalPatientsTableTableManager(_$AppDatabase db, $LocalPatientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPatientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPatientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPatientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> confidence = const Value.absent(),
                Value<String?> lastVisit = const Value.absent(),
                Value<String> history = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> hasConflict = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPatientsCompanion(
                id: id,
                code: code,
                name: name,
                age: age,
                gender: gender,
                status: status,
                confidence: confidence,
                lastVisit: lastVisit,
                history: history,
                updatedAt: updatedAt,
                hasConflict: hasConflict,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                required int age,
                required String gender,
                Value<String> status = const Value.absent(),
                Value<int?> confidence = const Value.absent(),
                Value<String?> lastVisit = const Value.absent(),
                Value<String> history = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> hasConflict = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalPatientsCompanion.insert(
                id: id,
                code: code,
                name: name,
                age: age,
                gender: gender,
                status: status,
                confidence: confidence,
                lastVisit: lastVisit,
                history: history,
                updatedAt: updatedAt,
                hasConflict: hasConflict,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalPatientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPatientsTable,
      LocalPatient,
      $$LocalPatientsTableFilterComposer,
      $$LocalPatientsTableOrderingComposer,
      $$LocalPatientsTableAnnotationComposer,
      $$LocalPatientsTableCreateCompanionBuilder,
      $$LocalPatientsTableUpdateCompanionBuilder,
      (
        LocalPatient,
        BaseReferences<_$AppDatabase, $LocalPatientsTable, LocalPatient>,
      ),
      LocalPatient,
      PrefetchHooks Function()
    >;
typedef $$LocalDiagnosesTableCreateCompanionBuilder =
    LocalDiagnosesCompanion Function({
      required String id,
      required String patientId,
      required bool isPositive,
      required int confidence,
      required String modelVersion,
      Value<int?> processingTimeMs,
      Value<String> findings,
      Value<String> status,
      Value<String?> doctorNote,
      required DateTime diagnosedAt,
      Value<DateTime?> updatedAt,
      Value<bool> hasConflict,
      Value<int> rowid,
    });
typedef $$LocalDiagnosesTableUpdateCompanionBuilder =
    LocalDiagnosesCompanion Function({
      Value<String> id,
      Value<String> patientId,
      Value<bool> isPositive,
      Value<int> confidence,
      Value<String> modelVersion,
      Value<int?> processingTimeMs,
      Value<String> findings,
      Value<String> status,
      Value<String?> doctorNote,
      Value<DateTime> diagnosedAt,
      Value<DateTime?> updatedAt,
      Value<bool> hasConflict,
      Value<int> rowid,
    });

class $$LocalDiagnosesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDiagnosesTable> {
  $$LocalDiagnosesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPositive => $composableBuilder(
    column: $table.isPositive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get processingTimeMs => $composableBuilder(
    column: $table.processingTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get findings => $composableBuilder(
    column: $table.findings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doctorNote => $composableBuilder(
    column: $table.doctorNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get diagnosedAt => $composableBuilder(
    column: $table.diagnosedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalDiagnosesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDiagnosesTable> {
  $$LocalDiagnosesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPositive => $composableBuilder(
    column: $table.isPositive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get processingTimeMs => $composableBuilder(
    column: $table.processingTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get findings => $composableBuilder(
    column: $table.findings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doctorNote => $composableBuilder(
    column: $table.doctorNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get diagnosedAt => $composableBuilder(
    column: $table.diagnosedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDiagnosesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDiagnosesTable> {
  $$LocalDiagnosesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get patientId =>
      $composableBuilder(column: $table.patientId, builder: (column) => column);

  GeneratedColumn<bool> get isPositive => $composableBuilder(
    column: $table.isPositive,
    builder: (column) => column,
  );

  GeneratedColumn<int> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get processingTimeMs => $composableBuilder(
    column: $table.processingTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get findings =>
      $composableBuilder(column: $table.findings, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get doctorNote => $composableBuilder(
    column: $table.doctorNote,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get diagnosedAt => $composableBuilder(
    column: $table.diagnosedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get hasConflict => $composableBuilder(
    column: $table.hasConflict,
    builder: (column) => column,
  );
}

class $$LocalDiagnosesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalDiagnosesTable,
          LocalDiagnose,
          $$LocalDiagnosesTableFilterComposer,
          $$LocalDiagnosesTableOrderingComposer,
          $$LocalDiagnosesTableAnnotationComposer,
          $$LocalDiagnosesTableCreateCompanionBuilder,
          $$LocalDiagnosesTableUpdateCompanionBuilder,
          (
            LocalDiagnose,
            BaseReferences<_$AppDatabase, $LocalDiagnosesTable, LocalDiagnose>,
          ),
          LocalDiagnose,
          PrefetchHooks Function()
        > {
  $$LocalDiagnosesTableTableManager(
    _$AppDatabase db,
    $LocalDiagnosesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDiagnosesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDiagnosesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDiagnosesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> patientId = const Value.absent(),
                Value<bool> isPositive = const Value.absent(),
                Value<int> confidence = const Value.absent(),
                Value<String> modelVersion = const Value.absent(),
                Value<int?> processingTimeMs = const Value.absent(),
                Value<String> findings = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> doctorNote = const Value.absent(),
                Value<DateTime> diagnosedAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> hasConflict = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDiagnosesCompanion(
                id: id,
                patientId: patientId,
                isPositive: isPositive,
                confidence: confidence,
                modelVersion: modelVersion,
                processingTimeMs: processingTimeMs,
                findings: findings,
                status: status,
                doctorNote: doctorNote,
                diagnosedAt: diagnosedAt,
                updatedAt: updatedAt,
                hasConflict: hasConflict,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String patientId,
                required bool isPositive,
                required int confidence,
                required String modelVersion,
                Value<int?> processingTimeMs = const Value.absent(),
                Value<String> findings = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> doctorNote = const Value.absent(),
                required DateTime diagnosedAt,
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<bool> hasConflict = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDiagnosesCompanion.insert(
                id: id,
                patientId: patientId,
                isPositive: isPositive,
                confidence: confidence,
                modelVersion: modelVersion,
                processingTimeMs: processingTimeMs,
                findings: findings,
                status: status,
                doctorNote: doctorNote,
                diagnosedAt: diagnosedAt,
                updatedAt: updatedAt,
                hasConflict: hasConflict,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalDiagnosesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalDiagnosesTable,
      LocalDiagnose,
      $$LocalDiagnosesTableFilterComposer,
      $$LocalDiagnosesTableOrderingComposer,
      $$LocalDiagnosesTableAnnotationComposer,
      $$LocalDiagnosesTableCreateCompanionBuilder,
      $$LocalDiagnosesTableUpdateCompanionBuilder,
      (
        LocalDiagnose,
        BaseReferences<_$AppDatabase, $LocalDiagnosesTable, LocalDiagnose>,
      ),
      LocalDiagnose,
      PrefetchHooks Function()
    >;
typedef $$SyncQueueTableCreateCompanionBuilder =
    SyncQueueCompanion Function({
      required String clientOpId,
      required String entityType,
      required String entityId,
      required String operation,
      required String payload,
      Value<DateTime?> baseUpdatedAt,
      Value<String> status,
      Value<String?> detail,
      required DateTime createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });
typedef $$SyncQueueTableUpdateCompanionBuilder =
    SyncQueueCompanion Function({
      Value<String> clientOpId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<String> payload,
      Value<DateTime?> baseUpdatedAt,
      Value<String> status,
      Value<String?> detail,
      Value<DateTime> createdAt,
      Value<DateTime?> syncedAt,
      Value<int> rowid,
    });

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientOpId => $composableBuilder(
    column: $table.clientOpId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get baseUpdatedAt => $composableBuilder(
    column: $table.baseUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientOpId => $composableBuilder(
    column: $table.clientOpId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get baseUpdatedAt => $composableBuilder(
    column: $table.baseUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientOpId => $composableBuilder(
    column: $table.clientOpId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get baseUpdatedAt => $composableBuilder(
    column: $table.baseUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$SyncQueueTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueTable,
          SyncQueueData,
          $$SyncQueueTableFilterComposer,
          $$SyncQueueTableOrderingComposer,
          $$SyncQueueTableAnnotationComposer,
          $$SyncQueueTableCreateCompanionBuilder,
          $$SyncQueueTableUpdateCompanionBuilder,
          (
            SyncQueueData,
            BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
          ),
          SyncQueueData,
          PrefetchHooks Function()
        > {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clientOpId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime?> baseUpdatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion(
                clientOpId: clientOpId,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payload: payload,
                baseUpdatedAt: baseUpdatedAt,
                status: status,
                detail: detail,
                createdAt: createdAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientOpId,
                required String entityType,
                required String entityId,
                required String operation,
                required String payload,
                Value<DateTime?> baseUpdatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncQueueCompanion.insert(
                clientOpId: clientOpId,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payload: payload,
                baseUpdatedAt: baseUpdatedAt,
                status: status,
                detail: detail,
                createdAt: createdAt,
                syncedAt: syncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueTable,
      SyncQueueData,
      $$SyncQueueTableFilterComposer,
      $$SyncQueueTableOrderingComposer,
      $$SyncQueueTableAnnotationComposer,
      $$SyncQueueTableCreateCompanionBuilder,
      $$SyncQueueTableUpdateCompanionBuilder,
      (
        SyncQueueData,
        BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>,
      ),
      SyncQueueData,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalPatientsTableTableManager get localPatients =>
      $$LocalPatientsTableTableManager(_db, _db.localPatients);
  $$LocalDiagnosesTableTableManager get localDiagnoses =>
      $$LocalDiagnosesTableTableManager(_db, _db.localDiagnoses);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
