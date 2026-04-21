class Profile {
  final String birthDate;
  final String gender;
  final double height;
  final String heightUnit;
  final double weight;
  final String weightUnit;
  final String activityLevel;
  final int dailyCalorieGoal;
  final bool hasDiabetes;
  final bool hasHypertension;
  final bool hasHighCholesterol;
  final String? diabetesType;
  final double? latestHbA1c;
  final List<String> healthConditionIds;
  final String goal;

  Profile({
    required this.birthDate,
    required this.gender,
    required this.height,
    required this.heightUnit,
    required this.weight,
    required this.weightUnit,
    required this.activityLevel,
    required this.dailyCalorieGoal,
    this.hasDiabetes = false,
    this.hasHypertension = false,
    this.hasHighCholesterol = false,
    this.diabetesType,
    this.latestHbA1c,
    required this.healthConditionIds,
    required this.goal,
  });

  Map<String, dynamic> toJson() {
    return {
      'birthdate': birthDate,
      'gender': gender,
      'height': height,
      'height_unit': heightUnit,
      'weight': weight,
      'weight_unit': weightUnit,
      'activity_level': activityLevel,
      'daily_calorie_goal': dailyCalorieGoal,
      'has_diabetes': hasDiabetes,
      'has_hypertension': hasHypertension,
      'has_high_cholesterol': hasHighCholesterol,
      'diabetes_type': diabetesType,
      'latest_hba1c': latestHbA1c,
      'health_condition_ids': healthConditionIds,
      'goal': goal,
    };
  }

  Profile copyWith({
    String? birthDate,
    String? gender,
    double? height,
    String? heightUnit,
    double? weight,
    String? weightUnit,
    String? activityLevel,
    int? dailyCalorieGoal,
    bool? hasDiabetes,
    bool? hasHypertension,
    bool? hasHighCholesterol,
    String? diabetesType,
    double? latestHbA1c,
    List<String>? healthConditionIds,
    String? goal,
  }) {
    return Profile(
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      heightUnit: heightUnit ?? this.heightUnit,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      activityLevel: activityLevel ?? this.activityLevel,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      hasDiabetes: hasDiabetes ?? this.hasDiabetes,
      hasHypertension: hasHypertension ?? this.hasHypertension,
      hasHighCholesterol: hasHighCholesterol ?? this.hasHighCholesterol,
      diabetesType: diabetesType ?? this.diabetesType,
      latestHbA1c: latestHbA1c ?? this.latestHbA1c,
      healthConditionIds: healthConditionIds ?? this.healthConditionIds,
      goal: goal ?? this.goal,
    );
  }

  // Calculate daily calorie goal based on profile data
  int calculateDailyCalorieGoal() {
    // Convert height to cm and weight to kg if needed
    final heightInCm =
        heightUnit.toLowerCase() == 'in' ? height * 2.54 : height;
    final weightInKg =
        weightUnit.toLowerCase() == 'lbs' ? weight * 0.453592 : weight;

    // Calculate age from birth date
    final birthDateParts = birthDate.split('-');
    final birthYear = int.tryParse(birthDateParts[0]) ?? 2000;
    final birthMonth = int.tryParse(birthDateParts[1]) ?? 1;
    final birthDay = int.tryParse(birthDateParts[2]) ?? 1;

    final now = DateTime.now();
    var age = now.year - birthYear;

    // Check if birthday has occurred this year
    if (now.month < birthMonth ||
        (now.month == birthMonth && now.day < birthDay)) {
      age--;
    }

    // Calculate BMR using Mifflin-St Jeor equation
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = 10 * weightInKg + 6.25 * heightInCm - 5 * age + 5;
    } else {
      bmr = 10 * weightInKg + 6.25 * heightInCm - 5 * age - 161;
    }

    // Apply activity level multiplier
    double activityMultiplier;
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'lightly active':
        activityMultiplier = 1.375;
        break;
      case 'moderately active':
        activityMultiplier = 1.55;
        break;
      case 'very active':
        activityMultiplier = 1.725;
        break;
      case 'extra active':
        activityMultiplier = 1.9;
        break;
      default:
        activityMultiplier = 1.2;
    }

    double tdee = bmr * activityMultiplier;

    // Adjust based on goal using percentage-based approach
    switch (goal.toLowerCase()) {
      case 'lose_weight':
        tdee *= 0.8; // 20% deficit (more personalized)
        break;
      case 'gain_weight':
        tdee *= 1.15; // 15% surplus for muscle gain
        break;
      case 'maintain':
      default:
        // No adjustment needed
        break;
    }

    // Ensure minimum daily calories (1200 for women, 1500 for men)
    final minCalories = gender.toLowerCase() == 'male' ? 1500 : 1200;

    return tdee.round().clamp(minCalories, 5000);
  }
}
