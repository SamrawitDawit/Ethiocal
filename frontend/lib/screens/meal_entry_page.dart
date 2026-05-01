import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/food_model.dart';
import '../services/api_service.dart';
import '../services/meal_service.dart';
import '../widgets/app_background.dart';

class MealEntryPage extends StatefulWidget {
  const MealEntryPage({super.key});

  @override
  State<MealEntryPage> createState() => _MealEntryPageState();
}

class _MealEntryPageState extends State<MealEntryPage> {
  // Step tracking: 1 = Food selection, 2 = Optional ingredients per food item
  int _currentStep = 1;

  String _selectedMealType = 'breakfast';
  List<FoodItem> _foodItems = [];
  List<Ingredient> _ingredients = [];
  List<SelectedFoodItem> _selectedFoods = [];
  bool _isLoading = false;
  bool _isFetchingData = true;
  String? _createdMealId;
  double _mealBaseCalories = 0.0; // Calories from step 1 (food items)
  Map<String, dynamic>? _mealTargetCheckResult;
  bool _isCheckingMealTargets = false;
  String? _mealTargetCheckError;
  int _mealTargetCheckVersion = 0;

  // Standard ingredients per food item (food_item_id -> list of standard ingredients)
  Map<String, List<FoodItemIngredient>> _standardIngredientsPerFood = {};

  // User's ingredient adjustments per food item (food_item_id -> ingredient_id -> selected ingredient)
  Map<String, Map<String, SelectedIngredientPerFood>> _userAdjustmentsPerFood = {};

  // Dropdown selections
  FoodItem? _selectedFoodDropdown;
  Ingredient? _selectedIngredientDropdown;

  // Currently editing food item in step 2
  String? _editingFoodItemId;

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final foods = await MealService.getFoodItems();
      final ingredients = await MealService.getIngredients();
      if (mounted) {
        setState(() {
          _foodItems = foods;
          _ingredients = ingredients;
          _isFetchingData = false;
        });
      }
      _scheduleMealTargetCheck();
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingData = false);
        _showError('Failed to load food data. Please try again.');
      }
    }
  }

  void _scheduleMealTargetCheck() {
    if (_selectedFoods.isEmpty) {
      if (mounted) {
        setState(() {
          _mealTargetCheckResult = null;
          _mealTargetCheckError = null;
        });
      }
      return;
    }

    final currentVersion = ++_mealTargetCheckVersion;
    setState(() {
      _isCheckingMealTargets = true;
      _mealTargetCheckError = null;
    });

    MealService.checkMealAgainstTargets(_mealNutrientsPayload).then((result) {
      if (!mounted || currentVersion != _mealTargetCheckVersion) {
        return;
      }
      setState(() {
        _mealTargetCheckResult = result;
        _isCheckingMealTargets = false;
      });
    }).catchError((error) {
      if (!mounted || currentVersion != _mealTargetCheckVersion) {
        return;
      }
      setState(() {
        _mealTargetCheckError = error.toString();
        _isCheckingMealTargets = false;
      });
    });
  }

  List<String> get _mealWarnings {
    final warnings = _mealTargetCheckResult?['warnings'];
    if (warnings is List) {
      return warnings.map((warning) => warning.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> get _mealProgress {
    final progress = _mealTargetCheckResult?['progress'];
    if (progress is Map<String, dynamic>) {
      return progress;
    }
    if (progress is Map) {
      return Map<String, dynamic>.from(progress);
    }
    return {};
  }

  String? get _mealDisclaimer {
    final disclaimer = _mealTargetCheckResult?['disclaimer'];
    return disclaimer?.toString();
  }

  Future<bool> _showMealWarningDialog() async {
    if (_mealWarnings.isEmpty) return true;

    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review meal guidance'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._mealWarnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $warning'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                ApiConstants.nutritionDisclaimer,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Edit portion'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen),
            child: const Text('Add anyway'),
          ),
        ],
      ),
    );

    return choice ?? false;
  }

  double get _totalFoodCalories {
    return _selectedFoods.fold(0.0, (sum, item) => sum + item.totalCalories);
  }

  /// Calculate total ingredient calories based on per-food-item adjustments
  double get _adjustedIngredientCalories {
    double total = 0.0;
    for (final foodEntry in _userAdjustmentsPerFood.entries) {
      for (final ingEntry in foodEntry.value.entries) {
        final selected = ingEntry.value;
        total += selected.adjustedCalories;
      }
    }
    return total;
  }

  double get _totalCalories {
    if (_currentStep == 1) {
      return _totalFoodCalories;
    }
    // In step 2, use the base meal calories plus adjusted ingredient calories
    return _mealBaseCalories + _adjustedIngredientCalories;
  }

  double get _totalProtein {
    return _selectedFoods.fold(0.0, (sum, item) => sum + item.totalProtein);
  }

  double get _totalCarbs {
    return _selectedFoods.fold(0.0, (sum, item) => sum + item.totalCarbs);
  }

  double get _totalFat {
    return _selectedFoods.fold(0.0, (sum, item) => sum + item.totalFat);
  }

  double get _totalSaturatedFatG {
    return _selectedFoods.fold(
            0.0, (sum, item) => sum + item.totalSaturatedFatG);
  }

  double get _totalFiber {
    return _selectedFoods.fold(0.0, (sum, item) => sum + item.totalFiber);
  }

  double get _totalSodiumMg {
    return _selectedFoods.fold(0.0, (sum, item) => sum + item.totalSodiumMg);
  }

  Map<String, dynamic> get _mealNutrientsPayload {
    return {
      'calories': _totalCalories,
      'carbs_g': _totalCarbs,
      'saturated_fat_g': _totalSaturatedFatG,
      'sodium_mg': _totalSodiumMg,
      'fiber_g': _totalFiber,
      'protein_g': _totalProtein,
    };
  }

  void _addFood(FoodItem item) {
    final existing = _selectedFoods.indexWhere((e) => e.foodItem.id == item.id);
    setState(() {
      if (existing >= 0) {
        _selectedFoods[existing].quantity += 1;
      } else {
        _selectedFoods.add(SelectedFoodItem(foodItem: item));
      }
      _selectedFoodDropdown = null;
    });
    _scheduleMealTargetCheck();
  }

  void _removeFood(int index) {
    final foodId = _selectedFoods[index].foodItem.id;
    setState(() {
      if (_selectedFoods[index].quantity > 1) {
        _selectedFoods[index].quantity -= 1;
      } else {
        _selectedFoods.removeAt(index);
        // Clean up any ingredient adjustments for this food item
        _userAdjustmentsPerFood.remove(foodId);
        _standardIngredientsPerFood.remove(foodId);
      }
    });
    _scheduleMealTargetCheck();
  }

  void _addIngredient(Ingredient item) {
    // When editing a specific food item
    if (_editingFoodItemId != null) {
      final foodAdjustments = _userAdjustmentsPerFood[_editingFoodItemId!] ?? {};
      final existingKey = foodAdjustments.keys.firstWhere(
        (key) => key == item.id,
        orElse: () => '',
      );

      if (existingKey.isNotEmpty) {
        foodAdjustments[existingKey]!.quantity += 1;
      } else {
        // Get standard quantity for this ingredient in this food
        final stdIngredients = _standardIngredientsPerFood[_editingFoodItemId!] ?? [];
        final stdIng = stdIngredients.firstWhere(
          (si) => si.ingredientId == item.id,
          orElse: () => FoodItemIngredient(
            id: '',
            foodItemId: '',
            ingredientId: item.id,
            standardQuantity: 0,
            createdAt: '',
          ),
        );
        foodAdjustments[item.id] = SelectedIngredientPerFood(
          ingredient: item,
          quantity: 1.0,
          standardQuantity: stdIng.standardQuantity,
        );
      }
      _userAdjustmentsPerFood[_editingFoodItemId!] = foodAdjustments;
    }
    setState(() {});
    _scheduleMealTargetCheck();
  }

  void _removeIngredient(String foodItemId, String ingredientId) {
    final foodAdjustments = _userAdjustmentsPerFood[foodItemId];
    if (foodAdjustments != null && foodAdjustments.containsKey(ingredientId)) {
      if (foodAdjustments[ingredientId]!.quantity > 1) {
        foodAdjustments[ingredientId]!.quantity -= 1;
      } else {
        foodAdjustments.remove(ingredientId);
      }
      setState(() {});
      _scheduleMealTargetCheck();
    }
  }

  Future<void> _createMeal() async {
    if (_selectedFoods.isEmpty) {
      _showError('Please select at least one food item');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await MealService.createMeal(
        mealType: _selectedMealType,
        foodItems: _selectedFoods,
      );

      _createdMealId = response.id;
      _mealBaseCalories = response.totalCalories;

      // Store the meal_food_item_id for each selected food
      for (var i = 0; i < response.foodItems.length; i++) {
        final mealFoodItem = response.foodItems[i];
        _selectedFoods[i].mealFoodItemId = mealFoodItem.id;
      }

      // Fetch standard ingredients for all selected food items
      await _fetchStandardIngredientsPerFood();

      // Initialize user adjustments with standard quantities
      _initializeUserAdjustments();

      // Move to step 2 (optional ingredients per food item)
      setState(() {
        _currentStep = 2;
        _isLoading = false;
        if (_selectedFoods.isNotEmpty) {
          _editingFoodItemId = _selectedFoods.first.foodItem.id;
        }
      });

      _showSuccess(
          'Food logged! ${response.totalCalories.toStringAsFixed(0)} calories. Adjust ingredients per dish?');
    } on ApiException catch (e) {
      _showError(e.message);
      setState(() => _isLoading = false);
    } catch (_) {
      _showError('Failed to log meal. Please try again.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateMealPressed() async {
    if (_mealWarnings.isNotEmpty) {
      final proceed = await _showMealWarningDialog();
      if (!proceed) {
        return;
      }
    }
    await _createMeal();
  }

  Future<void> _fetchStandardIngredientsPerFood() async {
    _standardIngredientsPerFood = {};

    for (final selectedFood in _selectedFoods) {
      try {
        final stdIngredients = await MealService.getFoodItemStandardIngredients(
            selectedFood.foodItem.id);

        // Scale standard quantities by the number of servings selected
        final scaledIngredients = stdIngredients.map((ing) {
          return FoodItemIngredient(
            id: ing.id,
            foodItemId: ing.foodItemId,
            ingredientId: ing.ingredientId,
            standardQuantity: ing.standardQuantity * selectedFood.quantity,
            ingredient: ing.ingredient,
            createdAt: ing.createdAt,
          );
        }).toList();

        _standardIngredientsPerFood[selectedFood.foodItem.id] = scaledIngredients;
      } catch (_) {
        // Silently ignore errors fetching standard ingredients
        _standardIngredientsPerFood[selectedFood.foodItem.id] = [];
      }
    }
  }

  void _initializeUserAdjustments() {
    _userAdjustmentsPerFood = {};

    for (final selectedFood in _selectedFoods) {
      final foodId = selectedFood.foodItem.id;
      final stdIngredients = _standardIngredientsPerFood[foodId] ?? [];

      final adjustments = <String, SelectedIngredientPerFood>{};
      for (final stdIng in stdIngredients) {
        if (stdIng.ingredient != null) {
          adjustments[stdIng.ingredientId] = SelectedIngredientPerFood(
            ingredient: stdIng.ingredient!,
            quantity: stdIng.standardQuantity, // Start with standard quantity
            standardQuantity: stdIng.standardQuantity,
          );
        }
      }
      _userAdjustmentsPerFood[foodId] = adjustments;
    }
  }

  Future<void> _addIngredientsToMeal() async {
    if (_createdMealId == null) return;

    setState(() => _isLoading = true);

    try {
      // Build the request payload with per-food-item ingredients
      final foodItemIngredients = <Map<String, dynamic>>[];

      for (final selectedFood in _selectedFoods) {
        if (selectedFood.mealFoodItemId == null) continue;

        final foodAdjustments = _userAdjustmentsPerFood[selectedFood.foodItem.id];
        if (foodAdjustments != null) {
          for (final ing in foodAdjustments.values) {
            foodItemIngredients.add({
              'meal_food_item_id': selectedFood.mealFoodItemId,
              'ingredient_id': ing.ingredient.id,
              'quantity': ing.quantity,
            });
          }
        }
      }

      final response = await MealService.addFoodItemIngredientsToMeal(
        mealId: _createdMealId!,
        foodItemIngredients: foodItemIngredients,
      );

      _showSuccess(
          'Ingredients saved! Total: ${(response['new_total_calories'] as num).toStringAsFixed(0)} calories');
      _finishMealEntry();
    } on ApiException catch (e) {
      _showError(e.message);
      setState(() => _isLoading = false);
    } catch (_) {
      _showError('Failed to save ingredients. Please try again.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAddIngredientsPressed() async {
    await _addIngredientsToMeal();
  }

  void _finishMealEntry() {
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (_currentStep == 1) ...[
                        _buildMealTypeSelector(),
                        const SizedBox(height: 20),
                        _buildFoodSelection(),
                      ] else ...[
                        _buildIngredientSelectionPerFood(),
                      ],
                      const SizedBox(height: 20),
                      if (_selectedFoods.isNotEmpty)
                        _buildNutritionSummary(),
                      const SizedBox(height: 16),
                      _buildMealGuidanceCard(),
                      const SizedBox(height: 20),
                      _buildActionButtons(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.textPrimary, size: 20),
            onPressed: () {
              if (_currentStep == 2) {
                // Go back to step 1
                setState(() => _currentStep = 1);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          Expanded(
            child: Center(
              child: Text(
                'Log Meal',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildStepCircle(1, 'Food'),
          Expanded(
            child: Container(
              height: 2,
              color: _currentStep >= 2
                  ? AppColors.primaryGreen
                  : AppColors.inputBorder,
            ),
          ),
          _buildStepCircle(2, 'Ingredients'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primaryGreen : AppColors.inputFill,
            border: Border.all(
              color: isActive ? AppColors.primaryGreen : AppColors.inputBorder,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$step',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isActive ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMealTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meal Type',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _mealTypes.map((type) {
            final isSelected = _selectedMealType == type;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedMealType = type),
                child: Container(
                  margin:
                      EdgeInsets.only(right: type != _mealTypes.last ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.inputFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreen
                          : AppColors.inputBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      type[0].toUpperCase() + type.substring(1),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFoodSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Food',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (_isFetchingData)
          const Center(child: CircularProgressIndicator())
        else
          _buildFoodDropdown(),
        const SizedBox(height: 16),
        if (_selectedFoods.isNotEmpty) ...[
          Text(
            'Selected Foods',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ..._selectedFoods.asMap().entries.map((entry) {
            return _buildSelectedFoodCard(entry.key, entry.value);
          }),
        ],
      ],
    );
  }

  Widget _buildFoodDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FoodItem>(
          isExpanded: true,
          hint: Text(
            'Choose a food item...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          value: _selectedFoodDropdown,
          items: _foodItems.map((food) {
            return DropdownMenuItem<FoodItem>(
              value: food,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          food.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (food.nameAmharic != null)
                          Text(
                            food.nameAmharic!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${food.caloriesPerServing.toStringAsFixed(0)} cal',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (food) {
            if (food != null) {
              _addFood(food);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSelectedFoodCard(int index, SelectedFoodItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.foodItem.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.foodItem.nameAmharic != null)
                  Text(
                    item.foodItem.nameAmharic!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  '${item.totalCalories.toStringAsFixed(0)} cal',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          _buildQuantityControl(
            quantity: item.quantity,
            onDecrease: () => _removeFood(index),
            onIncrease: () => _addFood(item.foodItem),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientSelectionPerFood() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.blobYellow.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.darkGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Adjust cooking ingredients per dish. Standard amounts are included in each dish\'s calories.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Select a dish to adjust its ingredients',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // Food item selector tabs
        _buildFoodItemSelector(),
        const SizedBox(height: 16),
        // Show ingredients for selected food item
        if (_editingFoodItemId != null) ...[
          _buildIngredientSectionForFood(),
        ],
      ],
    );
  }

  Widget _buildFoodItemSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _selectedFoods.map((food) {
          final isSelected = _editingFoodItemId == food.foodItem.id;
          return GestureDetector(
            onTap: () {
              setState(() {
                _editingFoodItemId = food.foodItem.id;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryGreen
                    : AppColors.inputFill,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.inputBorder,
                ),
              ),
              child: Text(
                food.foodItem.name,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIngredientSectionForFood() {
    final foodAdjustments = _userAdjustmentsPerFood[_editingFoodItemId] ?? {};
    final selectedFood = _selectedFoods.firstWhere(
      (f) => f.foodItem.id == _editingFoodItemId,
      orElse: () => SelectedFoodItem(foodItem: FoodItem(
        id: '',
        name: '',
        standardServingSize: 100,
        caloriesPerServing: 0,
        carbohydrates: 0,
        protein: 0,
        fat: 0,
        fiber: 0,
        createdAt: '',
      )),
    );

    // Calculate total adjusted calories for this food
    double foodIngredientCalories = 0.0;
    for (final adj in foodAdjustments.values) {
      foodIngredientCalories += adj.adjustedCalories;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ingredients for ${selectedFood.foodItem.name}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: foodIngredientCalories >= 0
                    ? AppColors.primaryGreen.withOpacity(0.2)
                    : AppColors.error.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${foodIngredientCalories >= 0 ? '+' : ''}${foodIngredientCalories.toStringAsFixed(0)} cal',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foodIngredientCalories >= 0
                      ? AppColors.darkGreen
                      : AppColors.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (foodAdjustments.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.textSecondary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No standard ingredients for this dish. Add extras?',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...foodAdjustments.entries.map((entry) {
            return _buildIngredientAdjustmentCard(
              _editingFoodItemId!,
              entry.value,
            );
          }),
        const SizedBox(height: 12),
        // Add extra ingredient dropdown
        _buildIngredientDropdown(),
      ],
    );
  }

  Widget _buildIngredientAdjustmentCard(
    String foodItemId,
    SelectedIngredientPerFood adjustment,
  ) {
    final diff = adjustment.quantity - adjustment.standardQuantity;
    final adjustedCalories = adjustment.adjustedCalories;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blobYellow.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blobYellow),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adjustment.ingredient.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (adjustment.ingredient.nameAmharic != null)
                  Text(
                    adjustment.ingredient.nameAmharic!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Standard: ${adjustment.standardQuantity.toStringAsFixed(1)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (diff != 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: diff > 0
                              ? AppColors.error.withOpacity(0.2)
                              : AppColors.primaryGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: diff > 0
                                ? AppColors.error
                                : AppColors.darkGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${adjustedCalories >= 0 ? '+' : ''}${adjustedCalories.toStringAsFixed(0)} cal',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: adjustedCalories >= 0
                        ? AppColors.darkGreen
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          _buildQuantityControl(
            quantity: adjustment.quantity,
            onDecrease: () => _removeIngredient(foodItemId, adjustment.ingredient.id),
            onIncrease: () {
              setState(() {
                adjustment.quantity += 1;
              });
              _scheduleMealTargetCheck();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Ingredient>(
          isExpanded: true,
          hint: Text(
            'Add extra ingredient...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          value: _selectedIngredientDropdown,
          items: _ingredients.map((ing) {
            // Filter out ingredients already in adjustments
            final existing = _userAdjustmentsPerFood[_editingFoodItemId] ?? {};
            if (existing.containsKey(ing.id)) {
              return null;
            }
            return DropdownMenuItem<Ingredient>(
              value: ing,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ing.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (ing.nameAmharic != null)
                          Text(
                            ing.nameAmharic!,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${ing.caloriesPerServing.toStringAsFixed(0)} cal',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            );
          }).whereType<DropdownMenuItem<Ingredient>>().toList(),
          onChanged: (ing) {
            if (ing != null) {
              _addIngredient(ing);
              setState(() {
                _selectedIngredientDropdown = null;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildQuantityControl({
    required double quantity,
    required VoidCallback onDecrease,
    required VoidCallback onIncrease,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: onDecrease,
            color: AppColors.primaryGreen,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Text(
            quantity.toStringAsFixed(quantity == quantity.toInt() ? 0 : 1),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: onIncrease,
            color: AppColors.primaryGreen,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Summary',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutritionItem(
                  'Calories', '${_totalCalories.toStringAsFixed(0)}', 'kcal'),
              _buildNutritionItem(
                  'Protein', '${_totalProtein.toStringAsFixed(1)}', 'g'),
              _buildNutritionItem(
                  'Carbs', '${_totalCarbs.toStringAsFixed(1)}', 'g'),
              _buildNutritionItem(
                  'Fat', '${_totalFat.toStringAsFixed(1)}', 'g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryGreen,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_currentStep == 1) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isLoading || _selectedFoods.isEmpty
              ? null
              : _handleCreateMealPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Next: Adjust Ingredients',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleAddIngredientsPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save & Finish',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Standard ingredient quantities will be used for any dishes not adjusted.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMealGuidanceCard() {
    if (_mealTargetCheckResult == null && _selectedFoods.isEmpty) {
      return const SizedBox.shrink();
    }

    final progress = _mealProgress;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Meal guidance',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (_isCheckingMealTargets) ...[
                const SizedBox(width: 8),
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          if (_mealWarnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._mealWarnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $warning',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.error)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildTargetProgressBar('Sodium', progress['sodium_percent']),
          _buildTargetProgressBar(
              'Saturated fat', progress['saturated_fat_percent']),
          _buildTargetProgressBar('Fiber', progress['fiber_percent']),
          _buildTargetProgressBar('Carbs', progress['carbs_percent']),
          const SizedBox(height: 12),
          Text(
            'Today\'s sodium: ${(progress['sodium_percent'] as num?)?.toStringAsFixed(0) ?? '0'}% used',
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            ApiConstants.nutritionDisclaimer,
            style: GoogleFonts.poppins(
                fontSize: 11, color: AppColors.textSecondary, height: 1.4),
          ),
          if (_mealTargetCheckError != null) ...[
            const SizedBox(height: 8),
            Text(_mealTargetCheckError!,
                style:
                    GoogleFonts.poppins(fontSize: 11, color: AppColors.error)),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetProgressBar(String label, dynamic value) {
    final percent =
        value is num ? (value.toDouble() / 100.0).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              Text(
                  '${(value is num ? value.toDouble() : 0.0).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: AppColors.inputBorder,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }
}
