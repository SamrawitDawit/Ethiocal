import 'api_service.dart';

class DashboardService {
  static Future<Map<String, dynamic>> fetchUserDashboard() async {
    try {
      print('DEBUG: Fetching optimized daily summary...');
      
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];
      
      print('DEBUG: Fetching daily summary for date: $todayStr');
      
      // Single API call to get all dashboard data
      final summaryData = await ApiService.get(
        '/api/v1/daily-summary/',
        requireAuth: true,
        queryParams: {
          'date': todayStr,
        },
      );
      
      print('DEBUG: Daily summary data: $summaryData');

      if (summaryData['success'] == true) {
        return {
          'dailyCalorieGoal': summaryData['daily_calorie_goal'] ?? 2000,
          'todayCalories': summaryData['total_calories'] ?? 0,
          'success': true,
          'mealBreakdown': summaryData['meal_breakdown'] ?? {},
          'nutrientBreakdown': {
            'totalProtein': summaryData['total_protein'] ?? 0.0,
            'totalCarbohydrates': summaryData['total_carbohydrates'] ?? 0.0,
            'totalFat': summaryData['total_fat'] ?? 0.0,
            'totalCalories': summaryData['total_calories'] ?? 0.0,
            'mealCount': summaryData['meal_count'] ?? 0,
          },
        };
      } else {
        throw Exception('Daily summary returned success=false');
      }
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
      print('DEBUG: Fetching optimized calories for date: ${date.toIso8601String().split('T')[0]}');
      
      final dateStr = date.toIso8601String().split('T')[0];
      
      // Single API call to get daily summary
      final summaryData = await ApiService.get(
        '/api/v1/daily-summary/',
        requireAuth: true,
        queryParams: {
          'date': dateStr,
        },
      );
      
      print('DEBUG: Summary data for date $dateStr: $summaryData');

      if (summaryData['success'] == true) {
        return {
          'date': date,
          'calories': summaryData['total_calories'] ?? 0,
          'target': summaryData['daily_calorie_goal'] ?? 2000,
          'success': true,
        };
      } else {
        throw Exception('Daily summary returned success=false');
      }
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
      print('DEBUG: Fetching optimized meal breakdown for date: ${date.toIso8601String().split('T')[0]}');
      
      final dateStr = date.toIso8601String().split('T')[0];
      
      // Single API call to get daily summary with meal breakdown
      final summaryData = await ApiService.get(
        '/api/v1/daily-summary/',
        requireAuth: true,
        queryParams: {
          'date': dateStr,
        },
      );
      
      print('DEBUG: Summary data for meal breakdown $dateStr: $summaryData');

      if (summaryData['success'] == true) {
        return {
          'date': date,
          'mealBreakdown': summaryData['meal_breakdown'] ?? {
            'breakfast': {'calories': 0, 'count': 0},
            'lunch': {'calories': 0, 'count': 0},
            'dinner': {'calories': 0, 'count': 0},
            'snack': {'calories': 0, 'count': 0},
          },
          'success': true,
        };
      } else {
        throw Exception('Daily summary returned success=false');
      }
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
      print('DEBUG: Fetching optimized daily nutrients for date: ${date.toIso8601String().split('T')[0]}');
      
      final dateStr = date.toIso8601String().split('T')[0];
      
      // Single API call to get daily summary with nutrient breakdown
      final summaryData = await ApiService.get(
        '/api/v1/daily-summary/',
        requireAuth: true,
        queryParams: {
          'date': dateStr,
        },
      );
      
      print('DEBUG: Summary data for nutrients $dateStr: $summaryData');

      if (summaryData['success'] == true) {
        return {
          'date': dateStr,
          'totalProtein': summaryData['total_protein'] ?? 0.0,
          'totalCarbohydrates': summaryData['total_carbohydrates'] ?? 0.0,
          'totalFat': summaryData['total_fat'] ?? 0.0,
          'totalCalories': summaryData['total_calories'] ?? 0.0,
          'mealCount': summaryData['meal_count'] ?? 0,
          'success': true,
        };
      } else {
        throw Exception('Daily summary returned success=false');
      }
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
