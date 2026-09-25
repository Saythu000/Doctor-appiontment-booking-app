import 'dart:async';
import '../../domain/service/i_sensor_service.dart';

class PedometerSensor implements ISensorService {
  final StreamController<int> _controller = StreamController<int>.broadcast();

  @override
  Stream<int> get dataStream => _controller.stream;

  @override
  Future<void> startSensor() async {
    // Hardware phone accelerometer step counting is disabled.
    // Step telemetry strictly originates from synced health services (Google Fit / Health Connect).
  }

  @override
  Future<void> stopSensor() async {
    // No-op as hardware listeners are removed
  }

  bool get isUsingAccelerometer => false;
}
