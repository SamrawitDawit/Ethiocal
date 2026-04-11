import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/local_notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  NotificationPreferences? _preferences;
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  NotificationPreferences? get preferences => _preferences;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPreferences() async {
    try {
      _preferences = await NotificationService.getPreferences();
      _syncLocalSchedule();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updatePreferences({
    bool? mealReminders,
    bool? healthAlerts,
    List<String>? reminderTimes,
  }) async {
    try {
      _preferences = await NotificationService.updatePreferences(
        mealReminders: mealReminders,
        healthAlerts: healthAlerts,
        reminderTimes: reminderTimes,
      );
      _syncLocalSchedule();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Sync local scheduled notifications with server preferences.
  void _syncLocalSchedule() {
    if (_preferences == null) return;

    if (_preferences!.mealReminders && _preferences!.reminderTimes.isNotEmpty) {
      LocalNotificationService.scheduleMealReminders(
        reminderTimes: _preferences!.reminderTimes,
        title: 'Time to log your meal!',
        body: "Don't forget to log your meal to stay on track with your nutrition goals.",
      );
    } else {
      // Reminders disabled -- cancel all scheduled
      LocalNotificationService.cancelAll();
    }
  }

  Future<void> loadNotifications({bool unreadOnly = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _notifications = await NotificationService.getNotifications(
        unreadOnly: unreadOnly,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await NotificationService.getUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await NotificationService.markAsRead(notificationId);
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final n = _notifications[index];
        _notifications[index] = AppNotification(
          id: n.id,
          userId: n.userId,
          type: n.type,
          title: n.title,
          body: n.body,
          isRead: true,
          createdAt: n.createdAt,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await NotificationService.markAllAsRead();
      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                userId: n.userId,
                type: n.type,
                title: n.title,
                body: n.body,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> checkHealthAlerts() async {
    try {
      await NotificationService.checkHealthAlerts();
      await loadNotifications();
      await loadUnreadCount();
    } catch (_) {}
  }
}
