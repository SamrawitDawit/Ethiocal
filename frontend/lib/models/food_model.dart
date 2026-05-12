class FoodItem {
  final String id;
  final String nameEnglish;
  final String? nameAmharic;
  final String? description;
  final String? descriptionEnglish;
  final String? descriptionAmharic;
  final String? category;
  final double standardServingSize;
  final double caloriesPerServing;
  final double carbohydrates;
  final double protein;
  final double fat;
  final double saturatedFatG;
  final double fiber;
  final double sodiumMg;
  final double sugar;
  final double cholesterolMg;
  final String source;
  final String? aiLabel;
  final String createdAt;

  FoodItem({
    required this.id,
    required this.nameEnglish,
    this.nameAmharic,
    this.description,
    this.descriptionEnglish,
    this.descriptionAmharic,
    this.category,
    required this.standardServingSize,
    required this.caloriesPerServing,
    required this.carbohydrates,
    required this.protein,
    required this.fat,
    this.saturatedFatG = 0.0,
    required this.fiber,
    this.sodiumMg = 0.0,
    this.sugar = 0.0,
    this.cholesterolMg = 0.0,
    this.source = 'manual',
    this.aiLabel,
    required this.createdAt,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final nameEnglish = ((json['name_english'] ?? json['name']) as String?)
      ?.trim();
    final descriptionEnglish =
      (json['description_english'] as String?)?.trim();
    final descriptionAmharic =
      (json['description_amharic'] as String?)?.trim();

    return FoodItem(
      id: json['id'],
      nameEnglish: nameEnglish ?? '',
      nameAmharic: json['name_amharic'],
      description: json['description'] as String?,
      descriptionEnglish: descriptionEnglish,
      descriptionAmharic: descriptionAmharic,
      category: json['category'],
      standardServingSize:
          (json['standard_serving_size'] as num?)?.toDouble() ?? 100.0,
      caloriesPerServing:
          (json['calories_per_100g'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      saturatedFatG: (json['saturated_fat_g'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      sugar: (json['sugar'] as num?)?.toDouble() ?? 0.0,
      cholesterolMg: (json['cholesterol_mg'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] ?? 'manual',
      aiLabel: json['ai_label'],
      createdAt: json['created_at'] ?? '',
    );
  }

  String get displayName => nameEnglish;

  String localizedTitle(bool isAmharic) {
    final amharicTitle = nameAmharic?.trim();
    if (isAmharic && amharicTitle != null && amharicTitle.isNotEmpty) {
      return amharicTitle;
    }

    return nameEnglish;
  }

  String? localizedDescription(bool isAmharic) {
    final amharicDescription = descriptionAmharic?.trim();
    if (isAmharic &&
        amharicDescription != null &&
        amharicDescription.isNotEmpty) {
      return amharicDescription;
    }

    final englishDescription = descriptionEnglish?.trim();
    if (englishDescription != null && englishDescription.isNotEmpty) {
      return englishDescription;
    }

    return null;
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
  final double saturatedFatG;
  final double fiber;
  final double sodiumMg;
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
    this.saturatedFatG = 0.0,
    this.fiber = 0.0,
    this.sodiumMg = 0.0,
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
      saturatedFatG: (json['saturated_fat_g'] as num?)?.toDouble() ?? 0.0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class SelectedFoodItem {
  final FoodItem foodItem;
  double quantity;
  String? mealFoodItemId; // Will be set after meal creation

  SelectedFoodItem({
    required this.foodItem,
    this.quantity = 1.0,
    this.mealFoodItemId,
  });

  double get totalCalories => foodItem.caloriesPerServing * quantity;
  double get totalProtein => foodItem.protein * quantity;
  double get totalCarbs => foodItem.carbohydrates * quantity;
  double get totalFat => foodItem.fat * quantity;
  double get totalSaturatedFatG => foodItem.saturatedFatG * quantity;
  double get totalFiber => foodItem.fiber * quantity;
  double get totalSodiumMg => foodItem.sodiumMg * quantity;
}

class SelectedIngredient {
  final Ingredient ingredient;
  double quantity;

  SelectedIngredient({
    required this.ingredient,
    this.quantity = 1.0,
  });

  double get totalCalories => ingredient.caloriesPerServing * quantity;
  double get totalProtein => ingredient.protein * quantity;
  double get totalCarbs => ingredient.carbohydrates * quantity;
  double get totalFat => ingredient.fat * quantity;
  double get totalSaturatedFatG => ingredient.saturatedFatG * quantity;
  double get totalFiber => ingredient.fiber * quantity;
  double get totalSodiumMg => ingredient.sodiumMg * quantity;
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

/// Per-food-item ingredient adjustment for meals (from backend)
class MealFoodItemIngredient {
  final String id;
  final String mealId;
  final String mealFoodItemId;
  final String ingredientId;
  final double quantity;
  final double standardQuantity;
  final double quantityDiff;
  final double totalCalories;
  final Ingredient? ingredient;
  final String createdAt;

  MealFoodItemIngredient({
    required this.id,
    required this.mealId,
    required this.mealFoodItemId,
    required this.ingredientId,
    required this.quantity,
    required this.standardQuantity,
    required this.quantityDiff,
    required this.totalCalories,
    this.ingredient,
    required this.createdAt,
  });

  factory MealFoodItemIngredient.fromJson(Map<String, dynamic> json) {
    return MealFoodItemIngredient(
      id: json['id'],
      mealId: json['meal_id'],
      mealFoodItemId: json['meal_food_item_id'],
      ingredientId: json['ingredient_id'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      standardQuantity: (json['standard_quantity'] as num?)?.toDouble() ?? 0.0,
      quantityDiff: (json['quantity_diff'] as num?)?.toDouble() ?? 0.0,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      ingredient: json['ingredient'] != null
          ? Ingredient.fromJson(json['ingredient'])
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }
}

/// Selected ingredient adjustment for a specific food item (frontend)
class SelectedIngredientPerFood {
  final Ingredient ingredient;
  double quantity;
  double standardQuantity; // The standard amount for this ingredient in this food item

  SelectedIngredientPerFood({
    required this.ingredient,
    this.quantity = 1.0,
    this.standardQuantity = 1.0,
  });

  /// Calories based on the difference from standard
  double get adjustedCalories {
    final diff = quantity - standardQuantity;
    return (diff / 100.0) * ingredient.caloriesPerServing;
  }
}
