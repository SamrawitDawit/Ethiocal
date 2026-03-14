class User {
  final String id;
  final String email;
  final String fullName;
  final bool hasDiabetes;
  final bool hasHypertension;
  final bool hasHeartDisease;
  final double dailyCalorieGoal;
  final bool isActive;
  final String createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.hasDiabetes,
    required this.hasHypertension,
    required this.hasHeartDisease,
    required this.dailyCalorieGoal,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      hasDiabetes: json['has_diabetes'] ?? false,
      hasHypertension: json['has_hypertension'] ?? false,
      hasHeartDisease: json['has_heart_disease'] ?? false,
      dailyCalorieGoal: (json['daily_calorie_goal'] as num).toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      user: User.fromJson(json['user']),
    );
  }
}
