import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
    ),
  );

  /// Throws if the value could not be stored. Callers must not fall back to
  /// plaintext storage for secrets.
  Future<void> writeSecure(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readSecure(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSecure(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
