import 'dart:async';

class PedometerSensor {
  final StreamController<int> _controller = StreamController<int>.broadcast();

  Stream<int> get dataStream => _controller.stream;

  Future<void> startSensor() async {
    // Hardware phone accelerometer step counting is disabled.
    // Step telemetry strictly originates from synced health services (Google Fit / Health Connect).
  }

  Future<void> stopSensor() async {
    // No-op as hardware listeners are removed
  }

  bool get isUsingAccelerometer => false;
}
