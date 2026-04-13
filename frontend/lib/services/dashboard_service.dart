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

  static Future<Map<String, dynamic>> fetchCaloriesForDate(DateTime date) async {
    try {
      print('DEBUG: Fetching calories for date: ${date.toIso8601String().split('T')[0]}');
      
      // Get user profile for daily calorie goal
      final profileData = await ApiService.get('/api/v1/users/me', requireAuth: true);
      final dailyCalorieGoal = profileData['daily_calorie_goal'] ?? 2000;
      
      // Get meal items for the specific date
      final dateStart = DateTime(date.year, date.month, date.day);
      final mealItemsData = await ApiService.get(
        '/api/v1/meals/meal-food-items',
        requireAuth: true,
        queryParams: {
          'date': dateStart.toIso8601String().split('T')[0]
        },
      );
      
      int totalCalories = 0;
      if (mealItemsData['meal_food_items'] != null) {
        final mealItems = mealItemsData['meal_food_items'] as List;
        for (final item in mealItems) {
          if (item['total_calories'] != null) {
            totalCalories += (item['total_calories'] as num).toInt();
          }
        }
      }
      
      return {
        'date': dateStart,
        'calories': totalCalories,
        'target': dailyCalorieGoal,
        'success': true,
      };
    } catch (e) {
      print('ERROR in fetchCaloriesForDate: $e');
      return {
        'date': date,
        'calories': 0,
        'target': 2000,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchMealBreakdownForDate(DateTime date) async {
    try {
      print('DEBUG: Fetching meal breakdown for date: ${date.toIso8601String().split('T')[0]}');
      
      // Get meals for specific date to get meal types
      final dateStart = DateTime(date.year, date.month, date.day);
      final mealsData = await ApiService.getList(
        '/api/v1/meals/',
        requireAuth: true,
        queryParams: {
          'date': dateStart.toIso8601String().split('T')[0]
        },
      );
      
      print('DEBUG: Received ${mealsData.length} meals'); // This will work now
      
      // Initialize meal type breakdown
      final mealBreakdown = {
        'breakfast': {'calories': 0, 'count': 0},
        'lunch': {'calories': 0, 'count': 0},
        'dinner': {'calories': 0, 'count': 0},
        'snack': {'calories': 0, 'count': 0},
      };
      
      // mealsData is already a List, so we can iterate directly
      for (final meal in mealsData) {
        final mealType = meal['meal_type'] as String;
        final calories = (meal['total_calories'] as num).toInt();
        
        print('DEBUG: Processing meal - Type: $mealType, Calories: $calories');
        
        if (mealBreakdown.containsKey(mealType)) {
          final currentCalories = mealBreakdown[mealType]?['calories'] as int;
          final currentCount = mealBreakdown[mealType]?['count'] as int;
          mealBreakdown[mealType]?['calories'] = currentCalories + calories;
          mealBreakdown[mealType]?['count'] = currentCount + 1;
        }
      }
      
      print('DEBUG: Meal breakdown: $mealBreakdown');
      
      return {
        'date': dateStart,
        'mealBreakdown': mealBreakdown,
        'success': true,
      };
    } catch (e) {
      print('ERROR in fetchMealBreakdownForDate: $e');
      return {
        'date': date,
        'mealBreakdown': {
          'breakfast': {'calories': 0, 'count': 0},
          'lunch': {'calories': 0, 'count': 0},
          'dinner': {'calories': 0, 'count': 0},
          'snack': {'calories': 0, 'count': 0},
        },
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchDailyNutrients(DateTime date) async {
    try {
      print('DEBUG: Fetching daily nutrients for date: ${date.toIso8601String().split('T')[0]}');
      
      final dateStr = DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];
      
      final nutrientsData = await ApiService.get(
        '/api/v1/meals/daily-nutrients',
        requireAuth: true,
        queryParams: {
          'date': dateStr
        },
      );
      
      print('DEBUG: Nutrients data: $nutrientsData');
      
      return {
        'date': dateStr,
        'totalProtein': nutrientsData['total_protein'] ?? 0.0,
        'totalCarbohydrates': nutrientsData['total_carbohydrates'] ?? 0.0,
        'totalFat': nutrientsData['total_fat'] ?? 0.0,
        'totalCalories': nutrientsData['total_calories'] ?? 0.0,
        'mealCount': nutrientsData['meal_count'] ?? 0,
        'success': true,
      };
    } catch (e) {
      print('ERROR in fetchDailyNutrients: $e');
      return {
        'date': date.toIso8601String().split('T')[0],
        'totalProtein': 0.0,
        'totalCarbohydrates': 0.0,
        'totalFat': 0.0,
        'totalCalories': 0.0,
        'mealCount': 0,
        'success': false,
        'error': e.toString(),
      };
    }
  }

}
