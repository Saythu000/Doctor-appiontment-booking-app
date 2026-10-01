import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../repository/health_repository.dart';
import '../repository/vitals_repository.dart';
import 'open_wearables_service.dart';

const String kPeriodicHealthSyncTask = 'drgodly_periodic_health_sync';
const String kPeriodicHealthSyncUniqueName = 'drgodly_health_sync_periodic_worker';

@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (kDebugMode) {
      print('[BackgroundSyncWorker] Executing background task: $taskName');
    }

    if (taskName == kPeriodicHealthSyncTask || taskName == Workmanager.iOSBackgroundTask) {
      try {
        final healthRepo = HealthRepository();
        final userId = await healthRepo.getSetting('iam_user_id') ?? 'usr_demo_101';
        final orgId = await healthRepo.getSetting('iam_org_id') ?? 'org_drgodly_default';

        final openWearablesService = OpenWearablesService();
        final vitals = await openWearablesService.fetchLatestVitals(
          userId: userId,
          orgId: orgId,
        );

        if (vitals != null) {
          final vitalsRepo = VitalsRepository();
          await vitalsRepo.submitVitals(vitals, userId: userId, orgId: orgId);
          if (kDebugMode) {
            print('[BackgroundSyncWorker] Successfully synced latest health metrics in background.');
          }
        }
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('[BackgroundSyncWorker] Error during background health sync: $e');
        }
        return false;
      }
    }
    return true;
  });
}

class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  static Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await Workmanager().initialize(
        backgroundSyncCallbackDispatcher,
      );
      if (kDebugMode) {
        print('[BackgroundSyncService] Workmanager initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BackgroundSyncService] Workmanager initialization failed: $e');
      }
    }
  }

  static Future<void> schedulePeriodicSync() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await Workmanager().registerPeriodicTask(
        kPeriodicHealthSyncUniqueName,
        kPeriodicHealthSyncTask,
        frequency: const Duration(hours: 1),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
      if (kDebugMode) {
        print('[BackgroundSyncService] Scheduled periodic background health sync (1h interval).');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[BackgroundSyncService] Failed to schedule periodic health sync: $e');
      }
    }
  }

  static Future<void> cancelAll() async {
    try {
      await Workmanager().cancelAll();
    } catch (e) {
      if (kDebugMode) {
        print('[BackgroundSyncService] Failed to cancel tasks: $e');
      }
    }
  }
}
