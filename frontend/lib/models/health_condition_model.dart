class HealthCondition {
  final String id;
  final String conditionName;
  final String restrictedNutrient;
  final double thresholdAmount;
  final String thresholdUnit;
  bool isSelected;

  HealthCondition({
    required this.id,
    required this.conditionName,
    required this.restrictedNutrient,
    required this.thresholdAmount,
    required this.thresholdUnit,
    this.isSelected = false,
  });

  factory HealthCondition.fromJson(Map<String, dynamic> json) {
    return HealthCondition(
      id: json['id'],
      conditionName: json['condition_name'],
      restrictedNutrient:
          (json['restricted_nutrient'] ?? json['restricted_nutrients'] ?? '')
              .toString(),
      thresholdAmount: (json['threshold_amount'] as num?)?.toDouble() ?? 0.0,
      thresholdUnit: json['threshold_unit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condition_name': conditionName,
      'restricted_nutrient': restrictedNutrient,
      'threshold_amount': thresholdAmount,
      'threshold_unit': thresholdUnit,
    };
  }

  HealthCondition copyWith({
    String? id,
    String? conditionName,
    String? restrictedNutrient,
    double? thresholdAmount,
    String? thresholdUnit,
    bool? isSelected,
  }) {
    return HealthCondition(
      id: id ?? this.id,
      conditionName: conditionName ?? this.conditionName,
      restrictedNutrient: restrictedNutrient ?? this.restrictedNutrient,
      thresholdAmount: thresholdAmount ?? this.thresholdAmount,
      thresholdUnit: thresholdUnit ?? this.thresholdUnit,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
