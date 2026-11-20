import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/domain/models/activity_item.dart';
import 'package:myapp/domain/models/dashboard_metric.dart';
import 'package:myapp/domain/models/dashboard_snapshot.dart';
import 'package:myapp/domain/models/system_status.dart';
import 'package:myapp/domain/models/trend_data_point.dart';
import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/repositories/dashboard_repository.dart';

/// Device-only statistics for the signed-in clinician. No HTTP dependency.
class OfflineDashboardRepository
    implements
        DashboardRepository,
        DashboardSnapshotRepository,
        DeviceDashboardSource {
  OfflineDashboardRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Stream<void> watchChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([_db.localPatients, _db.localDiagnoses]),
      )
      .map((_) {});

  @override
  Future<DashboardSnapshot> load({
    required int days,
    required int tzOffsetMinutes,
  }) async {
    if (days < 1 || days > 366) throw ArgumentError.value(days, 'days');
    final owner = _db.activeOwner;
    final generation = _db.sessionGeneration;
    if (owner == null) throw StateError('Clinician session required');
    return _db.transaction(() async {
      final role = await _db.getSetting(kUserRole);
      if (MobileRole.parse(role) != MobileRole.clinician) {
        throw StateError('Clinician session required');
      }
      // Explicit predicates are intentional: never read unbound/other accounts.
      bool owns(String? tenant, String? user, String? device) =>
          tenant == owner.tenantId &&
          user == owner.userId &&
          device == owner.deviceId;
      final patients = (await _db.allPatients())
          .where((p) => owns(p.tenantId, p.userId, p.deviceId))
          .toList();
      final rows = (await _db.allDiagnoses())
          .where((d) => owns(d.tenantId, d.userId, d.deviceId) && !d.isMock)
          .toList();
      if (generation != _db.sessionGeneration ||
          !identical(owner, _db.activeOwner)) {
        throw StateError('Session changed');
      }
      final offset = Duration(minutes: tzOffsetMinutes);
      final localNow = _now().toUtc().add(offset);
      final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
      final end = today.add(const Duration(days: 1)).subtract(offset);
      final start = end.subtract(Duration(days: days));
      final previousStart = start.subtract(Duration(days: days));
      bool within(LocalDiagnose d, DateTime from, DateTime to) =>
          !d.diagnosedAt.toUtc().isBefore(from) &&
          d.diagnosedAt.toUtc().isBefore(to);
      final current = rows.where((d) => within(d, start, end)).toList();
      final previous = rows
          .where((d) => within(d, previousStart, start))
          .toList();
      bool validated(LocalDiagnose d) =>
          d.validationDeletedAt == null &&
          (d.status == 'agreed' || d.status == 'disagreed');
      bool pending(LocalDiagnose d) =>
          d.validationDeletedAt == null && d.status == 'pending';
      DashboardMetric metric(
        String title,
        String icon,
        int value,
        int old,
      ) => DashboardMetric(
        title: title,
        icon: icon,
        value: '$value',
        change: old == 0
            ? '\u2014'
            : '${value >= old ? '+' : ''}${(100 * (value - old) / old).toStringAsFixed(1)}%',
        subtext: 'Previous period: $old',
      );
      final agreed = current
          .where((d) => validated(d) && d.status == 'agreed')
          .length;
      final disagreed = current
          .where((d) => validated(d) && d.status == 'disagreed')
          .length;
      final reviewed = current.where(validated).toList();
      DashboardDistribution distribution(int positive, int total) =>
          DashboardDistribution(
            positive,
            total - positive,
            total == 0 ? null : 100 * positive / total,
          );
      final patientNames = {for (final p in patients) p.id: p.name};
      String name(LocalDiagnose d) {
        final cached = patientNames[d.patientId];
        if (cached != null) return cached;
        try {
          final snapshot = jsonDecode(d.patientSnapshot) as Map;
          return snapshot['patient_name'] as String? ?? 'Patient';
        } catch (_) {
          return 'Patient';
        }
      }

      final trend = <TrendDataPoint>[];
      for (var i = 0; i < days; i++) {
        final day = start.add(Duration(days: i));
        final daily = current
            .where((d) => within(d, day, day.add(const Duration(days: 1))))
            .toList();
        trend.add(
          TrendDataPoint(
            date: day.add(offset).toIso8601String().substring(0, 10),
            totalDiagnoses: daily.length,
            totalPatients: daily.map((d) => d.patientId).toSet().length,
          ),
        );
      }
      current.sort((a, b) {
        final date = b.diagnosedAt.compareTo(a.diagnosedAt);
        return date != 0 ? date : a.id.compareTo(b.id);
      });
      return DashboardSnapshot(
        days: days,
        metrics: [
          DashboardMetric(
            title: 'Patients on device',
            value: '${patients.length}',
            change: '\u2014',
            icon: 'people',
            subtext: 'Current account / all local patients',
          ),
          metric(
            'Total Screenings',
            'analytics',
            current.length,
            previous.length,
          ),
          metric(
            'Validated',
            'verified',
            reviewed.length,
            previous.where(validated).length,
          ),
          metric(
            'Pending',
            'pending',
            current.where(pending).length,
            previous.where(pending).length,
          ),
        ],
        activities: [
          for (final d in current.take(10))
            ActivityItem(
              name: name(d),
              timestamp: d.diagnosedAt
                  .toUtc()
                  .add(offset)
                  .toIso8601String()
                  .substring(0, 16)
                  .replaceFirst('T', ' '),
              result: d.isPositive ? 'Positive' : 'Negative',
              confidence: d.confidence,
              institution: 'Local device',
            ),
        ],
        trend: trend,
        agreed: agreed,
        disagreed: disagreed,
        agreementRate: reviewed.isEmpty ? null : 100 * agreed / reviewed.length,
        ai: distribution(
          current.where((d) => d.isPositive).length,
          current.length,
        ),
        // Binary clinician result: disagree reverses the AI classification.
        doctor: distribution(
          reviewed
              .where((d) => d.status == 'agreed' ? d.isPositive : !d.isPositive)
              .length,
          reviewed.length,
        ),
      );
    });
  }

  Future<DashboardSnapshot> _default() =>
      load(days: 30, tzOffsetMinutes: _now().timeZoneOffset.inMinutes);
  @override
  Future<List<DashboardMetric>> getMetrics() async =>
      (await _default()).metrics;
  @override
  Future<List<ActivityItem>> getRecentActivities() async =>
      (await _default()).activities;
  @override
  Future<List<TrendDataPoint>> getTrendData() async => (await _default()).trend;
  @override
  Future<List<SystemStatus>> getSystemStatuses() async => const [];
}
