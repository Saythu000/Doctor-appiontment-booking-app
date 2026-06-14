import 'package:flutter/foundation.dart';
import '../../data/repository/health_repository.dart';
import '../data/service/notification_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final HealthRepository healthRepository;

  String weightUnit = 'kg';
  String heightUnit = 'cm';
  String tempUnit = '°C';
  String glucoseUnit = 'mg/dL';
  String appLanguage = 'English';
  String startWeekDay = 'Sunday';
  String? lastCloudSyncTime;

  List<Map<String, dynamic>> remindersList = [];
  List<Map<String, dynamic>> inAppNotificationsList = [];
  Map<String, Map<String, double>> vitalsThresholds = {
    'steps': {'min': 0, 'max': 10000},
    'systolic': {'min': 90, 'max': 140},
    'diastolic': {'min': 60, 'max': 90},
    'heart_rate': {'min': 50, 'max': 100},
  };

  SettingsViewModel({required this.healthRepository}) {
    loadAppSettings();
  }

  Future<void> loadAppSettings() async {
    weightUnit = await healthRepository.getSetting('weightUnit') ?? 'kg';
    heightUnit = await healthRepository.getSetting('heightUnit') ?? 'cm';
    tempUnit = await healthRepository.getSetting('tempUnit') ?? '°C';
    glucoseUnit = await healthRepository.getSetting('glucoseUnit') ?? 'mg/dL';
    appLanguage = await healthRepository.getSetting('appLanguage') ?? 'English';
    startWeekDay = await healthRepository.getSetting('startWeekDay') ?? 'Sunday';
    lastCloudSyncTime = await healthRepository.getSetting('lastCloudSyncTime');

    // Load reminders
    remindersList = await healthRepository.getReminders();

    // Load thresholds
    final dbThresholds = await healthRepository.getVitalsThresholds();
    dbThresholds.forEach((key, val) {
      vitalsThresholds[key] = val;
    });

    // Load in-app notifications
    inAppNotificationsList = await healthRepository.getInAppNotifications();

    // Synchronize scheduled notifications with loaded reminders
    for (var r in remindersList) {
      final id = r['id'] as String;
      final isActive = (r['is_active'] as int) == 1;
      if (isActive) {
        await NotificationService.instance.scheduleReminderNotifications(
          reminderId: id,
          title: r['title'] as String,
          type: r['type'] as String,
          timeStr: r['time'] as String,
          daysStr: r['days'] as String,
        );
      } else {
        await NotificationService.instance.cancelReminderNotifications(id);
      }
    }

    notifyListeners();
  }

  Future<void> saveSetting(String key, String value) async {
    await healthRepository.saveSetting(key, value);
    if (key == 'weightUnit') weightUnit = value;
    if (key == 'heightUnit') heightUnit = value;
    if (key == 'tempUnit') tempUnit = value;
    if (key == 'glucoseUnit') glucoseUnit = value;
    if (key == 'appLanguage') appLanguage = value;
    if (key == 'startWeekDay') startWeekDay = value;
    notifyListeners();
  }

  Future<void> saveReminder(Map<String, dynamic> reminder) async {
    await healthRepository.saveReminder(reminder);
    remindersList = await healthRepository.getReminders();

    final id = reminder['id'] as String;
    final isActive = (reminder['is_active'] as int) == 1;

    if (isActive) {
      await NotificationService.instance.scheduleReminderNotifications(
        reminderId: id,
        title: reminder['title'] as String,
        type: reminder['type'] as String,
        timeStr: reminder['time'] as String,
        daysStr: reminder['days'] as String,
      );
    } else {
      await NotificationService.instance.cancelReminderNotifications(id);
    }

    notifyListeners();
  }

  Future<void> toggleReminder(String id, bool isActive) async {
    final reminderMap = remindersList.firstWhere((r) => r['id'] == id);
    final updated = Map<String, dynamic>.from(reminderMap);
    updated['is_active'] = isActive ? 1 : 0;
    
    await healthRepository.saveReminder(updated);
    remindersList = await healthRepository.getReminders();

    if (isActive) {
      await NotificationService.instance.scheduleReminderNotifications(
        reminderId: id,
        title: updated['title'] as String,
        type: updated['type'] as String,
        timeStr: updated['time'] as String,
        daysStr: updated['days'] as String,
      );
    } else {
      await NotificationService.instance.cancelReminderNotifications(id);
    }

    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    await healthRepository.deleteReminder(id);
    remindersList = await healthRepository.getReminders();
    await NotificationService.instance.cancelReminderNotifications(id);
    notifyListeners();
  }

  Future<void> saveThreshold(String metric, double minVal, double maxVal) async {
    await healthRepository.saveVitalThreshold(metric, minVal, maxVal);
    vitalsThresholds[metric] = {'min': minVal, 'max': maxVal};
    notifyListeners();
  }

  // --- In-App Notifications State Handlers ---
  Future<void> fetchInAppNotifications() async {
    inAppNotificationsList = await healthRepository.getInAppNotifications();
    notifyListeners();
  }

  Future<void> addInAppNotification(String title, String body, String type) async {
    final notification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': title,
      'body': body,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': 0,
    };
    await healthRepository.saveInAppNotification(notification);
    await fetchInAppNotifications();
  }

  Future<void> markNotificationAsRead(String id) async {
    await healthRepository.markNotificationAsRead(id);
    await fetchInAppNotifications();
  }

  Future<void> deleteInAppNotification(String id) async {
    await healthRepository.deleteInAppNotification(id);
    await fetchInAppNotifications();
  }

  Future<void> clearAllInAppNotifications() async {
    await healthRepository.clearAllInAppNotifications();
    await fetchInAppNotifications();
  }
}
