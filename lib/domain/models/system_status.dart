/// Label/value pair describing a subsystem's health (AI model, DB, storage).
class SystemStatus {
  const SystemStatus({required this.label, required this.value});

  final String label;
  final String value;
}
