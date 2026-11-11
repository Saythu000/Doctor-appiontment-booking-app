import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final Map<String, String> _memoryCache = {};

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Throws if the value could not be stored. Callers must not fall back to
  /// plaintext storage for secrets.
  Future<void> writeSecure(String key, String value) async {
    _memoryCache[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('[SecureStorageService] writeSecure error for $key: $e');
    }
  }

  Future<String?> readSecure(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memoryCache[key] = val;
      }
      return val;
    } catch (e) {
      debugPrint('[SecureStorageService] readSecure error for $key: $e');
      return null;
    }
  }

  Future<void> deleteSecure(String key) async {
    _memoryCache.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    _memoryCache.clear();
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
