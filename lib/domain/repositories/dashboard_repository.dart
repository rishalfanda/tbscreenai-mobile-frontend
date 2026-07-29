import 'package:myapp/domain/models/activity_item.dart';
import 'package:myapp/domain/models/dashboard_metric.dart';
import 'package:myapp/domain/models/system_status.dart';
import 'package:myapp/domain/models/trend_data_point.dart';

/// Contract for aggregated dashboard data.
abstract class DashboardRepository {
  Future<List<DashboardMetric>> getMetrics();

  Future<List<ActivityItem>> getRecentActivities();

  Future<List<TrendDataPoint>> getTrendData();

  Future<List<SystemStatus>> getSystemStatuses();
}
