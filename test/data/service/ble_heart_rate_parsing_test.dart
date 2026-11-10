import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/data/service/ble_heart_rate_service.dart';

/// RR interval in ms -> raw uint16 (1/1024 s units), little-endian bytes.
List<int> _rr(double ms) {
  final raw = (ms / 1000.0 * 1024.0).round();
  return [raw & 0xFF, (raw >> 8) & 0xFF];
}

void main() {
  group('parseHeartRateMeasurement', () {
    test('8-bit heart rate without RR intervals', () {
      final m = BleHeartRateService.parseHeartRateMeasurement([0x00, 72])!;
      expect(m.bpm, 72);
      expect(m.rrIntervalsMs, isEmpty);
    });

    test('16-bit heart rate', () {
      final m = BleHeartRateService.parseHeartRateMeasurement([0x01, 0x2C, 0x01])!;
      expect(m.bpm, 300);
    });

    test('reads every RR interval in the packet, not just the first', () {
      final m = BleHeartRateService.parseHeartRateMeasurement(
        [0x10, 70, ..._rr(800), ..._rr(820), ..._rr(790)],
      )!;
      expect(m.bpm, 70);
      expect(m.rrIntervalsMs.length, 3);
      expect(m.rrIntervalsMs[0], closeTo(800, 1));
      expect(m.rrIntervalsMs[1], closeTo(820, 1));
      expect(m.rrIntervalsMs[2], closeTo(790, 1));
    });

    test('skips the energy-expended field before RR intervals', () {
      final m = BleHeartRateService.parseHeartRateMeasurement(
        [0x18, 65, 0x34, 0x12, ..._rr(900)],
      )!;
      expect(m.rrIntervalsMs.single, closeTo(900, 1));
    });

    test('returns null for empty or truncated packets', () {
      expect(BleHeartRateService.parseHeartRateMeasurement([]), isNull);
      expect(BleHeartRateService.parseHeartRateMeasurement([0x00]), isNull);
      expect(BleHeartRateService.parseHeartRateMeasurement([0x01, 0x2C]), isNull);
    });
  });

  group('rmssd', () {
    test('matches the hand-computed value', () {
      // diffs: +20, -30, +10 -> sqrt((400 + 900 + 100) / 3) = 21.602
      expect(BleHeartRateService.rmssd([800, 820, 790, 800]), closeTo(21.602, 0.001));
    });

    test('is 0 for a perfectly regular rhythm', () {
      expect(BleHeartRateService.rmssd([1000, 1000, 1000]), 0);
    });

    test('needs at least two intervals', () {
      expect(BleHeartRateService.rmssd([]), isNull);
      expect(BleHeartRateService.rmssd([800]), isNull);
    });

    test('is a beat-to-beat variation, not the RR interval itself', () {
      // A raw RR interval (~800 ms) used to be reported as "HRV".
      final value = BleHeartRateService.rmssd([800, 810, 805, 812, 798])!;
      expect(value, lessThan(50));
    });
  });
}
