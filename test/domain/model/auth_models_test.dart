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

    test('OAuth2TokenResponse parsing with snake_case and camelCase fallback', () {
      final json = {
        'access_token': 'atk_test_access_token_123',
        'refresh_token': 'rtk_test_refresh_token_456',
        'id_token': 'itk_test_id_token_789',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'scope': 'openid profile email',
      };

      final tokenResponse = OAuth2TokenResponse.fromJson(json);
      expect(tokenResponse.accessToken, equals('atk_test_access_token_123'));
      expect(tokenResponse.refreshToken, equals('rtk_test_refresh_token_456'));
      expect(tokenResponse.idToken, equals('itk_test_id_token_789'));
      expect(tokenResponse.tokenType, equals('Bearer'));
      expect(tokenResponse.expiresIn, equals(3600));
      expect(tokenResponse.scope, equals('openid profile email'));

      final outJson = tokenResponse.toJson();
      expect(outJson['access_token'], equals('atk_test_access_token_123'));
      expect(outJson['token_type'], equals('Bearer'));
    });

    test('OAuth2AuthResult holds tokens, user, sessionJwt and cookies', () {
      final tokens = OAuth2TokenResponse(
        accessToken: 'atk_123',
        tokenType: 'Bearer',
        expiresIn: 3600,
      );
      final user = User(
        id: 'usr_777',
        email: 'saythuk9@gmail.com',
        name: 'surya saythu',
      );

      final result = OAuth2AuthResult(
        tokens: tokens,
        user: user,
        sessionJwt: 'jwt_signed_eddsa_token',
        cookies: '__Secure-better-auth.session_token=xyz',
      );

      expect(result.tokens.accessToken, equals('atk_123'));
      expect(result.user.name, equals('surya saythu'));
      expect(result.sessionJwt, equals('jwt_signed_eddsa_token'));
      expect(result.cookies, contains('__Secure-better-auth.session_token'));
    });
  });
}
