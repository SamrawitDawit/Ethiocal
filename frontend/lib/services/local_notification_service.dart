import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _mealReminderBaseId = 1000;
  static const int _mealReminderLimit = 10;

  static Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings);

    // Request notification permission on Android 13+
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ethiocal_notifications',
      'EthioCal Notifications',
      channelDescription: 'Meal reminders and health alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  /// Schedule daily repeating meal reminders at given times.
  /// [reminderTimes] is a list of "HH:mm" strings.
  static Future<void> scheduleMealReminders({
    required List<String> reminderTimes,
    required String title,
    required String body,
  }) async {
    await cancelMealReminders();

    const androidDetails = AndroidNotificationDetails(
      'ethiocal_meal_reminders',
      'Meal Reminders',
      channelDescription: 'Reminders to log your meals',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final location = tz.local;

    for (int i = 0; i < reminderTimes.length && i < _mealReminderLimit; i++) {
      final parts = reminderTimes[i].split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      final now = tz.TZDateTime.now(location);
      var scheduledDate = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If the time has passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      try {
        await _plugin.zonedSchedule(
          _mealReminderBaseId + i,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        debugPrint(
            'Scheduled meal reminder at ${reminderTimes[i]} (id: ${_mealReminderBaseId + i})');
      } catch (e) {
        debugPrint('Failed to schedule notification: $e');
      }
    }
  }

  static Future<void> cancelMealReminders() async {
    for (int i = 0; i < _mealReminderLimit; i++) {
      await _plugin.cancel(_mealReminderBaseId + i);
    }
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
