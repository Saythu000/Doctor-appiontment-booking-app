import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/features/profile/domain/patient_profile.dart';

void main() {
  group('PatientProfile Unit Tests', () {
    test('PlainPatientName parsing and fullName computation', () {
      final name1 = PlainPatientName.fromJson({
        'given_name': 'Alex',
        'family_name': 'Rivera',
        'use': 'official',
      });
      expect(name1.fullName, equals('Alex Rivera'));
      expect(name1.use, equals('official'));

      // Test with given as a list
      final name2 = PlainPatientName.fromJson({
        'given': ['Jane', 'Marie'],
        'family': 'Doe',
      });
      expect(name2.fullName, equals('Jane Marie Doe'));

      // Test without family name
      final name3 = PlainPatientName.fromJson({
        'given_name': 'Alex',
      });
      expect(name3.fullName, equals('Alex'));
    });

    test('PlainPatientTelecom parsing and serialization', () {
      final json = {
        'system': 'phone',
        'value': '5550100123',
        'use': 'mobile',
      };
      final telecom = PlainPatientTelecom.fromJson(json);
      expect(telecom.system, equals('phone'));
      expect(telecom.value, equals('5550100123'));
      expect(telecom.use, equals('mobile'));

      final outJson = telecom.toJson();
      expect(outJson['value'], equals('5550100123'));
      expect(outJson['system'], equals('phone'));
    });

    test('PlainPatientAddress parsing with multiple lines', () {
      final json = {
        'line': ['123 Healthcare Ave', 'Suite 400'],
        'city': 'Hyderabad',
        'state': 'Telangana',
        'postal_code': '500081',
        'country': 'India',
      };
      final addr = PlainPatientAddress.fromJson(json);
      expect(addr.line.length, equals(2));
      expect(addr.city, equals('Hyderabad'));
      expect(addr.postalCode, equals('500081'));
    });

    test('PlainPatient full profile parsing from DrGodly FHIR me endpoint', () {
      final fhirJson = {
        'id': 10008,
        'user_id': 'usr_alex_99',
        'org_id': '0fb41e50-82a4-461e-96c7-bd11359d892d',
        'active': true,
        'gender': 'male',
        'birth_date': '1990-01-15',
        'name': [
          {
            'given_name': 'alex',
            'family_name': 'rivera',
            'use': 'official',
          }
        ],
        'telecom': [
          {
            'system': 'phone',
            'value': '5550100123',
            'use': 'mobile',
          }
        ],
        'address': [
          {
            'line': ['Plot 42'],
            'city': 'Hyderabad',
            'country': 'India',
          }
        ]
      };

      final patient = PlainPatient.fromJson(fhirJson);
      expect(patient.id, equals(10008));
      expect(patient.gender, equals('male'));
      expect(patient.birthDate, equals('1990-01-15'));
      expect(patient.name?.first.fullName, equals('alex rivera'));
      expect(patient.telecom?.first.value, equals('5550100123'));
      expect(patient.orgId, equals('0fb41e50-82a4-461e-96c7-bd11359d892d'));
    });
  });
}
