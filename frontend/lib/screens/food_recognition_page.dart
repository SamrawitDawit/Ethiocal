import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../constants/app_constants.dart';
import '../providers/language_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/food_detection_overlay.dart';
import '../models/food_recognition_model.dart';
import '../models/food_model.dart';
import '../services/food_recognition_service.dart';
import '../services/meal_service.dart';

class CornerBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerSize;

  CornerBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final margin = strokeWidth / 2;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(margin, cornerSize + margin)
        ..lineTo(margin, margin)
        ..lineTo(cornerSize + margin, margin),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize - margin, margin)
        ..lineTo(size.width - margin, margin)
        ..lineTo(size.width - margin, cornerSize + margin),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(margin, size.height - cornerSize - margin)
        ..lineTo(margin, size.height - margin)
        ..lineTo(cornerSize + margin, size.height - margin),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize - margin, size.height - margin)
        ..lineTo(size.width - margin, size.height - margin)
        ..lineTo(size.width - margin, size.height - cornerSize - margin),
      paint,
    );
  }

  @override
  bool shouldRepaint(CornerBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerSize != cornerSize;
  }
}

class FoodRecognitionPage extends StatefulWidget {
  const FoodRecognitionPage({super.key});

  @override
  State<FoodRecognitionPage> createState() => _FoodRecognitionPageState();
}

class _FoodRecognitionPageState extends State<FoodRecognitionPage> {
  File? _selectedImage;
  Uint8List? _webImage;
  bool _isAnalyzing = false;
  String? _errorMessage;
  FoodRecognitionResponse? _recognitionResult;
  final ImagePicker _imagePicker = ImagePicker();

  // Meal type selector
  String _selectedMealType = 'breakfast';
  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  // Progress indicator
  double _analysisProgress = 0.0;

  // Additional foods and ingredients
  List<SelectedFoodItem> _additionalFoods = [];
  List<SelectedIngredient> _additionalIngredients = [];

  // Saving state
  bool _isSaving = false;
  Map<String, dynamic>? _mealTargetCheckResult;
  bool _isCheckingMealTargets = false;
  String? _mealTargetCheckError;
  int _mealTargetCheckVersion = 0;

  LanguageProvider get _language => context.read<LanguageProvider>();

  String _t(String key) => _language.t(key);

  String _localizedMealTypeLabel(String mealType) => _t(mealType);

  String _localizedMealWarning(String warning) {
    switch (warning) {
      case "Projected saturated fat exceeds today's target.":
        return _t('meal_warning_saturated_fat');
      case "Projected sodium exceeds today's target.":
        return _t('meal_warning_sodium');
      case 'This meal is high in carbs for a single sitting.':
        return _t('meal_warning_high_carbs');
      case 'Very low fiber in this meal.':
        return _t('meal_warning_low_fiber');
      default:
        return warning;
    }
  }

  String _detectedItemsLabel(int count) {
    final key = count == 1 ? 'detected_item' : 'detected_items';
    return '$count ${_t(key)}';
  }

  String _localizedIngredientName(Ingredient ingredient) {
    if (_language.isAmharic) {
      final amharicName = ingredient.nameAmharic?.trim();
      if (amharicName != null && amharicName.isNotEmpty) {
        return amharicName;
      }
    }

    return ingredient.name;
  }

  Widget _buildImageWidget() {
    if (kIsWeb && _webImage != null) {
      return Image.memory(
        _webImage!,
        fit: BoxFit.contain,
      );
    } else if (!kIsWeb && _selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.contain,
      );
    } else {
      return const Center(
        child: Icon(
          Icons.image_outlined,
          size: 80,
          color: AppColors.primaryGreen,
        ),
      );
    }
  }

  Widget _buildImageWithOverlays(bool isAmharic) {
    final hasImage =
        (kIsWeb && _webImage != null) || (!kIsWeb && _selectedImage != null);

    if (!hasImage) {
      return _buildImageWidget();
    }

    // If we have recognition results, show overlays
    if (_recognitionResult != null &&
        _recognitionResult!.hasPredictions &&
        _recognitionResult!.imageWidth != null &&
        _recognitionResult!.imageHeight != null) {
      // Build bounding boxes and masks from results
      final boxes = <BoundingBoxData>[];
      final masks = <MaskData>[];

      for (int i = 0; i < _recognitionResult!.predictions.length; i++) {
        final prediction = _recognitionResult!.predictions[i];
        final color = DetectionColors.getColorForFood(
          _buildDetectedFoodTitle(prediction, isAmharic),
        );

        if (prediction.boundingBox != null) {
          boxes.add(BoundingBoxData(
            x1: prediction.boundingBox!.x1,
            y1: prediction.boundingBox!.y1,
            x2: prediction.boundingBox!.x2,
            y2: prediction.boundingBox!.y2,
            label: _buildDetectedFoodTitle(prediction, isAmharic),
            color: color,
          ));
        }

        if (prediction.mask != null) {
          masks.add(MaskData(
            polygon: prediction.mask!.polygon,
            color: color,
          ));
        }
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          // The image
          _buildImageWidget(),
          // Detection overlays
          FoodDetectionOverlay(
            boxes: boxes,
            masks: masks,
            imageSize: Size(
              _recognitionResult!.imageWidth!.toDouble(),
              _recognitionResult!.imageHeight!.toDouble(),
            ),
          ),
        ],
      );
    }

    return _buildImageWidget();
  }

  void _addAdditionalFood(FoodItem item) {
    final existing =
        _additionalFoods.indexWhere((e) => e.foodItem.id == item.id);
    setState(() {
      if (existing >= 0) {
        _additionalFoods[existing].quantity += 1;
      } else {
        _additionalFoods.add(SelectedFoodItem(foodItem: item));
      }
    });
    _scheduleMealTargetCheck();
  }

  String _formatAiLabel(String label) {
    final rawLabel = label.trim();
    return rawLabel
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _buildDetectedFoodTitle(
    FoodRecognitionResult prediction,
    bool isAmharic,
  ) {
    final food = prediction.foodItem;
    if (food != null) {
      final localizedTitle = food.localizedTitle(isAmharic).trim();
      if (localizedTitle.isNotEmpty) {
        return localizedTitle;
      }
    }

    final rawLabel = prediction.foodItem?.aiLabel ?? prediction.label;
    return _formatAiLabel(rawLabel);
  }

  String? _buildDetectedFoodDescription(
    FoodRecognitionResult prediction,
    bool isAmharic,
  ) {
    final food = prediction.foodItem;
    if (food != null) {
      final localizedDescription = food.localizedDescription(isAmharic);
      if (localizedDescription != null && localizedDescription.isNotEmpty) {
        return localizedDescription;
      }
    }

    return null;
  }

  void _removeAdditionalFood(int index) {
    setState(() {
      if (_additionalFoods[index].quantity > 1) {
        _additionalFoods[index].quantity -= 1;
      } else {
        _additionalFoods.removeAt(index);
      }
    });
    _scheduleMealTargetCheck();
  }

  void _addAdditionalIngredient(Ingredient item) {
    final existing =
        _additionalIngredients.indexWhere((e) => e.ingredient.id == item.id);
    setState(() {
      if (existing >= 0) {
        _additionalIngredients[existing].quantity += 1;
      } else {
        _additionalIngredients.add(SelectedIngredient(ingredient: item));
      }
    });
    _scheduleMealTargetCheck();
  }

  Future<void> _openAdditionalFoodSearch() async {
    final selectedFood = await showSearch<FoodItem?>(
      context: context,
      delegate: _FoodSearchDelegate(_language),
    );

    if (!mounted || selectedFood == null) {
      return;
    }

    _addAdditionalFood(selectedFood);
  }

  Future<void> _openAdditionalIngredientSearch() async {
    final selectedIngredient = await showSearch<Ingredient?>(
      context: context,
      delegate: _IngredientSearchDelegate(_language),
    );

    if (!mounted || selectedIngredient == null) {
      return;
    }

    _addAdditionalIngredient(selectedIngredient);
  }

  Future<void> _editDetectedFood(int index) async {
    if (_recognitionResult == null) {
      return;
    }

    final selectedFood = await showSearch<FoodItem?>(
      context: context,
      delegate: _FoodSearchDelegate(_language),
    );

    if (!mounted || selectedFood == null || _recognitionResult == null) {
      return;
    }

    final updatedPredictions =
        List<FoodRecognitionResult>.from(_recognitionResult!.predictions);
    final currentPrediction = updatedPredictions[index];

    updatedPredictions[index] = currentPrediction.copyWith(
      foodItem: selectedFood,
      estimatedCalories:
          _calculateDetectedCalories(selectedFood, currentPrediction.portionGrams),
      estimationMethod: 'manual_override',
    );

    setState(() {
      _recognitionResult = _recognitionResult!.copyWith(
        predictions: updatedPredictions,
      );
    });
    _scheduleMealTargetCheck();
  }

  double _portionGramsForPrediction(FoodRecognitionResult prediction) {
    return prediction.portionGrams ??
        prediction.foodItem?.standardServingSize ??
        150.0;
  }

  double _calculateDetectedCalories(FoodItem food, double? portionGrams) {
    final grams = portionGrams ?? food.standardServingSize;
    return double.parse(
      ((grams / 100.0) * food.caloriesPerServing).toStringAsFixed(1),
    );
  }

  void _removeAdditionalIngredient(int index) {
    setState(() {
      if (_additionalIngredients[index].quantity > 1) {
        _additionalIngredients[index].quantity -= 1;
      } else {
        _additionalIngredients.removeAt(index);
      }
    });
    _scheduleMealTargetCheck();
  }

  double get _detectedFoodsCalories {
    if (_recognitionResult == null) return 0.0;
    return _recognitionResult!.totalCalories;
  }

  double get _additionalFoodsCalories {
    return _additionalFoods.fold(0.0, (sum, item) => sum + item.totalCalories);
  }

  double get _additionalIngredientsCalories {
    return _additionalIngredients.fold(
        0.0,
        (sum, item) =>
            sum + (item.quantity * item.ingredient.caloriesPerServing));
  }

  double get _totalCalories {
    return _detectedFoodsCalories +
        _additionalFoodsCalories +
        _additionalIngredientsCalories;
  }

  double get _totalProtein {
    final detected = _recognitionResult?.predictions
            .where((prediction) => prediction.foodItem != null)
            .fold(0.0, (sum, prediction) {
          final food = prediction.foodItem!;
          final portionGrams = _portionGramsForPrediction(prediction);
          return sum + food.protein * (portionGrams / 100.0);
        }) ??
        0.0;

    return detected +
        _additionalFoods.fold(0.0, (sum, item) => sum + item.totalProtein) +
        _additionalIngredients.fold(
            0.0, (sum, item) => sum + item.totalProtein);
  }

  double get _totalCarbs {
    final detected = _recognitionResult?.predictions
            .where((prediction) => prediction.foodItem != null)
            .fold(0.0, (sum, prediction) {
          final food = prediction.foodItem!;
          final portionGrams = _portionGramsForPrediction(prediction);
          return sum + food.carbohydrates * (portionGrams / 100.0);
        }) ??
        0.0;

    return detected +
        _additionalFoods.fold(0.0, (sum, item) => sum + item.totalCarbs) +
        _additionalIngredients.fold(0.0, (sum, item) => sum + item.totalCarbs);
  }

  double get _totalSaturatedFatG {
    final detected = _recognitionResult?.predictions
            .where((prediction) => prediction.foodItem != null)
            .fold(0.0, (sum, prediction) {
          final food = prediction.foodItem!;
          final portionGrams = _portionGramsForPrediction(prediction);
          return sum + food.saturatedFatG * (portionGrams / 100.0);
        }) ??
        0.0;

    return detected +
        _additionalFoods.fold(
            0.0, (sum, item) => sum + item.totalSaturatedFatG) +
        _additionalIngredients.fold(
            0.0, (sum, item) => sum + item.totalSaturatedFatG);
  }

  double get _totalFiber {
    final detected = _recognitionResult?.predictions
            .where((prediction) => prediction.foodItem != null)
            .fold(0.0, (sum, prediction) {
          final food = prediction.foodItem!;
          final portionGrams = _portionGramsForPrediction(prediction);
          return sum + food.fiber * (portionGrams / 100.0);
        }) ??
        0.0;

    return detected +
        _additionalFoods.fold(0.0, (sum, item) => sum + item.totalFiber) +
        _additionalIngredients.fold(0.0, (sum, item) => sum + item.totalFiber);
  }

  double get _totalSodiumMg {
    final detected = _recognitionResult?.predictions
            .where((prediction) => prediction.foodItem != null)
            .fold(0.0, (sum, prediction) {
          final food = prediction.foodItem!;
          final portionGrams = _portionGramsForPrediction(prediction);
          return sum + food.sodiumMg * (portionGrams / 100.0);
        }) ??
        0.0;

    return detected +
        _additionalFoods.fold(0.0, (sum, item) => sum + item.totalSodiumMg) +
        _additionalIngredients.fold(
            0.0, (sum, item) => sum + item.totalSodiumMg);
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

  void _scheduleMealTargetCheck() {
    if (_recognitionResult == null &&
        _additionalFoods.isEmpty &&
        _additionalIngredients.isEmpty) {
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

  Future<bool> _showMealWarningDialog() async {
    if (_mealWarnings.isEmpty) return true;

    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('review_meal_guidance')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._mealWarnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${_localizedMealWarning(warning)}'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _t('nutrition_disclaimer'),
                style: GoogleFonts.poppins(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('edit_portion')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              _showAlternativeSuggestions();
            },
            child: Text(_t('suggest_alternatives')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: Text(_t('add_anyway')),
          ),
        ],
      ),
    );

    return choice ?? false;
  }

  void _showAlternativeSuggestions() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('suggested_alternatives')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('alternative_lower_salt'),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              _t('alternative_lower_carb'),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              _t('alternative_higher_fiber'),
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('ok')),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('meal_type_label'),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _mealTypes.map((type) {
            final isSelected = type == _selectedMealType;

            return InkWell(
              onTap: () => setState(() => _selectedMealType = type),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.inputBorder,
                  ),
                ),
                child: Text(
                  _localizedMealTypeLabel(type),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _t('analyzing_food'),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Circular progress ring
              CircularProgressIndicator(
                value: _analysisProgress,
                strokeWidth: 8,
                strokeCap: StrokeCap.round,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
              // Percentage text (white, centered)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(_analysisProgress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        // Nutritional summary
        if (_recognitionResult != null && _recognitionResult!.hasPredictions)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAnalysisNutrientCard(
                  _t('protein'),
                  _calculateTotalNutrient((food) => food.protein),
                  'g',
                  const Color(0xFF4A90E2),
                ),
                _buildAnalysisNutrientCard(
                  _t('carbs'),
                  _calculateTotalNutrient((food) => food.carbohydrates),
                  'g',
                  const Color(0xFF52C7A1),
                ),
                _buildAnalysisNutrientCard(
                  _t('fiber'),
                  _calculateTotalNutrient((food) => food.fiber),
                  'g',
                  const Color(0xFF9B59B6),
                ),
              ],
            ),
          ),
      ],
    );
  }

  double _calculateTotalNutrient(double Function(FoodItem) getNutrient) {
    if (_recognitionResult == null) return 0.0;
    double total = 0.0;
    for (final prediction in _recognitionResult!.predictions) {
      if (prediction.foodItem != null) {
        final portionGrams = _portionGramsForPrediction(prediction);
        total += getNutrient(prediction.foodItem!) * (portionGrams / 100.0);
      }
    }
    return total;
  }

  Widget _buildNutrientCard(
    String label,
    double value,
    String unit,
    IconData icon,
  ) {
    // Color mapping for nutrients
    Color cardColor;
    switch (label) {
      case 'Protein':
      case 'ፕሮቲን':
        cardColor = const Color(0xFF4A90E2);
        break;
      case 'Carbs':
      case 'ካርቦሃይድሬት':
        cardColor = const Color(0xFF52C7A1);
        break;
      case 'Fiber':
      case 'ፋይበር':
        cardColor = const Color(0xFF9B59B6);
        break;
      default:
        cardColor = AppColors.primaryGreen;
    }

    return Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 0.75,
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(cardColor),
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
              Text(
                value.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)}$unit',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisNutrientCard(
    String label,
    double value,
    String unit,
    Color cardColor,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 0.75,
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(cardColor),
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
              Text(
                value.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)}$unit',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMissingFoodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          _t('add_missing_foods_or_ingredients'),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildSearchTrigger(
          title: _t('search_missing_food'),
          subtitle: _t('search_missing_food_desc'),
          onTap: _openAdditionalFoodSearch,
        ),
        // Added foods
        if (_additionalFoods.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._additionalFoods.asMap().entries.map((entry) {
            return _buildAdditionalFoodCard(entry.key, entry.value);
          }),
        ],
        const SizedBox(height: 12),
        _buildSearchTrigger(
          title: _t('search_extra_ingredient'),
          subtitle: _t('search_extra_ingredient_desc'),
          onTap: _openAdditionalIngredientSearch,
        ),
        // Added ingredients
        if (_additionalIngredients.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._additionalIngredients.asMap().entries.map((entry) {
            return _buildAdditionalIngredientCard(entry.key, entry.value);
          }),
        ],
      ],
    );
  }

  Widget _buildSearchTrigger({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalFoodCard(int index, SelectedFoodItem item) {
    final title = item.foodItem.localizedTitle(_language.isAmharic);

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
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!_language.isAmharic && item.foodItem.nameAmharic != null)
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
            onDecrease: () => _removeAdditionalFood(index),
            onIncrease: () => _addAdditionalFood(item.foodItem),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalIngredientCard(int index, SelectedIngredient item) {
    final adjustedCalories = item.quantity * item.ingredient.caloriesPerServing;

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
                  _localizedIngredientName(item.ingredient),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (!_language.isAmharic && item.ingredient.nameAmharic != null)
                  Text(
                    item.ingredient.nameAmharic!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  '${adjustedCalories.toStringAsFixed(0)} cal',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGreen,
                  ),
                ),
              ],
            ),
          ),
          _buildQuantityControl(
            quantity: item.quantity,
            onDecrease: () => _removeAdditionalIngredient(index),
            onIncrease: () => _addAdditionalIngredient(item.ingredient),
          ),
        ],
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

  Future<void> _analyzeImage(Uint8List imageBytes, String filename) async {
    setState(() {
      _isAnalyzing = true;
      _analysisProgress = 0.0;
      _errorMessage = null;
      _recognitionResult = null;
      _additionalFoods = [];
      _additionalIngredients = [];
    });

    // Animate progress from 0 to 90% while analyzing
    _startProgressAnimation();

    try {
      final result = await FoodRecognitionService.recognizeFood(
        imageBytes,
        filename,
        mealType: _selectedMealType,
      );

      setState(() {
        _analysisProgress = 1.0; // Reach 100%
        _recognitionResult = result;
        _isAnalyzing = false;
      });
      _scheduleMealTargetCheck();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isAnalyzing = false;
        _analysisProgress = 0.0;
      });
    }
  }

  void _startProgressAnimation() {
    // Simulate progress from 0 to 0.9
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && _isAnalyzing) {
        setState(() {
          if (_analysisProgress < 0.9) {
            _analysisProgress += 0.02;
          }
        });
        return true;
      }
      return false;
    });
  }

  Future<void> _saveMealToHistory() async {
    if (_recognitionResult == null) {
      _showError(_t('no_analysis_result_to_save'));
      return;
    }

    final notificationProvider = context.read<NotificationProvider>();

    // Check if we have at least some foods (either detected or manually added)
    final hasDetectedFoods =
        _recognitionResult!.predictions.any((p) => p.foodItem != null);
    final hasAdditionalFoods = _additionalFoods.isNotEmpty;

    if (!hasDetectedFoods && !hasAdditionalFoods) {
      _showError(_t('no_foods_found_to_save'));
      return;
    }

    if (_mealWarnings.isNotEmpty) {
      final proceed = await _showMealWarningDialog();
      if (!proceed) {
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      // If we have detected foods with matches, use them
      if (hasDetectedFoods) {
        await FoodRecognitionService.saveFoodRecognitionToHistory(
          mealType: _selectedMealType,
          recognitionResult: _recognitionResult!,
          additionalIngredients:
              _additionalIngredients.isNotEmpty ? _additionalIngredients : null,
        );
      } else {
        // Otherwise, save only the manually added foods
        // Still pass the image URL from recognition for records
        final mealResponse = await MealService.createMeal(
          mealType: _selectedMealType,
          foodItems: _additionalFoods,
          imageUrl: _recognitionResult?.imageUrl,
        );

        if (_additionalIngredients.isNotEmpty) {
          await MealService.addIngredientsToMeal(
            mealId: mealResponse.id,
            ingredients: _additionalIngredients,
          );
        }
      }

      await notificationProvider.checkHealthAlerts();

      _showSuccess(
          '${_t('meal_saved')} ${_totalCalories.toStringAsFixed(0)} ${_t('calories_logged')}');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('${_t('error')}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final filename = pickedFile.name;

        setState(() {
          if (kIsWeb) {
            _webImage = bytes;
          } else {
            _selectedImage = File(pickedFile.path);
          }
        });

        await _analyzeImage(bytes, filename);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('error')}: $e')),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final filename = pickedFile.name;

        setState(() {
          if (kIsWeb) {
            _webImage = bytes;
          } else {
            _selectedImage = File(pickedFile.path);
          }
        });

        await _analyzeImage(bytes, filename);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_t('error')}: $e')),
      );
    }
  }

  Widget _buildResultsSection(bool isAmharic) {
    // Don't show results section while analyzing
    if (_isAnalyzing) {
      return const SizedBox.shrink();
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_recognitionResult == null || !_recognitionResult!.hasPredictions) {
      if (_selectedImage != null || _webImage != null) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _t('no_food_items_detected'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // Show detection results with missing foods section
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total calories header with breakdown
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryGreen, AppColors.darkGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  _t('total_estimated_calories'),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_totalCalories.toStringAsFixed(0)} kcal',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _detectedItemsLabel(_recognitionResult!.count),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nutritional summary (Protein, Carbs, Fiber)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNutrientCard(
                  _t('protein'),
                  _calculateTotalNutrient((food) => food.protein),
                  'g',
                  Icons.favorite,
                ),
                _buildNutrientCard(
                  _t('carbs'),
                  _calculateTotalNutrient((food) => food.carbohydrates),
                  'g',
                  Icons.local_fire_department,
                ),
                _buildNutrientCard(
                  _t('fiber'),
                  _calculateTotalNutrient((food) => food.fiber),
                  'g',
                  Icons.nature,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildMealGuidanceCard(),
          const SizedBox(height: 16),

          // Detected foods
          Text(
            _t('detected_foods'),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_recognitionResult!.predictions.length, (index) {
            final prediction = _recognitionResult!.predictions[index];
            final hasMatch = prediction.foodItem != null;
            final title = _buildDetectedFoodTitle(prediction, isAmharic);
            final description =
                _buildDetectedFoodDescription(prediction, isAmharic);
            final detectionColor =
              DetectionColors.getColorForFood(title);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: detectionColor,
                    width: 5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Color indicator
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: detectionColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: detectionColor.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (description != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                description,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (!hasMatch)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_outlined,
                                        size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      _t('not_in_database_choose_correct_food'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.orange,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          prediction.confidencePercentage,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.scale,
                        prediction.portionDisplay,
                      ),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        Icons.local_fire_department,
                        prediction.caloriesDisplay,
                        highlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _editDetectedFood(index),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(
                      hasMatch
                          ? _t('change_detected_food')
                          : _t('select_correct_food'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Missing foods section
          _buildMissingFoodsSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primaryGreen.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight ? AppColors.primaryGreen : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color:
                  highlight ? AppColors.primaryGreen : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealGuidanceCard() {
    if (_mealTargetCheckResult == null &&
        _recognitionResult == null &&
        _additionalFoods.isEmpty &&
        _additionalIngredients.isEmpty) {
      return const SizedBox.shrink();
    }

    final progress = _mealProgress;

    Widget progressBar(String label, dynamic value) {
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
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
              const Icon(
                Icons.health_and_safety,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                _t('meal_guidance'),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
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
                child: Text('• ${_localizedMealWarning(warning)}',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.error)),
              ),
            ),
          ],
          const SizedBox(height: 12),
          progressBar(_t('sodium'), progress['sodium_percent']),
          progressBar(_t('saturated_fat'), progress['saturated_fat_percent']),
          progressBar(_t('fiber'), progress['fiber_percent']),
          progressBar(_t('carbs'), progress['carbs_percent']),
          const SizedBox(height: 8),
          Text(
            '${_t('todays_sodium')}: ${(progress['sodium_percent'] as num?)?.toStringAsFixed(0) ?? '0'}% ${_t('used')}',
            style: GoogleFonts.poppins(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            _t('nutrition_disclaimer'),
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

  @override
  Widget build(BuildContext context) {
    final hasImage =
        (kIsWeb && _webImage != null) || (!kIsWeb && _selectedImage != null);
    final language = context.watch<LanguageProvider>();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      language.t('food_recognition'),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Status text
              if (!_isAnalyzing && !hasImage)
                Text(
                  language.t('add_a_food_image'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                )
              else if (!_isAnalyzing &&
                  _recognitionResult != null &&
                  _recognitionResult!.hasPredictions)
                Text(
                  language.t('analysis_complete'),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryGreen,
                  ),
                ),
              const SizedBox(height: 16),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Meal type selector
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: _buildMealTypeSelector(),
                      ),
                      // Image frame with corner borders and overlays
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          height: hasImage ? 400 : 300,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E8D8),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: hasImage
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildImageWithOverlays(language.isAmharic),
                                      // Loading overlay with progress
                                      if (_isAnalyzing)
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.black.withOpacity(0.4),
                                            borderRadius:
                                                BorderRadius.circular(24),
                                          ),
                                          child: Center(
                                            child: _buildProgressIndicator(),
                                          ),
                                        ),
                                    ],
                                  )
                                : Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _buildImageWithOverlays(language.isAmharic),
                                      CustomPaint(
                                        painter: CornerBorderPainter(
                                          color: AppColors.primaryGreen,
                                          strokeWidth: 4,
                                          cornerSize: 32,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Results section
                      _buildResultsSection(language.isAmharic),
                    ],
                  ),
                ),
              ),

              // Action buttons
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    // Save to History button (shown when analysis complete)
                    if (_recognitionResult != null &&
                        _recognitionResult!.hasPredictions) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveMealToHistory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  language.t('save_to_history'),
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${language.t('total')}: ${_totalCalories.toStringAsFixed(0)} kcal',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ] else ...[
                      _buildImageSourceOptionsInline(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOptionsInline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isAnalyzing ? null : _pickImageFromCamera,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.18),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt,
                      color: AppColors.primaryGreen,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t('camera'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _isAnalyzing ? null : _pickImageFromGallery,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.18),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library,
                      color: AppColors.primaryGreen,
                      size: 32,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _t('gallery'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodSearchDelegate extends SearchDelegate<FoodItem?> {
  _FoodSearchDelegate(this.lang)
      : super(searchFieldLabel: lang.t('search_food_items'));

  final LanguageProvider lang;

  String _lastQuery = '';
  Future<List<FoodItem>>? _lastSearch;

  Future<List<FoodItem>> _searchFoods(String query) {
    if (_lastSearch != null && _lastQuery == query) {
      return _lastSearch!;
    }

    _lastQuery = query;
    _lastSearch = MealService.getFoodItems(search: query);
    return _lastSearch!;
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchResultsList<FoodItem>(
      query: query,
      minQueryMessage: lang.t('search_foods_min_query'),
      emptyMessage: lang.t('no_matching_foods_found'),
      errorMessage: lang.t('search_foods_failed'),
      loadResults: _searchFoods,
      itemBuilder: (context, food) {
        final title = food.localizedTitle(lang.isAmharic);
        return ListTile(
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: food.nameAmharic == null
              ? null
              : Text(
                  food.nameAmharic!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
          trailing: Text(
            '${food.caloriesPerServing.toStringAsFixed(0)} cal',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
          onTap: () => close(context, food),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class _IngredientSearchDelegate extends SearchDelegate<Ingredient?> {
  _IngredientSearchDelegate(this.lang)
      : super(searchFieldLabel: lang.t('search_extra_ingredients'));

  final LanguageProvider lang;

  String _lastQuery = '';
  Future<List<Ingredient>>? _lastSearch;

  Future<List<Ingredient>> _searchIngredients(String query) {
    if (_lastSearch != null && _lastQuery == query) {
      return _lastSearch!;
    }

    _lastQuery = query;
    _lastSearch = MealService.getIngredients(search: query);
    return _lastSearch!;
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchResultsList<Ingredient>(
      query: query,
      minQueryMessage: lang.t('search_ingredients_min_query'),
      emptyMessage: lang.t('no_matching_ingredients_found'),
      errorMessage: lang.t('search_ingredients_failed'),
      loadResults: _searchIngredients,
      itemBuilder: (context, ingredient) {
        final title = lang.isAmharic &&
                ingredient.nameAmharic != null &&
                ingredient.nameAmharic!.trim().isNotEmpty
            ? ingredient.nameAmharic!
            : ingredient.name;
        return ListTile(
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: ingredient.nameAmharic == null
              ? null
              : Text(
                  ingredient.nameAmharic!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
          trailing: Text(
            '${ingredient.caloriesPerServing.toStringAsFixed(0)} cal',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
          onTap: () => close(context, ingredient),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}

class _SearchResultsList<T> extends StatelessWidget {
  const _SearchResultsList({
    required this.query,
    required this.minQueryMessage,
    required this.emptyMessage,
    required this.errorMessage,
    required this.loadResults,
    required this.itemBuilder,
  });

  final String query;
  final String minQueryMessage;
  final String emptyMessage;
  final String errorMessage;
  final Future<List<T>> Function(String query) loadResults;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.length < 2) {
      return Center(
        child: Text(
          minQueryMessage,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return FutureBuilder<List<T>>(
      future: loadResults(trimmedQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              errorMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        final items = snapshot.data ?? <T>[];
        if (items.isEmpty) {
          return Center(
            child: Text(
              emptyMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) => itemBuilder(context, items[index]),
        );
      },
    );
  }
}
