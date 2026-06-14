import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import '../repository/health_repository.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  NotificationService._init();

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Initialize Timezones
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Failed to set local location, using UTC fallback: $e');
      }
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2. Configure Android & iOS Initialization Settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 3. Initialize Plugin
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print('[NotificationService] Notification clicked: ${response.payload}');
        }
      },
    );

    _isInitialized = true;
    if (kDebugMode) {
      print('[NotificationService] Successfully initialized.');
    }
  }

  /// Request permissions for local notifications and exact alarms
  Future<bool> requestPermissions() async {
    // Check and request notification permissions
    final status = await Permission.notification.request();
    
    // On Android 13+, check exact alarm permission
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    return status.isGranted;
  }

  /// Helper to get next instance of a specific time
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Helper to get next instance of a weekday at a specific time
  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Build channel details for Android
  NotificationDetails _buildChannelDetails({
    required String channelId,
    required String channelName,
    required String channelDesc,
    Importance importance = Importance.max,
    Priority priority = Priority.high,
  }) {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      playSound: true,
      enableVibration: true,
      styleInformation: const BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Show an immediate high-priority alert (congratulatory, warnings, etc.)
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String channelId = 'immediate_alerts',
    String channelName = 'Immediate Alerts',
    String channelDesc = 'Critical vitals alerts and congratulations',
    String type = 'WARNING',
  }) async {
    final details = _buildChannelDetails(
      channelId: channelId,
      channelName: channelName,
      channelDesc: channelDesc,
    );

    await _localNotifications.show(id, title, body, details);

    // Save alert to SQLite DB for in-app notification log
    try {
      final repository = HealthRepository();
      await repository.saveInAppNotification({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'body': body,
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
      });
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] Failed to log immediate notification to SQLite: $e');
      }
    }
  }

  /// Schedule a one-off notification for a specific future date and time (e.g. Appointment)
  Future<void> scheduleOneOffNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDateTime,
  }) async {
    final details = _buildChannelDetails(
      channelId: 'appointments',
      channelName: 'Appointments',
      channelDesc: 'Appointment check-in alerts',
    );

    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledDateTime, tz.local);
    if (tzTime.isBefore(tz.TZDateTime.now(tz.local))) {
      // Don't schedule past dates
      return;
    }

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule daily or weekly medication / vitals check alarms
  Future<void> scheduleReminderNotifications({
    required String reminderId,
    required String title,
    required String type,
    required String timeStr, // Format: "HH:mm"
    required String daysStr, // Format: "Sun,Mon..." or "Daily"
  }) async {
    // Parse time
    final parts = timeStr.split(':');
    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);

    // Unique numeric ID base from reminderId hash
    final int idBase = reminderId.hashCode.abs() % 100000;

    final details = _buildChannelDetails(
      channelId: 'reminders',
      channelName: 'Reminders',
      channelDesc: 'Medication and Vitals check-in alarms',
    );

    if (daysStr.trim().toLowerCase() == 'daily') {
      // Schedule daily recurring
      final scheduledDate = _nextInstanceOfTime(hour, minute);
      await _localNotifications.zonedSchedule(
        idBase,
        '$type Reminder',
        title,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // Schedule for specific days weekly
      final days = daysStr.split(',');
      for (var day in days) {
        final weekday = _mapDayToWeekday(day);
        final scheduledDate = _nextInstanceOfWeekdayAndTime(weekday, hour, minute);
        
        // Create unique ID for each day of the week reminder
        final int finalId = idBase + weekday;

        await _localNotifications.zonedSchedule(
          finalId,
          '$type Reminder',
          title,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  /// Cancel all scheduled alarms for a specific reminder
  Future<void> cancelReminderNotifications(String reminderId) async {
    final int idBase = reminderId.hashCode.abs() % 100000;
    // Cancel the daily ID
    await _localNotifications.cancel(idBase);
    
    // Cancel all possible weekly weekday IDs (1-7)
    for (int weekday = 1; weekday <= 7; weekday++) {
      await _localNotifications.cancel(idBase + weekday);
    }
  }

  /// Cancel a single notification by exact ID
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
  }

  int _mapDayToWeekday(String dayStr) {
    switch (dayStr.trim().toLowerCase()) {
      case 'mon':
        return DateTime.monday;
      case 'tue':
        return DateTime.tuesday;
      case 'wed':
        return DateTime.wednesday;
      case 'thu':
        return DateTime.thursday;
      case 'fri':
        return DateTime.friday;
      case 'sat':
        return DateTime.saturday;
      case 'sun':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }
}
