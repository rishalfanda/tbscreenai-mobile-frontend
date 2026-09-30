import 'package:myapp/domain/models/models.dart';
import 'package:myapp/domain/repositories/repositories.dart';

/// No endpoint is guessed. Bind real adapters only after contract agreement.
class UnavailableDashboardRepository implements DashboardRepository {
  @override
  Future<List<DashboardMetric>> getMetrics() async => [];
  @override
  Future<List<ActivityItem>> getRecentActivities() async => [];
  @override
  Future<List<TrendDataPoint>> getTrendData() async => [];
  @override
  Future<List<SystemStatus>> getSystemStatuses() async => [];
}

class UnavailableDatasetRepository implements DatasetRepository {
  @override
  Future<List<DatasetModel>> getDatasets() async => [];
  @override
  Future<List<DatasetRecord>> getRecords() async => [];
}
