import 'food_model.dart';

class MealFoodItem {
  final String id;
  final String mealId;
  final String foodItemId;
  final double quantity;
  final double totalCalories;
  final FoodItem? foodItem;
  final String createdAt;

  MealFoodItem({
    required this.id,
    required this.mealId,
    required this.foodItemId,
    required this.quantity,
    required this.totalCalories,
    this.foodItem,
    required this.createdAt,
  });

  factory MealFoodItem.fromJson(Map<String, dynamic> json) {
    return MealFoodItem(
      id: json['id'],
      mealId: json['meal_id'],
      foodItemId: json['food_item_id'],
      quantity: (json['quantity'] as num).toDouble(),
      totalCalories: (json['total_calories'] as num).toDouble(),
      foodItem: json['food_item'] != null
          ? FoodItem.fromJson(json['food_item'])
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class MealIngredient {
  final String id;
  final String mealId;
  final String ingredientId;
  final double quantity;
  final double totalCalories;
  final Ingredient? ingredient;
  final String createdAt;

  MealIngredient({
    required this.id,
    required this.mealId,
    required this.ingredientId,
    required this.quantity,
    required this.totalCalories,
    this.ingredient,
    required this.createdAt,
  });

  factory MealIngredient.fromJson(Map<String, dynamic> json) {
    return MealIngredient(
      id: json['id'],
      mealId: json['meal_id'],
      ingredientId: json['ingredient_id'],
      quantity: (json['quantity'] as num).toDouble(),
      totalCalories: (json['total_calories'] as num).toDouble(),
      ingredient: json['ingredient'] != null
          ? Ingredient.fromJson(json['ingredient'])
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class Meal {
  final String id;
  final String userId;
  final String mealType;
  final double portionSize;
  final double totalCalories;
  final String? imageUrl;
  final String createdAt;
  final List<MealFoodItem> foodItems;
  final List<MealIngredient> ingredients;
  final List<MealFoodItemIngredient> foodItemIngredients;

  Meal({
    required this.id,
    required this.userId,
    required this.mealType,
    this.portionSize = 1.0,
    required this.totalCalories,
    this.imageUrl,
    required this.createdAt,
    this.foodItems = const [],
    this.ingredients = const [],
    this.foodItemIngredients = const [],
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'],
      userId: json['user_id'],
      mealType: json['meal_type'],
      portionSize: (json['portion_size'] as num?)?.toDouble() ?? 1.0,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'],
      createdAt: json['created_at'] ?? '',
      foodItems: (json['food_items'] as List?)
              ?.map((e) => MealFoodItem.fromJson(e))
              .toList() ??
          [],
      ingredients: (json['ingredients'] as List?)
              ?.map((e) => MealIngredient.fromJson(e))
              .toList() ??
          [],
      foodItemIngredients: (json['food_item_ingredients'] as List?)
              ?.map((e) => MealFoodItemIngredient.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class MealCreateResponse {
  final String id;
  final String userId;
  final String mealType;
  final double portionSize;
  final double totalCalories;
  final String? imageUrl;
  final List<MealFoodItem> foodItems;
  final String createdAt;

  MealCreateResponse({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.portionSize,
    required this.totalCalories,
    this.imageUrl,
    required this.foodItems,
    required this.createdAt,
  });

  factory MealCreateResponse.fromJson(Map<String, dynamic> json) {
    return MealCreateResponse(
      id: json['id'],
      userId: json['user_id'],
      mealType: json['meal_type'],
      portionSize: (json['portion_size'] as num).toDouble(),
      totalCalories: (json['total_calories'] as num).toDouble(),
      imageUrl: json['image_url'],
      foodItems: (json['food_items'] as List)
          .map((e) => MealFoodItem.fromJson(e))
          .toList(),
      createdAt: json['created_at'] ?? '',
    );
  }
}

class MealAddIngredientsResponse {
  final String mealId;
  final List<MealIngredient> ingredients;
  final double addedCalories;
  final double newTotalCalories;

  MealAddIngredientsResponse({
    required this.mealId,
    required this.ingredients,
    required this.addedCalories,
    required this.newTotalCalories,
  });

  factory MealAddIngredientsResponse.fromJson(Map<String, dynamic> json) {
    return MealAddIngredientsResponse(
      mealId: json['meal_id'],
      ingredients: (json['ingredients'] as List)
          .map((e) => MealIngredient.fromJson(e))
          .toList(),
      addedCalories: (json['added_calories'] as num).toDouble(),
      newTotalCalories: (json['new_total_calories'] as num).toDouble(),
    );
  }
}
