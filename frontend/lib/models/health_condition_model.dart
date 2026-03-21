class HealthCondition {
  final String id;
  final String conditionName;
  final String restrictedNutrients;
  final int thresholdAmount;
  final String thresholdUnit;
  bool isSelected;

  HealthCondition({
    required this.id,
    required this.conditionName,
    required this.restrictedNutrients,
    required this.thresholdAmount,
    required this.thresholdUnit,
    this.isSelected = false,
  });

  factory HealthCondition.fromJson(Map<String, dynamic> json) {
    return HealthCondition(
      id: json['id'],
      conditionName: json['condition_name'],
      restrictedNutrients: json['restricted_nutrients'],
      thresholdAmount: json['threshold_amount'],
      thresholdUnit: json['threshold_unit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'condition_name': conditionName,
      'restricted_nutrients': restrictedNutrients,
      'threshold_amount': thresholdAmount,
      'threshold_unit': thresholdUnit,
    };
  }

  HealthCondition copyWith({
    String? id,
    String? conditionName,
    String? restrictedNutrients,
    int? thresholdAmount,
    String? thresholdUnit,
    bool? isSelected,
  }) {
    return HealthCondition(
      id: id ?? this.id,
      conditionName: conditionName ?? this.conditionName,
      restrictedNutrients: restrictedNutrients ?? this.restrictedNutrients,
      thresholdAmount: thresholdAmount ?? this.thresholdAmount,
      thresholdUnit: thresholdUnit ?? this.thresholdUnit,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
