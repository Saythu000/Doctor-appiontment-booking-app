import '../model/health_metrics.dart';

abstract class IHealthRepository {
  Future<void> saveMetric(HealthMetric metric);
  Future<List<HealthMetric>> getRecentMetrics(String type);
  Future<void> uploadPendingMetrics();
  Future<void> clearMetrics();
  Future<void> saveProfileValue(String key, String value);
  Future<String?> getProfileValue(String key);
}
