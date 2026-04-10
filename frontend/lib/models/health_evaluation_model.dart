class NutrientSnapshot {
  final double calories;
  final double sugarG;
  final double sodiumMg;
  final double cholesterolMg;
  final double fatG;

  NutrientSnapshot({
    required this.calories,
    this.sugarG = 0.0,
    this.sodiumMg = 0.0,
    this.cholesterolMg = 0.0,
    this.fatG = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'sugar_g': sugarG,
      'sodium_mg': sodiumMg,
      'cholesterol_mg': cholesterolMg,
      'fat_g': fatG,
    };
  }
}

class CalorieEvaluation {
  final double? dailyGoal;
  final double consumedToday;
  final double mealCalories;
  final double projectedTotal;
  final bool? exceedsLimit;

  CalorieEvaluation({
    this.dailyGoal,
    required this.consumedToday,
    required this.mealCalories,
    required this.projectedTotal,
    this.exceedsLimit,
  });

  factory CalorieEvaluation.fromJson(Map<String, dynamic> json) {
    return CalorieEvaluation(
      dailyGoal: (json['daily_goal'] as num?)?.toDouble(),
      consumedToday: (json['consumed_today'] as num?)?.toDouble() ?? 0.0,
      mealCalories: (json['meal_calories'] as num?)?.toDouble() ?? 0.0,
      projectedTotal: (json['projected_total'] as num?)?.toDouble() ?? 0.0,
      exceedsLimit: json['exceeds_limit'],
    );
  }
}

class ConditionEvaluation {
  final String conditionName;
  final String restrictedNutrient;
  final double thresholdAmount;
  final String thresholdUnit;
  final double consumedTodayAmount;
  final double mealAmount;
  final double projectedAmount;
  final double consumedAmount;
  final String consumedUnit;
  final bool exceedsLimit;
  final bool isCloseToLimit;

  ConditionEvaluation({
    required this.conditionName,
    required this.restrictedNutrient,
    required this.thresholdAmount,
    required this.thresholdUnit,
    this.consumedTodayAmount = 0.0,
    this.mealAmount = 0.0,
    this.projectedAmount = 0.0,
    required this.consumedAmount,
    required this.consumedUnit,
    required this.exceedsLimit,
    required this.isCloseToLimit,
  });

  factory ConditionEvaluation.fromJson(Map<String, dynamic> json) {
    return ConditionEvaluation(
      conditionName: json['condition_name'] ?? '',
      restrictedNutrient: json['restricted_nutrient'] ?? '',
      thresholdAmount: (json['threshold_amount'] as num?)?.toDouble() ?? 0.0,
      thresholdUnit: json['threshold_unit'] ?? '',
      consumedTodayAmount:
          (json['consumed_today_amount'] as num?)?.toDouble() ?? 0.0,
      mealAmount: (json['meal_amount'] as num?)?.toDouble() ?? 0.0,
      projectedAmount: (json['projected_amount'] as num?)?.toDouble() ??
          (json['consumed_amount'] as num?)?.toDouble() ??
          0.0,
      consumedAmount: (json['consumed_amount'] as num?)?.toDouble() ?? 0.0,
      consumedUnit: json['consumed_unit'] ?? '',
      exceedsLimit: json['exceeds_limit'] ?? false,
      isCloseToLimit: json['is_close_to_limit'] ?? false,
    );
  }
}

class HealthEvaluationResult {
  final String status;
  final String message;
  final String evaluatedAt;
  final CalorieEvaluation calorie;
  final List<ConditionEvaluation> conditions;

  HealthEvaluationResult({
    required this.status,
    required this.message,
    required this.evaluatedAt,
    required this.calorie,
    required this.conditions,
  });

  factory HealthEvaluationResult.fromJson(Map<String, dynamic> json) {
    final conditions = (json['conditions'] as List<dynamic>? ?? [])
        .map((e) => ConditionEvaluation.fromJson(e as Map<String, dynamic>))
        .toList();

    return HealthEvaluationResult(
      status: json['status'] ?? 'good',
      message: json['message'] ?? '',
      evaluatedAt: json['evaluated_at'] ?? '',
      calorie: CalorieEvaluation.fromJson(json['calorie'] ?? {}),
      conditions: conditions,
    );
  }
}

class DailyNutrients {
  final double calories;
  final double sugarG;
  final double sodiumMg;
  final double cholesterolMg;
  final double fatG;

  DailyNutrients({
    required this.calories,
    required this.sugarG,
    required this.sodiumMg,
    required this.cholesterolMg,
    required this.fatG,
  });

  factory DailyNutrients.fromJson(Map<String, dynamic> json) {
    return DailyNutrients(
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      sugarG: (json['sugar_g'] as num?)?.toDouble() ?? 0.0,
      sodiumMg: (json['sodium_mg'] as num?)?.toDouble() ?? 0.0,
      cholesterolMg: (json['cholesterol_mg'] as num?)?.toDouble() ?? 0.0,
      fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DailyConditionStatus {
  final String conditionName;
  final String restrictedNutrient;
  final double thresholdAmount;
  final String thresholdUnit;
  final double consumedAmount;
  final double remainingAmount;
  final bool exceedsLimit;

  DailyConditionStatus({
    required this.conditionName,
    required this.restrictedNutrient,
    required this.thresholdAmount,
    required this.thresholdUnit,
    required this.consumedAmount,
    required this.remainingAmount,
    required this.exceedsLimit,
  });

  factory DailyConditionStatus.fromJson(Map<String, dynamic> json) {
    return DailyConditionStatus(
      conditionName: json['condition_name'] ?? '',
      restrictedNutrient: json['restricted_nutrient'] ?? '',
      thresholdAmount: (json['threshold_amount'] as num?)?.toDouble() ?? 0.0,
      thresholdUnit: json['threshold_unit'] ?? '',
      consumedAmount: (json['consumed_amount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 0.0,
      exceedsLimit: json['exceeds_limit'] ?? false,
    );
  }
}

class DailyHealthSummary {
  final String date;
  final double? dailyCalorieGoal;
  final DailyNutrients nutrientsConsumed;
  final List<DailyConditionStatus> conditionStatuses;

  DailyHealthSummary({
    required this.date,
    this.dailyCalorieGoal,
    required this.nutrientsConsumed,
    required this.conditionStatuses,
  });

  factory DailyHealthSummary.fromJson(Map<String, dynamic> json) {
    final statuses = (json['condition_statuses'] as List<dynamic>? ?? [])
        .map((e) => DailyConditionStatus.fromJson(e as Map<String, dynamic>))
        .toList();

    return DailyHealthSummary(
      date: json['date'] ?? '',
      dailyCalorieGoal: (json['daily_calorie_goal'] as num?)?.toDouble(),
      nutrientsConsumed:
          DailyNutrients.fromJson(json['nutrients_consumed'] ?? {}),
      conditionStatuses: statuses,
    );
  }
}

class HistoryDaySummary {
  final String date;
  final String status;
  final double? dailyCalorieGoal;
  final double caloriesConsumed;
  final bool? calorieLimitExceeded;
  final List<String> conditionAlerts;

  HistoryDaySummary({
    required this.date,
    required this.status,
    this.dailyCalorieGoal,
    required this.caloriesConsumed,
    this.calorieLimitExceeded,
    required this.conditionAlerts,
  });

  factory HistoryDaySummary.fromJson(Map<String, dynamic> json) {
    return HistoryDaySummary(
      date: json['date'] ?? '',
      status: json['status'] ?? 'good',
      dailyCalorieGoal: (json['daily_calorie_goal'] as num?)?.toDouble(),
      caloriesConsumed: (json['calories_consumed'] as num?)?.toDouble() ?? 0.0,
      calorieLimitExceeded: json['calorie_limit_exceeded'],
      conditionAlerts: (json['condition_alerts'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class HealthHistory {
  final String fromDate;
  final String toDate;
  final List<HistoryDaySummary> days;

  HealthHistory({
    required this.fromDate,
    required this.toDate,
    required this.days,
  });

  factory HealthHistory.fromJson(Map<String, dynamic> json) {
    final dayItems = (json['days'] as List<dynamic>? ?? [])
        .map((e) => HistoryDaySummary.fromJson(e as Map<String, dynamic>))
        .toList();

    return HealthHistory(
      fromDate: json['from_date'] ?? '',
      toDate: json['to_date'] ?? '',
      days: dayItems,
    );
  }
}
