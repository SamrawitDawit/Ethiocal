class Profile {
  final int age;
  final String gender;
  final double height;
  final String heightUnit;
  final double weight;
  final String weightUnit;
  final String activityLevel;
  final int dailyCalorieGoal;
  final List<String> healthConditionIds;

  Profile({
    required this.age,
    required this.gender,
    required this.height,
    required this.heightUnit,
    required this.weight,
    required this.weightUnit,
    required this.activityLevel,
    required this.dailyCalorieGoal,
    required this.healthConditionIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'gender': gender,
      'height': height,
      'height_unit': heightUnit,
      'weight': weight,
      'weight_unit': weightUnit,
      'activity_level': activityLevel,
      'daily_calorie_goal': dailyCalorieGoal,
      'health_condition_ids': healthConditionIds,
    };
  }

  Profile copyWith({
    int? age,
    String? gender,
    double? height,
    String? heightUnit,
    double? weight,
    String? weightUnit,
    String? activityLevel,
    int? dailyCalorieGoal,
    List<String>? healthConditionIds,
  }) {
    return Profile(
      age: age ?? this.age,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      activityLevel: activityLevel ?? this.activityLevel,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      healthConditionIds: healthConditionIds ?? this.healthConditionIds,
    );
  }
}
