class HealthMetric {
  final String id;
  final String type;
  final double value;
  final DateTime timestamp;
  final bool isSynced;

  HealthMetric({
    required this.id,
    required this.type,
    required this.value,
    required this.timestamp,
    this.isSynced = false,
  });
}
