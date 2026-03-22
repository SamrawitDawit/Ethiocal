import '../models/food_entry.dart';
import '../services/api_service.dart';

class NutritionService {
  static Future<NutritionResponse> calculateCalories(List<FoodEntry> foods) async {
    final request = NutritionRequest(foods: foods);
    
    try {
      final response = await ApiService.post(
        '/api/v1/nutrition/calculate-calories',
        request.toJson(),
      );
      
      return NutritionResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to calculate calories: $e');
    }
  }
}
