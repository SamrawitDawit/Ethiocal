import 'package:flutter/foundation.dart';
import '../models/health_condition_model.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

class ProfileSetupProvider extends ChangeNotifier {
  // Step 1: Basic Info
  String _birthDate = '2000-01-01';
  String _gender = 'Male';
  String _activityLevel = 'Sedentary';
  int _dailyCalorieGoal = 2000;
  String _goal = 'maintain'; // 'lose_weight', 'maintain', 'gain_weight'
  bool _hasDiabetes = false;
  bool _hasHypertension = false;
  bool _hasHighCholesterol = false;
  String? _diabetesType;
  double? _latestHbA1c;

  // Step 2: Body Measurements
  double _height = 170;
  String _heightUnit = 'cm';
  double _weight = 65;
  String _weightUnit = 'kg';

  // Step 3: Health Conditions
  List<HealthCondition> _healthConditions = [];
  bool _isLoadingHealthConditions = false;
  String _healthConditionsError = '';

  // Navigation
  int _currentStep = 1;
  bool _isSubmitting = false;
  String _submitError = '';

  // Getters
  String get birthDate => _birthDate;
  String get gender => _gender;
  String get activityLevel => _activityLevel;
  int get dailyCalorieGoal => _dailyCalorieGoal;
  String get goal => _goal;
  bool get hasDiabetes => _hasDiabetes;
  bool get hasHypertension => _hasHypertension;
  bool get hasHighCholesterol => _hasHighCholesterol;
  String? get diabetesType => _diabetesType;
  double? get latestHbA1c => _latestHbA1c;
  double get height => _height;
  String get heightUnit => _heightUnit;
  double get weight => _weight;
  String get weightUnit => _weightUnit;
  List<HealthCondition> get healthConditions => _healthConditions;
  bool get isLoadingHealthConditions => _isLoadingHealthConditions;
  String get healthConditionsError => _healthConditionsError;
  int get currentStep => _currentStep;
  bool get isSubmitting => _isSubmitting;
  String get submitError => _submitError;

  // Setters for Step 1
  void setBirthDate(String birthDate) {
    _birthDate = birthDate;
    _calculateAndUpdateDailyCalorieGoal();
    notifyListeners();
  }

  void setGender(String gender) {
    _gender = gender;
    _calculateAndUpdateDailyCalorieGoal();
    notifyListeners();
  }

  void setActivityLevel(String activityLevel) {
    _activityLevel = activityLevel;
    _calculateAndUpdateDailyCalorieGoal();
    notifyListeners();
  }

  void setDailyCalorieGoal(int goal) {
    _dailyCalorieGoal = goal;
    notifyListeners();
  }

  void setGoal(String goal) {
    _goal = goal;
    // Automatically calculate daily calorie goal when goal changes
    _calculateAndUpdateDailyCalorieGoal();
    notifyListeners();
  }

  void setHasDiabetes(bool value) {
    _hasDiabetes = value;
    _setConditionSelectionByName('diabetes', value);
    if (!value) {
      _diabetesType = null;
      _latestHbA1c = null;
    }
    notifyListeners();
  }

  void setHasHypertension(bool value) {
    _hasHypertension = value;
    _setConditionSelectionByName('hypertension', value);
    notifyListeners();
  }

  void setHasHighCholesterol(bool value) {
    _hasHighCholesterol = value;
    _setConditionSelectionByName('cholesterol', value);
    notifyListeners();
  }

  void _setConditionSelectionByName(String term, bool isSelected) {
    if (_healthConditions.isEmpty) return;

    final lowerTerm = term.toLowerCase();
    _healthConditions = _healthConditions.map((condition) {
      final name = condition.conditionName.toLowerCase();
      final matches = name.contains(lowerTerm) ||
          (lowerTerm == 'cholesterol' &&
              (name.contains('cholestrol') || name.contains('heart disease')));
      if (!matches) return condition;
      return condition.copyWith(isSelected: isSelected);
    }).toList();
  }

  void setDiabetesType(String? value) {
    _diabetesType = value;
    notifyListeners();
  }

  void setLatestHbA1c(double? value) {
    _latestHbA1c = value;
    notifyListeners();
  }

  // Calculate and update daily calorie goal based on current profile data
  void _calculateAndUpdateDailyCalorieGoal() {
    // Only calculate if we have valid height and weight
    if (_height > 0 && _weight > 0) {
      final profile = _createTemporaryProfile();
      _dailyCalorieGoal = profile.calculateDailyCalorieGoal();
    }
  }

  // Create a temporary profile for calculation purposes
  Profile _createTemporaryProfile() {
    return Profile(
      birthDate: _birthDate,
      gender: _gender,
      height: _height,
      heightUnit: _heightUnit,
      weight: _weight,
      weightUnit: _weightUnit,
      activityLevel: _activityLevel,
      dailyCalorieGoal: _dailyCalorieGoal,
      hasDiabetes: _hasDiabetes,
      hasHypertension: _hasHypertension,
      hasHighCholesterol: _hasHighCholesterol,
      diabetesType: _diabetesType,
      latestHbA1c: _latestHbA1c,
      healthConditionIds: selectedHealthConditionIds,
      goal: _goal,
    );
  }

  // Setters for Step 2
  void setHeight(double height) {
    _height = height;
    _calculateAndUpdateDailyCalorieGoal();
    notifyListeners();
  }

  void setHeightUnit(String unit) {
    _heightUnit = unit;
    notifyListeners();
  }

  void setWeight(double weight) {
    _weight = weight;
    _calculateAndUpdateDailyCalorieGoal();
    notifyListeners();
  }

  void setWeightUnit(String unit) {
    _weightUnit = unit;
    notifyListeners();
  }

  // Health conditions management
  Future<void> loadHealthConditions() async {
    _isLoadingHealthConditions = true;
    _healthConditionsError = '';
    notifyListeners();

    try {
      final conditions = await ProfileService.getHealthConditions();
      _healthConditions = conditions;
      _setConditionSelectionByName('diabetes', _hasDiabetes);
      _setConditionSelectionByName('hypertension', _hasHypertension);
      _setConditionSelectionByName('cholesterol', _hasHighCholesterol);
    } catch (e) {
      _healthConditionsError = e.toString();
    } finally {
      _isLoadingHealthConditions = false;
      notifyListeners();
    }
  }

  void toggleHealthCondition(String conditionId) {
    final index = _healthConditions.indexWhere((c) => c.id == conditionId);
    if (index != -1) {
      _healthConditions[index] = _healthConditions[index].copyWith(
        isSelected: !_healthConditions[index].isSelected,
      );
      notifyListeners();
    }
  }

  // Navigation
  void goToStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  void nextStep() {
    if (_currentStep < 3) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 1) {
      _currentStep--;
      notifyListeners();
    }
  }

  // Get selected health condition IDs
  List<String> get selectedHealthConditionIds {
    return _healthConditions
        .where((condition) => condition.isSelected)
        .map((condition) => condition.id)
        .toList();
  }

  // Create profile object
  Profile getProfile() {
    return Profile(
      birthDate: _birthDate,
      gender: _gender,
      height: _height,
      heightUnit: _heightUnit,
      weight: _weight,
      weightUnit: _weightUnit,
      activityLevel: _activityLevel,
      dailyCalorieGoal: _dailyCalorieGoal,
      hasDiabetes: _hasDiabetes,
      hasHypertension: _hasHypertension,
      hasHighCholesterol: _hasHighCholesterol,
      diabetesType: _diabetesType,
      latestHbA1c: _latestHbA1c,
      healthConditionIds: selectedHealthConditionIds,
      goal: _goal,
    );
  }

  // Submit profile
  Future<bool> submitProfile() async {
    _isSubmitting = true;
    _submitError = '';
    notifyListeners();

    try {
      final profile = getProfile();
      await ProfileService.createProfile(profile: profile);
      return true; // Success
    } catch (e) {
      _submitError = e.toString();
      return false; // Failure
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // Validation
  bool isStep1Valid() {
    return _birthDate.isNotEmpty && _goal.isNotEmpty;
  }

  bool isStep2Valid() {
    return _height > 0 && _weight > 0;
  }

  bool isStep3Valid() {
    return true; // Health conditions are optional
  }
}
