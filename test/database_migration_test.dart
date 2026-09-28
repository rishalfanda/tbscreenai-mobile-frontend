import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:myapp/data/local/app_database.dart';

void _createV1(File file, {String? owner, bool complete = true}) {
  final raw = sqlite3.open(file.path);
  try {
    raw.execute('''
      CREATE TABLE app_settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    raw.execute('''
      CREATE TABLE sync_queue (
        client_op_id TEXT NOT NULL PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        base_updated_at INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        detail TEXT NULL,
        created_at INTEGER NOT NULL,
        synced_at INTEGER NULL
      )
    ''');
    if (complete) {
      raw.execute('''
        CREATE TABLE local_patients (
          id TEXT NOT NULL PRIMARY KEY,
          code TEXT NOT NULL,
          name TEXT NOT NULL,
          age INTEGER NOT NULL,
          gender TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'Normal',
          confidence INTEGER NULL,
          last_visit TEXT NULL,
          history TEXT NOT NULL DEFAULT '[]',
          updated_at INTEGER NULL,
          has_conflict INTEGER NOT NULL DEFAULT 0
        )
      ''');
      raw.execute('''
        CREATE TABLE local_diagnoses (
          id TEXT NOT NULL PRIMARY KEY,
          patient_id TEXT NOT NULL,
          is_positive INTEGER NOT NULL,
          confidence INTEGER NOT NULL,
          model_version TEXT NOT NULL,
          processing_time_ms INTEGER NULL,
          findings TEXT NOT NULL DEFAULT '{}',
          status TEXT NOT NULL DEFAULT 'pending',
          doctor_note TEXT NULL,
          diagnosed_at INTEGER NOT NULL,
          updated_at INTEGER NULL,
          has_conflict INTEGER NOT NULL DEFAULT 0
        )
      ''');
      raw.execute(
        "INSERT INTO local_patients "
        "(id, code, name, age, gender, updated_at) "
        "VALUES ('patient-1', 'P1', 'Migrated', 40, 'Male', 1)",
      );
    }
    if (owner != null) {
      raw.execute('INSERT INTO app_settings (key, value) VALUES (?, ?)', [
        kSessionOwner,
        owner,
      ]);
    }
    raw.execute(
      'INSERT INTO sync_queue '
      '(client_op_id, entity_type, entity_id, operation, payload, created_at) '
      "VALUES ('op-1', 'patient', 'patient-1', 'update', '{}', 1)",
    );
    raw.execute('PRAGMA user_version = 1');
  } finally {
    raw.close();
  }
}

void main() {
  test('reopening v2 reclaims an interrupted sending operation', () async {
    final directory = await Directory.systemTemp.createTemp('tbscreen-reopen-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}restart.sqlite',
    );

    final first = AppDatabase(NativeDatabase(file));
    await first.enqueue(
      SyncQueueCompanion.insert(
        clientOpId: 'op-restart',
        entityType: 'patient',
        entityId: 'patient-1',
        operation: 'update',
        payload: '{}',
        createdAt: DateTime.utc(2026, 9, 28),
      ),
    );
    await first.markOpSending('op-restart');
    await first.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final retryable = await reopened.opsWithStatus(syncRetryable);
    expect(retryable.single.clientOpId, 'op-restart');
  });

  test('v1 to v2 preserves and attributes a pending queue', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tbscreen-migrate-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}owner.sqlite');
    _createV1(file, owner: 'hospital:doctor');

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final ops = await db.pendingOps();
    final patient = await db.findPatient('patient-1');

    expect(ops, hasLength(1));
    expect(ops.single.clientOpId, 'op-1');
    expect(ops.single.tenantId, 'hospital');
    expect(ops.single.userId, 'doctor');
    expect(ops.single.deviceId, isNotEmpty);
    expect(patient?.tenantId, 'hospital');
    expect(patient?.userId, 'doctor');
    expect(await db.getSetting(kAccessToken), isNull);
  });

  test('v1 queue without an owner is quarantined for user action', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tbscreen-migrate-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}orphan.sqlite',
    );
    _createV1(file);

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final quarantined = await db.opsWithStatus(syncPermanentFailure);

    expect(quarantined, hasLength(1));
    expect(quarantined.single.detail, contains('owner attribution required'));
  });

  test('failed migration leaves the v1 transaction and data intact', () async {
    final directory = await Directory.systemTemp.createTemp(
      'tbscreen-migrate-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File(
      '${directory.path}${Platform.pathSeparator}broken.sqlite',
    );
    _createV1(file, owner: 'hospital:doctor', complete: false);

    final db = AppDatabase(NativeDatabase(file));
    await expectLater(db.getSetting(kSessionOwner), throwsA(anything));
    await db.close();

    final raw = sqlite3.open(file.path);
    try {
      expect(raw.select('PRAGMA user_version').single.values.single, 1);
      expect(
        raw
            .select('SELECT client_op_id FROM sync_queue')
            .single['client_op_id'],
        'op-1',
      );
    } finally {
      raw.close();
    }
  });
}
