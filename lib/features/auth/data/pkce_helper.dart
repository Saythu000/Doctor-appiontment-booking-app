import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Cryptographic helper for OAuth 2.0 PKCE (RFC 7636).
class PkceHelper {
  static const String _charset =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// Generates a high-entropy cryptographically random `code_verifier`.
  /// RFC 7636 section 4.1 specifies length between 43 and 128 characters.
  static String generateCodeVerifier([int length = 64]) {
    final random = Random.secure();
    return List.generate(
      length.clamp(43, 128),
      (_) => _charset[random.nextInt(_charset.length)],
    ).join();
  }

  /// Calculates the SHA-256 `code_challenge` corresponding to a given `code_verifier`.
  /// Returns unpadded base64url encoded string per RFC 7636 section 4.2.
  static String generateCodeChallenge(String codeVerifier) {
    final bytes = ascii.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Generates a random state string for CSRF mitigation.
  static String generateState([int length = 32]) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => _charset[random.nextInt(_charset.length)],
    ).join();
  }
}
