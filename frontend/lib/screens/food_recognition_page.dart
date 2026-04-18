import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../constants/app_constants.dart';
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
  String? _imageFilename;
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
  List<FoodItem> _foodItems = [];
  List<Ingredient> _ingredients = [];
  List<SelectedFoodItem> _additionalFoods = [];
  List<SelectedIngredient> _additionalIngredients = [];
  FoodItem? _selectedFoodDropdown;
  Ingredient? _selectedIngredientDropdown;
  bool _isFetchingData = true;

  // Saving state
  bool _isSaving = false;

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
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingData = false);
      }
    }
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

  Widget _buildImageWithOverlays() {
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
        final color = DetectionColors.getColorForFood(prediction.displayName);

        if (prediction.boundingBox != null) {
          boxes.add(BoundingBoxData(
            x1: prediction.boundingBox!.x1,
            y1: prediction.boundingBox!.y1,
            x2: prediction.boundingBox!.x2,
            y2: prediction.boundingBox!.y2,
            label: prediction.displayName,
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
      _selectedFoodDropdown = null;
    });
  }

  void _removeAdditionalFood(int index) {
    setState(() {
      if (_additionalFoods[index].quantity > 1) {
        _additionalFoods[index].quantity -= 1;
      } else {
        _additionalFoods.removeAt(index);
      }
    });
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
      _selectedIngredientDropdown = null;
    });
  }

  void _removeAdditionalIngredient(int index) {
    setState(() {
      if (_additionalIngredients[index].quantity > 1) {
        _additionalIngredients[index].quantity -= 1;
      } else {
        _additionalIngredients.removeAt(index);
      }
    });
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
                onTap: _isAnalyzing
                    ? null
                    : () => setState(() => _selectedMealType = type),
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

  Widget _buildProgressIndicator() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Analyzing your food...',
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
                  'Protein',
                  _calculateTotalNutrient((food) => food.protein),
                  'g',
                  Color(0xFF4A90E2),
                ),
                _buildAnalysisNutrientCard(
                  'Carbs',
                  _calculateTotalNutrient((food) => food.carbohydrates),
                  'g',
                  Color(0xFF52C7A1),
                ),
                _buildAnalysisNutrientCard(
                  'Fiber',
                  _calculateTotalNutrient((food) => food.fiber),
                  'g',
                  Color(0xFF9B59B6),
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
        final portionGrams = prediction.portionGrams ?? 150.0;
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
        cardColor = Color(0xFF4A90E2);
        break;
      case 'Carbs':
        cardColor = Color(0xFF52C7A1);
        break;
      case 'Fiber':
        cardColor = Color(0xFF9B59B6);
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
          'Add Missing Foods or Ingredients',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        // Food dropdown
        Container(
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
                'Add a food item...',
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
                  _addAdditionalFood(food);
                }
              },
            ),
          ),
        ),
        // Added foods
        if (_additionalFoods.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._additionalFoods.asMap().entries.map((entry) {
            return _buildAdditionalFoodCard(entry.key, entry.value);
          }),
        ],
        // Ingredient dropdown
        const SizedBox(height: 12),
        Container(
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
                'Add an ingredient...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              value: _selectedIngredientDropdown,
              items: _ingredients.map((ing) {
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
              }).toList(),
              onChanged: (ing) {
                if (ing != null) {
                  _addAdditionalIngredient(ing);
                }
              },
            ),
          ),
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

  Widget _buildAdditionalFoodCard(int index, SelectedFoodItem item) {
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
                  item.ingredient.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.ingredient.nameAmharic != null)
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

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Food Image',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Camera option
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen.withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.primaryGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Camera',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Gallery option
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen.withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          color: AppColors.primaryGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gallery',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
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
      _showError('No analysis result to save');
      return;
    }

    // Check if we have at least some foods (either detected or manually added)
    final hasDetectedFoods =
        _recognitionResult!.predictions.any((p) => p.foodItem != null);
    final hasAdditionalFoods = _additionalFoods.isNotEmpty;

    if (!hasDetectedFoods && !hasAdditionalFoods) {
      _showError(
          'No foods found. Please add foods from the dropdown below the results.');
      return;
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

      _showSuccess(
          'Meal saved! ${_totalCalories.toStringAsFixed(0)} calories logged.');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
      setState(() => _isSaving = false);
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
          _imageFilename = filename;
        });

        await _analyzeImage(bytes, filename);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
          _imageFilename = filename;
        });

        await _analyzeImage(bytes, filename);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildResultsSection() {
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
            'No food items detected. Try taking another photo.',
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
                  'Total Estimated Calories',
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
                  '${_recognitionResult!.count} detected item${_recognitionResult!.count > 1 ? 's' : ''}',
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
                  'Protein',
                  _calculateTotalNutrient((food) => food.protein),
                  'g',
                  Icons.favorite,
                ),
                _buildNutrientCard(
                  'Carbs',
                  _calculateTotalNutrient((food) => food.carbohydrates),
                  'g',
                  Icons.local_fire_department,
                ),
                _buildNutrientCard(
                  'Fiber',
                  _calculateTotalNutrient((food) => food.fiber),
                  'g',
                  Icons.nature,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detected foods
          Text(
            'Detected Foods',
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
            final detectionColor =
                DetectionColors.getColorForFood(prediction.displayName);

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
                              prediction.displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (prediction.displayNameAmharic != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                prediction.displayNameAmharic!,
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
                                      'Not in database - please add manually',
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

  @override
  Widget build(BuildContext context) {
    final hasImage =
        (kIsWeb && _webImage != null) || (!kIsWeb && _selectedImage != null);

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
                      'Food Recognition',
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
                  'Add a food image',
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
                  'Analysis Complete',
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
                                      _buildImageWithOverlays(),
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
                                      _buildImageWithOverlays(),
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
                      _buildResultsSection(),
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
                                  'Save to History',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total: ${_totalCalories.toStringAsFixed(0)} kcal',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ] else ...[
                      // Camera button (shown when no image)
                      GestureDetector(
                        onTap: _isAnalyzing ? null : _showImageSourceOptions,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isAnalyzing
                                ? AppColors.primaryGreen.withOpacity(0.5)
                                : AppColors.primaryGreen,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGreen.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _selectedImage != null || _webImage != null
                                ? Icons.refresh
                                : Icons.add,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
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
}
