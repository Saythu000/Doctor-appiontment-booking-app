import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Keeps the profile photo in the app's private storage.
///
/// The image picker returns a temporary cache file that Android may delete
/// at any time, so the picked photo is copied here before its path is saved.
abstract final class ProfilePhotoStore {
  static const _prefix = 'profile_photo_';

  static Future<Directory> _dir() async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'profile'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Copies [sourcePath] into app storage and returns the new path.
  static Future<String> keep(String sourcePath) async {
    final dir = await _dir();
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final target = p.join(dir.path, '$_prefix${DateTime.now().millisecondsSinceEpoch}$ext');
    await File(sourcePath).copy(target);
    return target;
  }

  /// Deletes an old photo this store created. Other paths are left alone.
  static Future<void> discard(String? path, {String? keep}) async {
    if (path == null || path == keep || !p.basename(path).startsWith(_prefix)) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (e) {
      debugPrint('Could not delete old profile photo: $e');
    }
  }

  /// Deletes every stored profile photo (used on sign-out, so the next
  /// person on this phone never sees the previous user's photo).
  static Future<void> deleteAll() async {
    try {
      final dir = await _dir();
      for (final f in dir.listSync().whereType<File>()) {
        if (p.basename(f.path).startsWith(_prefix)) await f.delete();
      }
    } catch (e) {
      debugPrint('Could not delete profile photos: $e');
    }
  }
}
