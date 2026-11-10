import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Appointment Sorting Logic Tests', () {
    test('past appointments sort by date descending and time ascending', () {
      final pastAppts = [
        {'id': '1', 'start_time': '2026-10-05T14:30:00Z'}, // Oct 5, 2:30 PM UTC
        {'id': '2', 'start_time': '2026-10-06T16:00:00Z'}, // Oct 6, 4:00 PM UTC
        {'id': '3', 'start_time': '2026-10-06T09:15:00Z'}, // Oct 6, 9:15 AM UTC
        {'id': '4', 'start_time': '2026-10-05T08:00:00Z'}, // Oct 5, 8:00 AM UTC
        {'id': '5', 'start_time': '2026-10-06T11:00:00Z'}, // Oct 6, 11:00 AM UTC
        {'id': '6', 'start_time': '2026-10-04T10:00:00Z'}, // Oct 4, 10:00 AM UTC
      ];

      pastAppts.sort((a, b) {
        try {
          final dtA = DateTime.parse(a['start_time'] as String).toLocal();
          final dtB = DateTime.parse(b['start_time'] as String).toLocal();

          final dateA = DateTime(dtA.year, dtA.month, dtA.day);
          final dateB = DateTime(dtB.year, dtB.month, dtB.day);
          final dateCompare = dateB.compareTo(dateA); // Newer date first

          if (dateCompare != 0) return dateCompare;

          // Same date: chronological time order (morning -> evening)
          final timeA = dtA.hour * 60 + dtA.minute;
          final timeB = dtB.hour * 60 + dtB.minute;
          return timeA.compareTo(timeB);
        } catch (_) {
          return (b['start_time'] ?? '').compareTo(a['start_time'] ?? '');
        }
      });

      // Expected order:
      // Oct 6: 09:15 AM (id: 3), 11:00 AM (id: 5), 16:00 (id: 2)
      // Oct 5: 08:00 AM (id: 4), 14:30 (id: 1)
      // Oct 4: 10:00 AM (id: 6)
      expect(pastAppts.map((a) => a['id']).toList(), ['3', '5', '2', '4', '1', '6']);
    });

    test('upcoming appointments sort chronological ascending', () {
      final upcomingAppts = [
        {'id': '1', 'start_time': '2026-10-10T14:30:00Z'},
        {'id': '2', 'start_time': '2026-10-08T16:00:00Z'},
        {'id': '3', 'start_time': '2026-10-08T09:15:00Z'},
      ];

      upcomingAppts.sort((a, b) {
        try {
          final dtA = DateTime.parse(a['start_time'] as String).toLocal();
          final dtB = DateTime.parse(b['start_time'] as String).toLocal();
          return dtA.compareTo(dtB);
        } catch (_) {
          return (a['start_time'] ?? '').compareTo(b['start_time'] ?? '');
        }
      });

      expect(upcomingAppts.map((a) => a['id']).toList(), ['3', '2', '1']);
    });
  });
}
