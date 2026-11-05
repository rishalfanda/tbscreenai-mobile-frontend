import 'activity_item.dart';
import 'dashboard_metric.dart';
import 'trend_data_point.dart';

class DashboardDistribution {
  const DashboardDistribution(this.positive, this.negative, this.positivePct);
  final int positive;
  final int negative;
  final double? positivePct;
  int get total => positive + negative;
}

/// A complete live response. A null rate means there is no denominator.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.days,
    required this.metrics,
    required this.activities,
    required this.trend,
    required this.agreed,
    required this.disagreed,
    required this.agreementRate,
    required this.ai,
    required this.doctor,
  });
  final int days;
  final List<DashboardMetric> metrics;
  final List<ActivityItem> activities;
  final List<TrendDataPoint> trend;
  final int agreed;
  final int disagreed;
  final double? agreementRate;
  final DashboardDistribution ai;
  final DashboardDistribution doctor;
}
