import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:phia_flutter/viewmodel/auth_viewmodel.dart';

String _jwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

int _epoch(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

void main() {
  group('AuthViewModel.isJwtValid', () {
    test('accepts an unexpired token', () {
      final token = _jwt({'exp': _epoch(DateTime.now().add(const Duration(hours: 1)))});
      expect(AuthViewModel.isJwtValid(token), isTrue);
    });

    test('rejects an expired token', () {
      final token = _jwt({'exp': _epoch(DateTime.now().subtract(const Duration(minutes: 1)))});
      expect(AuthViewModel.isJwtValid(token), isFalse);
    });

    test('rejects a token expiring within the 10s safety buffer', () {
      final token = _jwt({'exp': _epoch(DateTime.now().add(const Duration(seconds: 5)))});
      expect(AuthViewModel.isJwtValid(token), isFalse);
    });

    test('rejects a token without an exp claim', () {
      expect(AuthViewModel.isJwtValid(_jwt({'sub': 'user-1'})), isFalse);
    });

    test('rejects null, empty and non-JWT strings', () {
      expect(AuthViewModel.isJwtValid(null), isFalse);
      expect(AuthViewModel.isJwtValid(''), isFalse);
      expect(AuthViewModel.isJwtValid('opaque-access-token'), isFalse);
    });
  });
}
