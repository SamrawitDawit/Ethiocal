import '../constants/app_constants.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import 'api_service.dart';

class MealService {
  static Future<List<FoodItem>> getFoodItems({String? search}) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final json = await ApiService.getList(
      ApiConstants.foodEndpoint,
      requireAuth: true,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    return json
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Ingredient>> getIngredients({String? search}) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final json = await ApiService.getList(
      ApiConstants.ingredientsEndpoint,
      requireAuth: true,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    return json
        .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<MealCreateResponse> createMeal({
    required String mealType,
    required List<SelectedFoodItem> foodItems,
    double portionSize = 1.0,
    String? imageUrl,
  }) async {
    final body = {
      'meal_type': mealType,
      'portion_size': portionSize,
      'food_items': foodItems
          .map((e) => {
                'food_item_id': e.foodItem.id,
                'quantity': e.quantity,
              })
          .toList(),
    };

    // Add image URL if provided
    if (imageUrl != null) {
      body['image_url'] = imageUrl;
    }

    final json = await ApiService.post(
      ApiConstants.mealsEndpoint,
      body,
      requireAuth: true,
    );

    return MealCreateResponse.fromJson(json);
  }

  static Future<MealAddIngredientsResponse> addIngredientsToMeal({
    required String mealId,
    required List<SelectedIngredient> ingredients,
  }) async {
    final body = {
      'ingredients': ingredients
          .map((e) => {
                'ingredient_id': e.ingredient.id,
                'quantity': e.quantity,
              })
          .toList(),
    };

    final json = await ApiService.post(
      '${ApiConstants.mealsEndpoint}/$mealId/ingredients',
      body,
      requireAuth: true,
    );

    return MealAddIngredientsResponse.fromJson(json);
  }

  static Future<List<Meal>> getMealHistory(
      {int skip = 0, int limit = 20}) async {
    final json = await ApiService.getList(
      ApiConstants.mealsEndpoint,
      requireAuth: true,
      queryParams: {
        'skip': skip.toString(),
        'limit': limit.toString(),
      },
    );

    return json.map((e) => Meal.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<FoodItemIngredient>> getFoodItemStandardIngredients(
      String foodItemId) async {
    final json = await ApiService.getList(
      '${ApiConstants.foodEndpoint}/$foodItemId/ingredients',
      requireAuth: true,
    );

    return json
        .map((e) => FoodItemIngredient.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
