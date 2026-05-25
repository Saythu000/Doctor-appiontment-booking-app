import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import '../../domain/service/i_sensor_service.dart';

class PPGData {
  final double bpm;
  final double hrv;
  final double signal;
  final bool isFingerDetected;

  PPGData({
    required this.bpm,
    required this.hrv,
    required this.signal,
    required this.isFingerDetected,
  });
}

class CameraPPGSensor implements ISensorService {
  CameraController? _cameraController;
  final StreamController<PPGData> _controller = StreamController<PPGData>.broadcast();

  // DSP and Peak Detection state
  final List<double> _rawHistory = [];
  final List<double> _filteredHistory = [];
  final List<int> _ibiHistory = []; // Inter-Beat Intervals in ms
  
  DateTime? _lastPeakTime;
  double _runningBpm = 0.0;
  double _runningHrv = 0.0;
  bool _processingFrame = false;

  static const int _historyLimit = 150; // ~5 seconds of data at 30fps
  static const int _dcWindow = 20;     // Windows size to remove DC offset (low-pass)
  static const int _smoothWindow = 5;  // Window size to smooth signal (high-pass filter)
  static const Duration _minRefractory = Duration(milliseconds: 400); // Max 150 BPM

  @override
  Stream<PPGData> get dataStream => _controller.stream;

  @override
  Future<void> startSensor() async {
    _rawHistory.clear();
    _filteredHistory.clear();
    _ibiHistory.clear();
    _lastPeakTime = null;
    _runningBpm = 0.0;
    _runningHrv = 0.0;
    _processingFrame = false;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _controller.addError('No cameras found on device');
        return;
      }

      // Find the primary back camera
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      
      // Turn on torch to illuminate capillaries in the finger
      await _cameraController!.setFlashMode(FlashMode.torch);
      
      // Start streaming video frames
      await _cameraController!.startImageStream(_processImageFrame);
    } catch (e) {
      _controller.addError('Failed to initialize Camera PPG sensor: $e');
    }
  }

  void _processImageFrame(CameraImage image) {
    if (_processingFrame) return;
    _processingFrame = true;

    try {
      double averageLuminance = 0.0;

      // Extract average pixel luminance based on format
      if (image.format.group == ImageFormatGroup.yuv420) {
        // YUV (Android/Emulator)
        final bytes = image.planes[0].bytes;
        int sum = 0;
        int step = 32; // Subsample for real-time efficiency
        int count = 0;
        for (int i = 0; i < bytes.length; i += step) {
          sum += bytes[i];
          count++;
        }
        averageLuminance = sum / count;
      } else {
        // BGRA / RGBA (iOS)
        final bytes = image.planes[0].bytes;
        int sum = 0;
        int step = 32 * 4; // Subsample pixels
        int count = 0;
        for (int i = 0; i < bytes.length; i += step) {
          if (i + 2 < bytes.length) {
            sum += bytes[i + 2]; // BGRA: index 2 is red channel
            count++;
          }
        }
        averageLuminance = count > 0 ? (sum / count) : 0.0;
      }

      // Finger detection check
      // When a finger is placed on the lens with the flash active, the frames are highly illuminated and red-saturated
      // An average luminance > 160 is a reliable threshold for finger placement
      bool fingerDetected = averageLuminance > 160;

      if (!fingerDetected) {
        _rawHistory.clear();
        _filteredHistory.clear();
        _controller.add(PPGData(
          bpm: 0.0,
          hrv: 0.0,
          signal: 0.0,
          isFingerDetected: false,
        ));
        _processingFrame = false;
        return;
      }

      // 1. Record raw signal value
      _rawHistory.add(averageLuminance);
      if (_rawHistory.length > _historyLimit) {
        _rawHistory.removeAt(0);
      }

      // 2. High-pass filter: Remove slow baseline drift (DC offset)
      double dcOffset = 0.0;
      int dcStart = max(0, _rawHistory.length - _dcWindow);
      int dcCount = _rawHistory.length - dcStart;
      for (int i = dcStart; i < _rawHistory.length; i++) {
        dcOffset += _rawHistory[i];
      }
      dcOffset /= dcCount;
      double acComponent = averageLuminance - dcOffset;

      // 3. Low-pass filter: Smooth out high-frequency noise
      _filteredHistory.add(acComponent);
      if (_filteredHistory.length > _historyLimit) {
        _filteredHistory.removeAt(0);
      }

      double smoothedSignal = 0.0;
      int smoothStart = max(0, _filteredHistory.length - _smoothWindow);
      int smoothCount = _filteredHistory.length - smoothStart;
      for (int i = smoothStart; i < _filteredHistory.length; i++) {
        smoothedSignal += _filteredHistory[i];
      }
      smoothedSignal /= smoothCount;

      // 4. Peak Detection and HRV/BPM updates
      _detectPulsePeak(smoothedSignal);

      _controller.add(PPGData(
        bpm: _runningBpm,
        hrv: _runningHrv,
        signal: smoothedSignal,
        isFingerDetected: true,
      ));

    } catch (e) {
      // Gracefully swallow single frame exceptions to prevent crash, just don't output
    } finally {
      _processingFrame = false;
    }
  }

  void _detectPulsePeak(double currentSignal) {
    if (_filteredHistory.length < 3) return;

    double prevSignal = _filteredHistory[_filteredHistory.length - 2];
    double prevPrevSignal = _filteredHistory[_filteredHistory.length - 3];

    // Local maxima peak check (Signal changes from increasing to decreasing)
    bool isPeak = prevSignal > prevPrevSignal && prevSignal > currentSignal && prevSignal > 0.05;

    if (isPeak) {
      final now = DateTime.now();
      if (_lastPeakTime == null) {
        _lastPeakTime = now;
      } else {
        final difference = now.difference(_lastPeakTime!);
        if (difference > _minRefractory) {
          int ibiMs = difference.inMilliseconds;
          _lastPeakTime = now;

          // Keep rolling window of last 10 beats
          _ibiHistory.add(ibiMs);
          if (_ibiHistory.length > 10) {
            _ibiHistory.removeAt(0);
          }

          // Calculate Live Heart Rate (BPM)
          double averageIbi = _ibiHistory.reduce((a, b) => a + b) / _ibiHistory.length;
          _runningBpm = 60000.0 / averageIbi;

          // Calculate Live HRV (RMSSD: Root Mean Square of Successive Differences)
          if (_ibiHistory.length >= 2) {
            double sumSquaredDiffs = 0.0;
            for (int i = 1; i < _ibiHistory.length; i++) {
              double diff = (_ibiHistory[i] - _ibiHistory[i - 1]).toDouble();
              sumSquaredDiffs += diff * diff;
            }
            _runningHrv = sqrt(sumSquaredDiffs / (_ibiHistory.length - 1));
          } else {
            _runningHrv = 0.0;
          }
        }
      }
    }
  }

  @override
  Future<void> stopSensor() async {
    if (_cameraController != null) {
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
        await _cameraController!.stopImageStream();
      } catch (e) {
        // Safe swallow
      }
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }
}
