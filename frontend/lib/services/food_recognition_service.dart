import 'dart:typed_data';
import '../models/food_recognition_model.dart';
import '../models/food_model.dart';
import '../models/meal_model.dart';
import 'api_service.dart';
import 'meal_service.dart';

/// Service for food recognition via AI image analysis
class FoodRecognitionService {
  /// Recognize food items in an image without saving to history
  ///
  /// [imageBytes] - The image data as bytes
  /// [filename] - Original filename with extension
  /// [mealType] - Type of meal: breakfast, lunch, dinner, snack (default: snack)
  ///
  /// Returns [FoodRecognitionResponse] with detected foods
  static Future<FoodRecognitionResponse> recognizeFood(
    Uint8List imageBytes,
    String filename, {
    String mealType = 'snack',
  }) async {
    final response = await ApiService.uploadFileWithFields(
      '/api/v1/food/recognize',
      imageBytes,
      filename,
      fieldName: 'image',
      additionalFields: {
        'meal_type': mealType,
        'save_to_history': 'false',
      },
      requireAuth: true,
    );

    return FoodRecognitionResponse.fromJson(response);
  }

  /// Save recognized foods to meal history
  ///
  /// [mealType] - Type of meal: breakfast, lunch, dinner, snack
  /// [recognitionResult] - The food recognition response with detected foods
  /// [additionalIngredients] - Optional additional ingredients to add
  ///
  /// Returns [MealCreateResponse] with saved meal info
  static Future<MealCreateResponse> saveFoodRecognitionToHistory({
    required String mealType,
    required FoodRecognitionResponse recognitionResult,
    List<SelectedIngredient>? additionalIngredients,
  }) async {
    if (recognitionResult.predictions.isEmpty) {
      throw ApiException('No foods detected. Please add foods manually.', 400);
    }

    // Filter foods that have database matches
    final detectedFoods =
        recognitionResult.predictions.where((p) => p.foodItem != null).toList();

    if (detectedFoods.isEmpty) {
      throw ApiException(
          'No foods with database matches detected. Please add foods manually.',
          400);
    }

    // Build food items with actual portion grams as quantity
    final foodItems = <SelectedFoodItem>[];
    for (final prediction in detectedFoods) {
      final item = SelectedFoodItem(foodItem: prediction.foodItem!);
      // Store actual portion grams as quantity (AI-estimated value)
      item.quantity = prediction.portionGrams ?? 150.0;
      foodItems.add(item);
    }

    try {
      // Create meal using MealService with image_url to signal backend
      final mealResponse = await MealService.createMeal(
        mealType: mealType,
        foodItems: foodItems,
        portionSize: 1.0,
        imageUrl: recognitionResult.imageUrl,
      );

      // Add additional ingredients if provided
      if (additionalIngredients != null && additionalIngredients.isNotEmpty) {
        await MealService.addIngredientsToMeal(
          mealId: mealResponse.id,
          ingredients: additionalIngredients,
        );
      }

      return mealResponse;
    } catch (e) {
      throw Exception('Failed to save meal: $e');
    }
  }
}
