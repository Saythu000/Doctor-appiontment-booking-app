import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/core/auth/pkce_helper.dart';

void main() {
  group('PkceHelper Unit Tests', () {
    test('generateCodeVerifier creates high-entropy string within RFC 7636 bounds', () {
      final verifierDefault = PkceHelper.generateCodeVerifier();
      expect(verifierDefault.length, equals(64));

      final allowedRegex = RegExp(r'^[A-Za-z0-9\-._~]+$');
      expect(allowedRegex.hasMatch(verifierDefault), isTrue);

      final verifierMin = PkceHelper.generateCodeVerifier(10);
      expect(verifierMin.length, equals(43));

      final verifierMax = PkceHelper.generateCodeVerifier(200);
      expect(verifierMax.length, equals(128));

      final verifier2 = PkceHelper.generateCodeVerifier();
      expect(verifierDefault, isNot(equals(verifier2)));
    });

    test('generateCodeChallenge produces valid S256 base64url unpadded digest', () {
      const testVerifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      final challenge = PkceHelper.generateCodeChallenge(testVerifier);

      final expectedDigest = sha256.convert(ascii.encode(testVerifier));
      final expectedChallenge = base64Url.encode(expectedDigest.bytes).replaceAll('=', '');

      expect(challenge, equals(expectedChallenge));
      expect(challenge.contains('='), isFalse);
      expect(challenge.contains('+'), isFalse);
      expect(challenge.contains('/'), isFalse);
    });

    test('generateState creates distinct cryptographically secure state tokens', () {
      final state1 = PkceHelper.generateState(32);
      final state2 = PkceHelper.generateState(32);

      expect(state1.length, equals(32));
      expect(state2.length, equals(32));
      expect(state1, isNot(equals(state2)));

      final allowedRegex = RegExp(r'^[A-Za-z0-9\-._~]+$');
      expect(allowedRegex.hasMatch(state1), isTrue);
    });
  });
}
