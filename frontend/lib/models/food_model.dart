class FoodItem {
  final String id;
  final String name;
  final String? nameAmharic;
  final String? description;
  final String? category;
  final double standardServingSize;
  final double caloriesPerServing;
  final double carbohydrates;
  final double protein;
  final double fat;
  final double fiber;
  final double sodiumMg;
  final double sugar;
  final double cholesterolMg;
  final String source;
  final String? aiLabel;
  final String createdAt;

  FoodItem({
    required this.id,
    required this.name,
    this.nameAmharic,
    this.description,
    this.category,
    required this.standardServingSize,
    required this.caloriesPerServing,
    required this.carbohydrates,
    required this.protein,
    required this.fat,
    required this.fiber,
    this.sodiumMg = 0.0,
    this.sugar = 0.0,
    this.cholesterolMg = 0.0,
    this.source = 'manual',
    this.aiLabel,
    required this.createdAt,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'],
      name: json['name'],
      nameAmharic: json['name_amharic'],
      description: json['description'],
      category: json['category'],
      standardServingSize:
          (json['standard_serving_size'] as num?)?.toDouble() ?? 100.0,
      caloriesPerServing:
          (json['calories_per_100g'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
      cholesterolMg: (json['cholesterol_mg'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] ?? 'manual',
      aiLabel: json['ai_label'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class Ingredient {
  final String id;
  final String name;
  final String? nameAmharic;
  final String? category;
  final double standardServingSize;
  final double caloriesPerServing;
  final double carbohydrates;
  final double protein;
  final double fat;
  final String createdAt;

  Ingredient({
    required this.id,
    required this.name,
    this.nameAmharic,
    this.category,
    required this.standardServingSize,
    required this.caloriesPerServing,
    required this.carbohydrates,
    required this.protein,
    required this.fat,
    required this.createdAt,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'],
      name: json['name'],
      nameAmharic: json['name_amharic'],
      category: json['category'],
      standardServingSize:
          (json['standard_serving_size'] as num?)?.toDouble() ?? 10.0,
      caloriesPerServing:
          (json['calories_per_100g'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class SelectedFoodItem {
  final FoodItem foodItem;
  double quantity;

  SelectedFoodItem({
    required this.foodItem,
    this.quantity = 1.0,
  });

  double get totalCalories => foodItem.caloriesPerServing * quantity;
  double get totalProtein => foodItem.protein * quantity;
  double get totalCarbs => foodItem.carbohydrates * quantity;
  double get totalFat => foodItem.fat * quantity;
}

class SelectedIngredient {
  final Ingredient ingredient;
  double quantity;

  SelectedIngredient({
    required this.ingredient,
    this.quantity = 1.0,
  });

  double get totalCalories => ingredient.caloriesPerServing * quantity;
}

class FoodItemIngredient {
  final String id;
  final String foodItemId;
  final String ingredientId;
  final double standardQuantity;
  final Ingredient? ingredient;
  final String createdAt;

  FoodItemIngredient({
    required this.id,
    required this.foodItemId,
    required this.ingredientId,
    required this.standardQuantity,
    this.ingredient,
    required this.createdAt,
  });

  factory FoodItemIngredient.fromJson(Map<String, dynamic> json) {
    return FoodItemIngredient(
      id: json['id'],
      foodItemId: json['food_item_id'],
      ingredientId: json['ingredient_id'],
      standardQuantity: (json['quantity_grams'] as num?)?.toDouble() ?? 1.0,
      ingredient: json['ingredient'] != null
          ? Ingredient.fromJson(json['ingredient'])
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }
}
