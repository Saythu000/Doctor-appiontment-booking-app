import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'open_wearables_service.dart';

@pragma('vm:entry-point')
void startVitalsCallback() {
  FlutterForegroundTask.setTaskHandler(VitalsTaskHandler());
}

class VitalsTaskHandler extends TaskHandler {
  final OpenWearablesService _service = OpenWearablesService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    if (kDebugMode) {
      print('[VitalsTaskHandler] Foreground sync service started at $timestamp');
    }
    await _performSync();
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    if (kDebugMode) {
      print('[VitalsTaskHandler] Recurring background sync triggered at $timestamp');
    }
    await _performSync();
  }

  Future<void> _performSync() async {
    try {
      final vitals = await _service.fetchLatestVitals(
        userId: 'patient-drgodly-01',
        orgId: 'org-drgodly-dev',
      );
      if (vitals != null) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'DrGodly Active Sync',
          notificationText: 'Last synced: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')} • Steps: ${vitals.steps}',
        );
        FlutterForegroundTask.sendDataToMain({
          'steps': vitals.steps,
          'restingHr': vitals.restingHeartRate,
          'hrv': vitals.heartRateVariability,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VitalsTaskHandler] Error during background sync: $e');
      }
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (kDebugMode) {
      print('[VitalsTaskHandler] Foreground sync destroyed.');
    }
  }

  @override
  void onReceiveData(Object data) {}

  @override
  void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {}
}

class VitalsForegroundService {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'drgodly_vitals_sync',
        channelName: 'DrGodly Vitals Auto-Sync',
        channelDescription: 'Maintains continuous background synchronization with Health Connect & wearable devices.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15 * 60000), // 15 minutes
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> start() async {
    if (!Platform.isAndroid) return;
    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (!isRunning) {
        await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: 'DrGodly Active Sync',
          notificationText: 'Clinical vitals synchronized in real-time',
          callback: startVitalsCallback,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VitalsForegroundService] Failed to start foreground service: $e');
      }
    }
  }

  static Future<void> stop() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      if (kDebugMode) {
        print('[VitalsForegroundService] Failed to stop foreground service: $e');
      }
    }
  }
}
