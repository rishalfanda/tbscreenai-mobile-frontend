/// Recent diagnosis activity entry for the dashboard feed.
class ActivityItem {
  const ActivityItem({
    required this.name,
    required this.timestamp,
    required this.result,
    required this.confidence,
    required this.institution,
  });

  final String name;
  final String timestamp;
  final String result;
  final int confidence;
  final String institution;
}
