/// Semantic accent for a metric icon. The widget layer maps this to a color
/// via AppTheme — domain models stay free of Flutter imports.
enum MetricTone { success, warning }

/// Immutable stat-card data for the dashboard grid.
class DashboardMetric {
  const DashboardMetric({
    required this.title,
    required this.value,
    required this.change,
    required this.icon,
    this.subtext,
    this.tone,
  });

  final String title;
  final String value;
  final String change;

  /// Icon key ('people' | 'analytics' | 'verified' | 'pending').
  final String icon;
  final String? subtext;
  final MetricTone? tone;
}
