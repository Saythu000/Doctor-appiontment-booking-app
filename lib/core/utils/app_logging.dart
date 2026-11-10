import 'package:flutter/foundation.dart';

/// Turns `debugPrint` into a no-op in release builds.
///
/// `debugPrint` is NOT stripped from release builds by default: its output goes
/// to logcat, where other tools (and anyone with adb) can read it. This app
/// logs request paths, error bodies and agent events that can contain tokens
/// or patient data, so release builds must log nothing.
///
/// Call this at the start of every isolate entry point (main and background
/// callbacks), because each isolate has its own copy of `debugPrint`.
void silenceDebugPrintInRelease() {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}
