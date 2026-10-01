import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/domain/model/auth_models.dart';

void main() {
  group('AuthModels Unit Tests', () {
    test('User serialization and deserialization', () {
      final user = User(
        id: 'usr_123',
        email: 'patient@example.com',
        name: 'Jane Doe',
      );

      final json = user.toJson();
      final fromJsonUser = User.fromJson(json);

      expect(fromJsonUser.id, equals('usr_123'));
      expect(fromJsonUser.email, equals('patient@example.com'));
      expect(fromJsonUser.name, equals('Jane Doe'));
    });

    test('UserSession parsing with activeOrganizationId', () {
      final json = {
        'id': 'sess_999',
        'token': 'tok_xyz',
        'userId': 'usr_123',
        'activeOrganizationId': 'org_drgodly_primary',
        'expiresAt': '2026-12-31T23:59:59Z',
      };

      final session = UserSession.fromJson(json);

      expect(session.id, equals('sess_999'));
      expect(session.token, equals('tok_xyz'));
      expect(session.activeOrganizationId, equals('org_drgodly_primary'));
    });

    test('GetSessionResponse parsing', () {
      final json = {
        'user': {
          'id': 'usr_456',
          'email': 'doctor@example.com',
          'name': 'Dr. Smith',
        },
        'session': {
          'id': 'sess_1',
          'token': 'tok_1',
          'userId': 'usr_456',
          'activeOrganizationId': 'org_1',
          'expiresAt': '2026-10-10T10:00:00Z',
        }
      };

      final response = GetSessionResponse.fromJson(json);
      expect(response.user.id, equals('usr_456'));
      expect(response.session.id, equals('sess_1'));
    });
  });
}
