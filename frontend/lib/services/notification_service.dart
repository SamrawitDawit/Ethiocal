import '../constants/app_constants.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  static Future<NotificationPreferences> getPreferences() async {
    final json = await ApiService.get(
      '${ApiConstants.notificationsEndpoint}/preferences',
      requireAuth: true,
    );
    return NotificationPreferences.fromJson(json);
  }

  static Future<NotificationPreferences> updatePreferences({
    bool? mealReminders,
    bool? healthAlerts,
    List<String>? reminderTimes,
  }) async {
    final body = <String, dynamic>{};
    if (mealReminders != null) body['meal_reminders'] = mealReminders;
    if (healthAlerts != null) body['health_alerts'] = healthAlerts;
    if (reminderTimes != null) body['reminder_times'] = reminderTimes;

    final json = await ApiService.patch(
      '${ApiConstants.notificationsEndpoint}/preferences',
      body,
      requireAuth: true,
    );
    return NotificationPreferences.fromJson(json);
  }

  static Future<List<AppNotification>> getNotifications({
    int skip = 0,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final params = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (unreadOnly) params['unread_only'] = 'true';

    final json = await ApiService.getList(
      ApiConstants.notificationsEndpoint,
      requireAuth: true,
      queryParams: params,
    );
    return json
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<int> getUnreadCount() async {
    final json = await ApiService.get(
      '${ApiConstants.notificationsEndpoint}/unread-count',
      requireAuth: true,
    );
    return json['unread_count'] ?? 0;
  }

  static Future<void> markAsRead(String notificationId) async {
    await ApiService.patch(
      '${ApiConstants.notificationsEndpoint}/$notificationId/read',
      {},
      requireAuth: true,
    );
  }

  static Future<void> markAllAsRead() async {
    await ApiService.patch(
      '${ApiConstants.notificationsEndpoint}/read-all',
      {},
      requireAuth: true,
    );
  }

  static Future<void> sendReminder() async {
    await ApiService.post(
      '${ApiConstants.notificationsEndpoint}/send-reminder',
      {},
      requireAuth: true,
    );
  }

  static Future<Map<String, dynamic>> checkHealthAlerts() async {
    return await ApiService.post(
      '${ApiConstants.notificationsEndpoint}/check-health-alerts',
      {},
      requireAuth: true,
    );
  }
}
