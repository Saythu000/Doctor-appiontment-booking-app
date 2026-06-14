import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../domain/service/i_sensor_service.dart';

class PedometerSensor implements ISensorService {
  StreamSubscription<StepCount>? _pedometerSubscription;
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  
  final StreamController<int> _controller = StreamController<int>.broadcast();
  
  // Track step offsets
  int _startSteps = -1;
  int _sessionSteps = 0;
  
  // Accelerometer fallback fields
  double _lastMagnitude = 0.0;
  DateTime _lastStepTime = DateTime.now();
  static const double _stepThreshold = 5.0; // Balanced at 5.0 to detect steps with arm dampening while avoiding hand tilts
  static const Duration _stepRefractory = Duration(milliseconds: 380); // Balanced at 380ms to capture brisk walking without double counting

  @override
  Stream<int> get dataStream => _controller.stream;

  @override
  Future<void> startSensor() async {
    _startSteps = -1;
    _sessionSteps = 0;

    // Bypassing native pedometer batch-buffering to force the calibrated Accelerometer stream
    _startAccelerometerFallback();
  }

  void _onStepCount(StepCount event) {
    if (_startSteps == -1) {
      _startSteps = event.steps;
    }
    _sessionSteps = event.steps - _startSteps;
    _controller.add(_sessionSteps);
  }

  void _onPedometerError(dynamic error) {
    // If native hardware pedometer is unavailable (e.g. on emulators),
    // fallback gracefully to accelerometer-based peak detection
    _startAccelerometerFallback();
  }

  void _startAccelerometerFallback() {
    _pedometerSubscription?.cancel();
    _pedometerSubscription = null;

    _accelerometerSubscription = userAccelerometerEventStream().listen(
      (UserAccelerometerEvent event) {
        // Calculate magnitude of acceleration vector
        double magnitude = event.x * event.x + event.y * event.y + event.z * event.z;
        magnitude = magnitude > 0 ? magnitude : 0;
        
        // Simple peak detection
        if (magnitude > _stepThreshold && _lastMagnitude <= _stepThreshold) {
          final now = DateTime.now();
          if (now.difference(_lastStepTime) > _stepRefractory) {
            _sessionSteps++;
            _controller.add(_sessionSteps);
            _lastStepTime = now;
          }
        }
        _lastMagnitude = magnitude;
      },
      onError: (err) {
        _controller.addError('Step tracking sensors unavailable: $err');
      },
    );
  }

  @override
  Future<void> stopSensor() async {
    await _pedometerSubscription?.cancel();
    _pedometerSubscription = null;
    
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  bool get isUsingAccelerometer => _accelerometerSubscription != null;
}
