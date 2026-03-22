class FoodEntry {
  final String name;
  final int grams;

  FoodEntry({
    required this.name,
    required this.grams,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'grams': grams,
    };
  }

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
      name: json['name'] as String,
      grams: json['grams'] as int,
    );
  }
}

class NutritionRequest {
  final List<FoodEntry> foods;

  NutritionRequest({
    required this.foods,
  });

  Map<String, dynamic> toJson() {
    return {
      'foods': foods.map((food) => food.toJson()).toList(),
    };
  }
}

class NutritionResponse {
  final double totalCalories;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;
  final List<FoodNutrition> foods;

  NutritionResponse({
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    required this.foods,
  });

  factory NutritionResponse.fromJson(Map<String, dynamic> json) {
    final foodsList = (json['foods'] as List)
        .map((food) => FoodNutrition.fromJson(food as Map<String, dynamic>))
        .toList();
    
    final total = json['total'] as Map<String, dynamic>;
    
    return NutritionResponse(
      totalCalories: (total['calories'] as num).toDouble(),
      totalProtein: (total['protein'] as num).toDouble(),
      totalFat: (total['fat'] as num).toDouble(),
      totalCarbs: (total['carbs'] as num).toDouble(),
      foods: foodsList,
    );
  }
}

class FoodNutrition {
  final String food;
  final double grams;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  FoodNutrition({
    required this.food,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory FoodNutrition.fromJson(Map<String, dynamic> json) {
    return FoodNutrition(
      food: json['food'] as String,
      grams: (json['grams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
    );
  }
}
