import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/domain/models/activity_item.dart';
import 'package:myapp/domain/models/dashboard_metric.dart';
import 'package:myapp/domain/models/dashboard_snapshot.dart';
import 'package:myapp/domain/models/system_status.dart';
import 'package:myapp/domain/models/trend_data_point.dart';
import 'package:myapp/domain/repositories/dashboard_repository.dart';

class HttpDashboardRepository
    implements DashboardRepository, DashboardSnapshotRepository {
  HttpDashboardRepository(this._client);
  final ApiClient _client;

  @override
  Future<DashboardSnapshot> load({
    required int days,
    required int tzOffsetMinutes,
  }) async {
    final responses = await Future.wait([
      _client.dio.get<Object?>(
        '/dashboard/summary',
        queryParameters: {'days': days, 'tz_offset_minutes': tzOffsetMinutes},
      ),
      _client.dio.get<Object?>(
        '/dashboard/activity',
        queryParameters: {'limit': 10, 'offset': 0},
      ),
    ]);
    final summary = _object(responses[0].data);
    final period = _object(summary['period']);
    final responseDays = _count(period['days']);
    if (responseDays != days) {
      throw const FormatException('Dashboard period mismatch');
    }
    final agreement = _object(summary['agreement']);
    final distribution = _object(summary['distribution']);
    final rawTrend = summary['trend'];
    final rawActivities = responses[1].data;
    if (rawTrend is! List || rawActivities is! List) {
      throw const FormatException('Dashboard lists are invalid');
    }
    final metrics = <DashboardMetric>[];
    for (final entry in const [
      ('patients', 'Patients registered', 'people'),
      ('screenings', 'Total Screenings', 'analytics'),
      ('validated', 'Validated', 'verified'),
      ('pending', 'Pending', 'pending'),
    ]) {
      final count = _object(summary[entry.$1]);
      final value = _count(count['value']);
      final previous = _count(count['previous']);
      final change = count['change_pct'];
      if (!count.containsKey('change_pct')) {
        throw const FormatException('Dashboard change is missing');
      }
      if (change != null && (change is! num || !change.isFinite)) {
        throw const FormatException('Dashboard change is invalid');
      }
      metrics.add(
        DashboardMetric(
          title: entry.$2,
          value: '$value',
          change: change == null
              ? '—'
              : '${change >= 0 ? '+' : ''}${(change as num).toStringAsFixed(1)}%',
          icon: entry.$3,
          subtext: 'Previous period: $previous',
        ),
      );
    }
    return DashboardSnapshot(
      days: responseDays,
      metrics: List.unmodifiable(metrics),
      activities: List.unmodifiable(
        rawActivities.map((raw) {
          final item = _object(raw);
          final positive = item['is_positive'];
          final confidence = _count(item['confidence']);
          if (positive is! bool || confidence > 100) {
            throw const FormatException('Dashboard activity is invalid');
          }
          final date = DateTime.parse(_text(item['diagnosed_at'])).toLocal();
          final stamp = date
              .toIso8601String()
              .substring(0, 16)
              .replaceFirst('T', ' ');
          return ActivityItem(
            name: _text(item['patient_name']),
            timestamp: stamp,
            result: positive ? 'Positive' : 'Negative',
            confidence: confidence,
            institution: _text(item['hospital_name']),
          );
        }),
      ),
      trend: List.unmodifiable(
        rawTrend.map((raw) {
          final point = _object(raw);
          final date = _text(point['date']);
          DateTime.parse(date);
          return TrendDataPoint(
            date: date,
            totalDiagnoses: _count(point['screenings']),
            totalPatients: _count(point['patients']),
          );
        }),
      ),
      agreed: _count(agreement['agreed']),
      disagreed: _count(agreement['disagreed']),
      agreementRate: _percentage(agreement, 'rate'),
      ai: _distribution(distribution['ai']),
      doctor: _distribution(distribution['doctor']),
    );
  }

  DashboardDistribution _distribution(Object? raw) {
    final value = _object(raw);
    return DashboardDistribution(
      _count(value['positive']),
      _count(value['negative']),
      _percentage(value, 'positive_pct'),
    );
  }

  Map<String, dynamic> _object(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Dashboard object is invalid');
    }
    return raw;
  }

  int _count(Object? raw) {
    if (raw is! int || raw < 0) {
      throw const FormatException('Dashboard count is invalid');
    }
    return raw;
  }

  String _text(Object? raw) {
    if (raw is! String) {
      throw const FormatException('Dashboard text is invalid');
    }
    return raw;
  }

  double? _percentage(Map<String, dynamic> value, String key) {
    if (!value.containsKey(key)) {
      throw const FormatException('Dashboard rate is missing');
    }
    final raw = value[key];
    if (raw == null) return null;
    if (raw is! num || !raw.isFinite || raw < 0 || raw > 100) {
      throw const FormatException('Dashboard rate is invalid');
    }
    return raw.toDouble();
  }

  Future<DashboardSnapshot> _default() =>
      load(days: 30, tzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes);
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
