import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/features/booking/domain/booking_models.dart';
import 'package:phia_flutter/features/booking/presentation/widgets/doctor_info.dart';

void main() {
  group('availabilityLabel Tests', () {
    PractitionerRoleBooking makeDoctor({
      required List<String> days,
      String? start,
      String? end,
    }) {
      return PractitionerRoleBooking(
        id: 1,
        active: true,
        practitionerRefId: 10,
        specialties: const ['Cardiology'],
        availability: [
          PractitionerAvailability(
            id: 1,
            availableTimes: [
              AvailableTimeSlot(
                id: 1,
                daysOfWeek: days,
                allDay: false,
                availableStartTime: start,
                availableEndTime: end,
              ),
            ],
          ),
        ],
        practitionerDetail: PractitionerDetail(
          id: 10,
          fullName: 'Dr. Test',
          qualifications: const [],
        ),
      );
    }

    test('formats Mon-Fri with start and end hours', () {
      final doc = makeDoctor(
        days: ['mon', 'tue', 'wed', 'thu', 'fri'],
        start: '09:00:00',
        end: '17:00:00',
      );
      expect(availabilityLabel(doc), equals('Mon–Fri · 9:00 AM–5:00 PM'));
    });

    test('formats all 7 days as Mon-Sun with hours', () {
      final doc = makeDoctor(
        days: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'],
        start: '09:00:00',
        end: '22:00:00',
      );
      expect(availabilityLabel(doc), equals('Mon–Sun · 9:00 AM–10:00 PM'));
    });

    test('formats Mon-Sat with hours', () {
      final doc = makeDoctor(
        days: ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
        start: '08:00:00',
        end: '17:00:00',
      );
      expect(availabilityLabel(doc), equals('Mon–Sat · 8:00 AM–5:00 PM'));
    });

    test('formats non-contiguous days as comma-separated list with hours', () {
      final doc = makeDoctor(
        days: ['mon', 'wed', 'fri'],
        start: '18:00:00',
        end: '21:00:00',
      );
      expect(availabilityLabel(doc), equals('Mon, Wed, Fri · 6:00 PM–9:00 PM'));
    });

    test('formats days only when no hours are provided', () {
      final doc = makeDoctor(
        days: ['mon', 'tue', 'wed', 'thu', 'fri'],
      );
      expect(availabilityLabel(doc), equals('Mon–Fri'));
    });

    test('returns null when doctor has no availability days', () {
      final doc = makeDoctor(
        days: [],
        start: '09:00:00',
        end: '17:00:00',
      );
      expect(availabilityLabel(doc), isNull);
    });
  });
}
