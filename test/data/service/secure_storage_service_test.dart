import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:phia_flutter/data/service/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService Unit Tests', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('writeSecure and readSecure round-trip', () async {
      final storage = SecureStorageService();
      await storage.writeSecure('test_token', 'sample_jwt_123');

      final value = await storage.readSecure('test_token');
      expect(value, equals('sample_jwt_123'));
    });

    test('deleteSecure removes item', () async {
      final storage = SecureStorageService();
      await storage.writeSecure('delete_me', 'temp_val');
      expect(await storage.readSecure('delete_me'), equals('temp_val'));

      await storage.deleteSecure('delete_me');
      expect(await storage.readSecure('delete_me'), isNull);
    });

    test('clearAll removes all items', () async {
      final storage = SecureStorageService();
      await storage.writeSecure('key1', 'v1');
      await storage.writeSecure('key2', 'v2');

      await storage.clearAll();
      expect(await storage.readSecure('key1'), isNull);
      expect(await storage.readSecure('key2'), isNull);
    });
  });
}
