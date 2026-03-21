import 'package:flutter/foundation.dart';
import '../models/health_condition_model.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

class ProfileSetupProvider extends ChangeNotifier {
  // Step 1: Basic Info
  int _age = 25;
  String _gender = 'Male';
  String _activityLevel = 'Sedentary';
  int _dailyCalorieGoal = 2000;

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
  int get age => _age;
  String get gender => _gender;
  String get activityLevel => _activityLevel;
  int get dailyCalorieGoal => _dailyCalorieGoal;
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
  void setAge(int age) {
    _age = age;
    notifyListeners();
  }

  void setGender(String gender) {
    _gender = gender;
    notifyListeners();
  }

  void setActivityLevel(String activityLevel) {
    _activityLevel = activityLevel;
    notifyListeners();
  }

  void setDailyCalorieGoal(int goal) {
    _dailyCalorieGoal = goal;
    notifyListeners();
  }

  // Setters for Step 2
  void setHeight(double height) {
    _height = height;
    notifyListeners();
  }

  void setHeightUnit(String unit) {
    _heightUnit = unit;
    notifyListeners();
  }

  void setWeight(double weight) {
    _weight = weight;
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
      age: _age,
      gender: _gender,
      height: _height,
      heightUnit: _heightUnit,
      weight: _weight,
      weightUnit: _weightUnit,
      activityLevel: _activityLevel,
      dailyCalorieGoal: _dailyCalorieGoal,
      healthConditionIds: selectedHealthConditionIds,
    );
  }

  // Submit profile
  Future<void> submitProfile() async {
    _isSubmitting = true;
    _submitError = '';
    notifyListeners();

    try {
      final profile = getProfile();
      await ProfileService.createProfile(profile: profile);
    } catch (e) {
      _submitError = e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // Validation
  bool isStep1Valid() {
    return _age > 0 && _dailyCalorieGoal > 0;
  }

  bool isStep2Valid() {
    return _height > 0 && _weight > 0;
  }

  bool isStep3Valid() {
    return true; // Health conditions are optional
  }
}
