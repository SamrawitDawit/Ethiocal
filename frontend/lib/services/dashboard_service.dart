import 'api_service.dart';

class DashboardService {
  static Future<Map<String, dynamic>> fetchUserDashboard() async {
  try {
    print('DEBUG: Fetching user profile...');
    final profileData =
        await ApiService.get('/api/v1/users/me', requireAuth: true);
    print('DEBUG: Profile data: $profileData');

    final dailyCalorieGoal = profileData['daily_calorie_goal'] ?? 2000;
    print('DEBUG: Daily calorie goal: $dailyCalorieGoal');

    // Try to get meal items, but don't let failure break the entire dashboard
    int totalCalories = 0;
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      print('DEBUG: Fetching meal items for date: ${todayStart.toIso8601String().split('T')[0]}');
      final mealItemsData = await ApiService.get(
        '/api/v1/meals/meal-food-items',
        requireAuth: true,
        queryParams: {
          'date': todayStart.toIso8601String().split('T')[0]
        },
      );
      print('DEBUG: Meal items data: $mealItemsData');

      if (mealItemsData['meal_food_items'] != null) {
        final mealItems = mealItemsData['meal_food_items'] as List;
        print('DEBUG: Processing ${mealItems.length} meal items');
        for (final item in mealItems) {
          if (item['total_calories'] != null) {
            totalCalories += (item['total_calories'] as num).toInt();
          }
        }
      }
      print('DEBUG: Total calories: $totalCalories');
    } catch (e) {
      print('DEBUG: Failed to fetch meal items, using 0 calories: $e');
      // Continue with 0 calories if meal items fetch fails
    }

    return {
      'dailyCalorieGoal': dailyCalorieGoal,
      'todayCalories': totalCalories,
      'success': true,
    };
  } catch (e) {
    print('ERROR in fetchUserDashboard: $e');
    return {
      'dailyCalorieGoal': 2000,
      'todayCalories': 0,
      'success': false,
      'error': e.toString(),
    };
  }
}

}
