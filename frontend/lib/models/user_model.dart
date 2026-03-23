class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String languagePreference;
  final bool isActive;
  final String createdAt;
  // Extended profile fields
  final int? age;
  final String? gender;
  final double? height;
  final double? weight;
  final String? activityLevel;
  final double dailyCalorieGoal;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.languagePreference = 'English',
    required this.isActive,
    required this.createdAt,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.activityLevel,
    this.dailyCalorieGoal = 2000.0,
  });

  bool get isAdmin => role == 'admin';

  bool get hasCompletedProfile =>
      age != null && gender != null && height != null && weight != null;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'] ?? 'user',
      languagePreference: json['language_preference'] ?? 'English',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
      age: json['age'],
      gender: json['gender'],
      height: json['height'] != null ? (json['height'] as num).toDouble() : null,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      activityLevel: json['activity_level'],
      dailyCalorieGoal: (json['daily_calorie_goal'] as num?)?.toDouble() ?? 2000.0,
    );
  }
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final User user;
  final bool emailConfirmationRequired;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.emailConfirmationRequired = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      user: User.fromJson(json['user']),
      emailConfirmationRequired: json['email_confirmation_required'] ?? false,
    );
  }
}

class HealthCondition {
  final String id;
  final String conditionName;
  final String restrictedNutrient;
  final double thresholdAmount;
  final String thresholdUnit;

  HealthCondition({
    required this.id,
    required this.conditionName,
    required this.restrictedNutrient,
    required this.thresholdAmount,
    required this.thresholdUnit,
  });

  factory HealthCondition.fromJson(Map<String, dynamic> json) {
    return HealthCondition(
      id: json['id'],
      conditionName: json['condition_name'],
      restrictedNutrient: json['restricted_nutrient'],
      thresholdAmount: (json['threshold_amount'] as num).toDouble(),
      thresholdUnit: json['threshold_unit'],
    );
  }
}
