import 'api_service.dart';

class DashboardService {
  static Future<Map<String, dynamic>> fetchUserDashboard() async {
    try {
      final profileData = await ApiService.get(
        '/api/v1/user-profile/me',
        requireAuth: true,
      );

      final dailyCalorieGoal = profileData['daily_calorie_goal'] ?? 2000;

      final mealHistory = await ApiService.getList(
        '/api/v1/meals',
        requireAuth: true,
        queryParams: {
          'skip': '0',
          'limit': '100',
        },
      );

      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      int totalCalories = 0;
      for (final meal in mealHistory) {
        final createdAtRaw = meal['created_at'];
        if (createdAtRaw == null) continue;

        DateTime? createdAt;
        try {
          createdAt = DateTime.parse(createdAtRaw.toString()).toLocal();
        } catch (_) {
          continue;
        }

        if (createdAt.isAfter(
                todayStart.subtract(const Duration(milliseconds: 1))) &&
            createdAt.isBefore(todayEnd)) {
          totalCalories +=
              ((meal['total_calories'] as num?)?.toDouble() ?? 0).toInt();
        }
      }

      return {
        'dailyCalorieGoal': dailyCalorieGoal,
        'todayCalories': totalCalories,
        'success': true,
      };
    } catch (e) {
      return {
        'dailyCalorieGoal': 2000,
        'todayCalories': 0,
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
