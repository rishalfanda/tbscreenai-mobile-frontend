import 'package:flutter/foundation.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/activity_item.dart';
import 'package:myapp/domain/models/dashboard_metric.dart';
import 'package:myapp/domain/models/system_status.dart';
import 'package:myapp/domain/models/trend_data_point.dart';
import 'package:myapp/domain/repositories/dashboard_repository.dart';

/// Mock dashboard data, returned synchronously (no loading flash).
class MockDashboardRepository implements DashboardRepository {
  @override
  Future<List<DashboardMetric>> getMetrics() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.dashboardMetrics));

  @override
  Future<List<ActivityItem>> getRecentActivities() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.recentActivities));

  @override
  Future<List<TrendDataPoint>> getTrendData() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.trendData));

  @override
  Future<List<SystemStatus>> getSystemStatuses() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.systemStatuses));
}
