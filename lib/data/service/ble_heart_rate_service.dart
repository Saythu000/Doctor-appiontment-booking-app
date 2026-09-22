import 'dart:async';
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

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
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
      if (_currentState == BleDeviceState.scanning) {
        _updateState(BleDeviceState.disconnected);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Failed to stop scan: $e');
      }
    }
  }

  /// Connect directly to a chosen smartwatch/fitness tracker
  Future<bool> connect(BluetoothDevice device) async {
    try {
      await stopScan();
      _updateState(BleDeviceState.connecting);
      _connectedDevice = device;

      // Monitor hardware connection lifecycle
      _deviceStateSubscription?.cancel();
      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _updateState(BleDeviceState.connected);
        } else if (state == BluetoothConnectionState.disconnected) {
          _cleanupConnection();
          _updateState(BleDeviceState.disconnected);
        }
      });

      // Connect with autoConnect false for faster initial handshake
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

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

      if (_hrCharacteristic != null) {
        // Enable notify on GATT Heart Rate Measurement
        await _hrCharacteristic!.setNotifyValue(true);
        _hrSubscription?.cancel();
        _hrSubscription = _hrCharacteristic!.onValueReceived.listen(_parseHeartRatePacket);

        _updateState(BleDeviceState.connected);
        if (kDebugMode) {
          print('[BLE] Successfully subscribed to Heart Rate GATT (0x2A37) on ${device.platformName}');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('[BLE] Heart Rate GATT (0x180D/0x2A37) not found on ${device.platformName}. Services discovered: ${services.map((s) => s.uuid).toList()}');
        }
        _updateState(BleDeviceState.connected); // Still keep connection alive for device tracking
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BLE] Connection error: $e');
      }
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
  }

  void _updateState(BleDeviceState newState) {
    _currentState = newState;
    _statusController.add(newState);
  }

  /// Parse Bluetooth SIG Standard Heart Rate Measurement binary packet (GATT 0x2A37)
  /// Spec: https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0/
  void _parseHeartRatePacket(List<int> data) {
    if (data.isEmpty) return;

    final flags = data[0];
    final is16Bit = (flags & 0x01) != 0;
    int bpm = 0;
    int offset = 1;

    if (is16Bit) {
      if (data.length >= 3) {
        bpm = data[offset] | (data[offset + 1] << 8);
        offset += 2;
      }
    } else {
      if (data.length >= 2) {
        bpm = data[offset];
        offset += 1;
      }
    }

    if (bpm > 30 && bpm < 240) {
      _latestHeartRate = bpm;
      _heartRateController.add(bpm);
    }

    // Check if Energy Expended is present (Bit 3)
    final energyPresent = (flags & 0x08) != 0;
    if (energyPresent) {
      offset += 2;
    }

    // Check if RR-Interval (HRV) values are present (Bit 4)
    final rrPresent = (flags & 0x10) != 0;
    if (rrPresent && data.length >= offset + 2) {
      final rrRaw = data[offset] | (data[offset + 1] << 8);
      // RR-interval unit: 1/1024 seconds -> convert to milliseconds
      final double rrMs = (rrRaw / 1024.0) * 1000.0;
      if (rrMs > 300 && rrMs < 2000) {
        _latestHrv = double.parse(rrMs.toStringAsFixed(1));
        _hrvController.add(_latestHrv!);
      }
    }
  }

  void dispose() {
    _cleanupConnection();
    _heartRateController.close();
    _hrvController.close();
    _statusController.close();
    _scanResultsController.close();
  }
}
