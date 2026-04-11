class NotificationPreferences {
  final String id;
  final String userId;
  final bool mealReminders;
  final bool healthAlerts;
  final List<String> reminderTimes;

  NotificationPreferences({
    required this.id,
    required this.userId,
    this.mealReminders = true,
    this.healthAlerts = true,
    this.reminderTimes = const ['08:00', '12:30', '18:30'],
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      id: json['id'],
      userId: json['user_id'],
      mealReminders: json['meal_reminders'] ?? true,
      healthAlerts: json['health_alerts'] ?? true,
      reminderTimes: (json['reminder_times'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['08:00', '12:30', '18:30'],
    );
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      title: json['title'],
      body: json['body'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}
