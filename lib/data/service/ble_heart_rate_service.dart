import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Bluetooth GATT Service & Characteristic standard UUIDs
class BleGattUuid {
  static final Guid heartRateService = Guid('180D');
  static final Guid heartRateMeasurement = Guid('2A37');
  static final Guid bodySensorLocation = Guid('2A38');
  static final Guid pulseOximeterService = Guid('1822');
  static final Guid spo2Continuous = Guid('2A5F');
}

/// Device connection state wrapper
enum BleDeviceState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class BleHeartRateService {
  // Singleton pattern
  static final BleHeartRateService _instance = BleHeartRateService._internal();
  factory BleHeartRateService() => _instance;
  BleHeartRateService._internal();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _hrCharacteristic;
  StreamSubscription<List<int>>? _hrSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;

  /// Recent beat-to-beat (RR) intervals in ms, used to compute HRV (RMSSD).
  final List<double> _rrIntervalsMs = [];
  static const int _rrWindow = 60;
  static const int minRrIntervalsForHrv = 30;

  // Reactive Streams
  final _heartRateController = StreamController<int>.broadcast();
  final _hrvController = StreamController<double>.broadcast();
  final _statusController = StreamController<BleDeviceState>.broadcast();
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();

  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<double> get hrvStream => _hrvController.stream;
  Stream<BleDeviceState> get statusStream => _statusController.stream;
  Stream<List<ScanResult>> get scanResultsStream => _scanResultsController.stream;

  BleDeviceState _currentState = BleDeviceState.disconnected;
  BleDeviceState get currentState => _currentState;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  String? get connectedDeviceName => _connectedDevice?.platformName.isNotEmpty == true 
      ? _connectedDevice!.platformName 
      : _connectedDevice?.remoteId.str;

  int _latestHeartRate = 0;
  int get latestHeartRate => _latestHeartRate;

  double? _latestHrv;
  double? get latestHrv => _latestHrv;

  /// Check if Bluetooth hardware is available and turned on
  Future<bool> isBluetoothSupported() async {
    return await FlutterBluePlus.isSupported;
  }

  /// Request Bluetooth adapter to turn on if supported
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Could not turn on Bluetooth automatically: $e');
      }
    }
  }

  /// Start scanning for nearby BLE Smartwatches and fitness trackers
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        _updateState(BleDeviceState.error);
        return;
      }

      // Cancel previous scan if active
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _updateState(BleDeviceState.scanning);

      // Listen to scan results. Keep a single subscription: every scan used to
      // add another permanent listener.
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        // Filter devices that have an identifiable name or advertise Heart Rate service
        final validDevices = results.where((r) {
          return r.device.platformName.isNotEmpty || 
                 r.advertisementData.serviceUuids.contains(BleGattUuid.heartRateService);
        }).toList();

        _scanResultsController.add(validDevices);
      });

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidUsesFineLocation: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Failed to start scan: $e');
      }
      _updateState(BleDeviceState.error);
    }
  }

  /// Stop active scanning
  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      await _scanResultsSubscription?.cancel();
      _scanResultsSubscription = null;
      if (_currentState == BleDeviceState.scanning) {
        _updateState(BleDeviceState.disconnected);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Failed to stop scan: $e');
      }
    }
  }

  /// Connect directly to a chosen smartwatch/fitness tracker.
  /// Returns true only when the device exposes the standard Heart Rate
  /// service and live heart-rate notifications were enabled.
  Future<bool> connect(BluetoothDevice device) async {
    try {
      await stopScan();
      _updateState(BleDeviceState.connecting);
      await _deviceStateSubscription?.cancel();
      _deviceStateSubscription = null;

      // Connect with autoConnect false for faster initial handshake
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
      _connectedDevice = device;

      // Discover GATT services
      final services = await device.discoverServices();

      // Look for standard Heart Rate Service (0x180D)
      BluetoothService? hrService;
      for (final s in services) {
        if (s.uuid == BleGattUuid.heartRateService) {
          hrService = s;
          break;
        }
      }

      if (hrService == null) {
        // Some watches register Heart Rate under standard lowercase or full 128-bit UUID
        for (final s in services) {
          if (s.uuid.str128.toLowerCase().contains('180d')) {
            hrService = s;
            break;
          }
        }
      }

      if (hrService != null) {
        for (final c in hrService.characteristics) {
          if (c.uuid == BleGattUuid.heartRateMeasurement ||
              c.uuid.str128.toLowerCase().contains('2a37')) {
            _hrCharacteristic = c;
            break;
          }
        }
      }

      if (_hrCharacteristic == null) {
        // No standard heart-rate stream: reporting "connected" would show a
        // live device that never sends data. Disconnect and report failure.
        if (kDebugMode) {
          print('[BLE] Heart Rate GATT (0x180D/0x2A37) not found on ${device.platformName}. Services discovered: ${services.map((s) => s.uuid).toList()}');
        }
        try {
          await device.disconnect();
        } catch (_) {}
        _cleanupConnection();
        _updateState(BleDeviceState.error);
        return false;
      }

      // Enable notify on GATT Heart Rate Measurement
      await _hrCharacteristic!.setNotifyValue(true);
      await _hrSubscription?.cancel();
      _hrSubscription = _hrCharacteristic!.onValueReceived.listen(_parseHeartRatePacket);

      // Watch for the link dropping. Subscribing only now (after connect)
      // matters: connectionState replays its last value on listen, which
      // before connect() was "disconnected" and wiped the connection we were
      // about to make.
      _deviceStateSubscription = device.connectionState
          .where((state) => state == BluetoothConnectionState.disconnected)
          .listen((_) {
        if (_connectedDevice?.remoteId != device.remoteId) return;
        _cleanupConnection();
        _updateState(BleDeviceState.disconnected);
      });

      _updateState(BleDeviceState.connected);
      if (kDebugMode) {
        print('[BLE] Successfully subscribed to Heart Rate GATT (0x2A37) on ${device.platformName}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Connection error: $e');
      }
      try {
        await device.disconnect();
      } catch (_) {}
      _cleanupConnection();
      _updateState(BleDeviceState.error);
      return false;
    }
  }

  /// Disconnect current active device
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Disconnect error: $e');
      }
    } finally {
      _cleanupConnection();
      _updateState(BleDeviceState.disconnected);
    }
  }

  void _cleanupConnection() {
    _hrSubscription?.cancel();
    _hrSubscription = null;
    _hrCharacteristic = null;
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    _connectedDevice = null;
    _rrIntervalsMs.clear();
    _latestHrv = null;
  }

  void _updateState(BleDeviceState newState) {
    _currentState = newState;
    _statusController.add(newState);
  }

  void _parseHeartRatePacket(List<int> data) {
    final packet = parseHeartRateMeasurement(data);
    if (packet == null) return;

    if (packet.bpm > 30 && packet.bpm < 240) {
      _latestHeartRate = packet.bpm;
      _heartRateController.add(packet.bpm);
    }

    // HRV is RMSSD over a window of successive RR intervals (in ms). A single
    // RR interval is NOT HRV: it is just the length of one heartbeat.
    for (final rr in packet.rrIntervalsMs) {
      if (rr > 300 && rr < 2000) {
        _rrIntervalsMs.add(rr);
      }
    }
    if (_rrIntervalsMs.length > _rrWindow) {
      _rrIntervalsMs.removeRange(0, _rrIntervalsMs.length - _rrWindow);
    }
    if (_rrIntervalsMs.length >= minRrIntervalsForHrv) {
      final value = rmssd(_rrIntervalsMs);
      if (value != null) {
        _latestHrv = double.parse(value.toStringAsFixed(1));
        _hrvController.add(_latestHrv!);
      }
    }
  }

  /// Parses a Bluetooth SIG Heart Rate Measurement packet (GATT 0x2A37).
  /// Spec: https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0/
  /// Returns null for an empty or truncated packet.
  static HeartRateMeasurement? parseHeartRateMeasurement(List<int> data) {
    if (data.isEmpty) return null;

    final flags = data[0];
    final is16Bit = (flags & 0x01) != 0;
    int offset = 1;
    int bpm;

    if (is16Bit) {
      if (data.length < 3) return null;
      bpm = data[1] | (data[2] << 8);
      offset = 3;
    } else {
      if (data.length < 2) return null;
      bpm = data[1];
      offset = 2;
    }

    // Energy Expended present (bit 3): 2 bytes to skip
    if ((flags & 0x08) != 0) {
      offset += 2;
    }

    // RR-Interval values present (bit 4): every remaining uint16 is one RR
    // interval in units of 1/1024 s. A packet can carry several.
    final rr = <double>[];
    if ((flags & 0x10) != 0) {
      while (offset + 1 < data.length) {
        final raw = data[offset] | (data[offset + 1] << 8);
        rr.add(raw / 1024.0 * 1000.0);
        offset += 2;
      }
    }

    return HeartRateMeasurement(bpm: bpm, rrIntervalsMs: rr);
  }

  /// Root mean square of successive differences of RR intervals (ms), the
  /// standard short-term HRV measure. Returns null with fewer than 2 values.
  static double? rmssd(List<double> rrMs) {
    if (rrMs.length < 2) return null;
    double sumSq = 0;
    for (var i = 1; i < rrMs.length; i++) {
      final d = rrMs[i] - rrMs[i - 1];
      sumSq += d * d;
    }
    return math.sqrt(sumSq / (rrMs.length - 1));
  }

  void dispose() {
    _scanResultsSubscription?.cancel();
    _cleanupConnection();
    _heartRateController.close();
    _hrvController.close();
    _statusController.close();
    _scanResultsController.close();
  }
}

/// One decoded Heart Rate Measurement notification.
class HeartRateMeasurement {
  final int bpm;
  final List<double> rrIntervalsMs;
  const HeartRateMeasurement({required this.bpm, required this.rrIntervalsMs});
}
