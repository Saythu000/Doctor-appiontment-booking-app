import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/domain/model/booking_models.dart';

void main() {
  group('BookingModels Unit Tests', () {
    test('BookingSlot parses correctly and computes displayTime', () {
      final json = {
        'id': 101,
        'status': 'free',
        'start': '2026-10-15T09:30:00Z',
        'end': '2026-10-15T10:00:00Z',
      };

      final slot = BookingSlot.fromJson(json);

      expect(slot.id, equals(101));
      expect(slot.status, equals('free'));
      expect(slot.startDateTime, isNotNull);
      expect(slot.displayTime, isNotEmpty);
    });

    test('PractitionerRoleBooking parses specialties and details', () {
      final json = {
        'id': 1,
        'active': true,
        'practitioner_display': 'Dr. Sarah Connor',
        'specialty': [
          {'text': 'Cardiology'},
          {'coding_display': 'Internal Medicine'}
        ],
        'practitioner_detail': {
          'id': 55,
          'gender': 'female',
          'name': {'text': 'Dr. Sarah Connor'},
          'qualifications': [
            {'display': 'MD, FACC'}
          ]
        }
      };

      final role = PractitionerRoleBooking.fromJson(json);

      expect(role.id, equals(1));
      expect(role.active, isTrue);
      expect(role.specialties, contains('Cardiology'));
      expect(role.practitionerDetail?.fullName, equals('Dr. Sarah Connor'));
      expect(role.practitionerDetail?.qualifications.first.display, equals('MD, FACC'));
    });

    test('PractitionerRoleBooking serialization and roundtrip', () {
      final json = {
        'id': 1,
        'active': true,
        'practitioner_display': 'Dr. Sarah Connor',
        'specialty': [
          {'text': 'Cardiology'},
        ],
        'availability': [
          {
            'id': 10,
            'available_times': [
              {
                'id': 20,
                'days_of_week': ['mon', 'tue'],
                'all_day': false,
                'available_start_time': '09:00:00',
                'available_end_time': '17:00:00',
              }
            ]
          }
        ],
        'practitioner_detail': {
          'id': 55,
          'gender': 'female',
          'name': {'text': 'Dr. Sarah Connor'},
          'qualifications': [
            {'display': 'MD, FACC'}
          ]
        },
        'org_id': 'default-org',
      };

      final role = PractitionerRoleBooking.fromJson(json);
      final serialized = role.toJson();
      final roundtrip = PractitionerRoleBooking.fromJson(serialized);

      expect(roundtrip.id, equals(1));
      expect(roundtrip.active, isTrue);
      expect(roundtrip.orgId, equals('default-org'));
      expect(roundtrip.specialties, contains('Cardiology'));
      expect(roundtrip.practitionerDetail?.fullName, equals('Dr. Sarah Connor'));
      expect(roundtrip.availability.first.availableTimes.first.daysOfWeek, contains('mon'));
    });
  });
}
