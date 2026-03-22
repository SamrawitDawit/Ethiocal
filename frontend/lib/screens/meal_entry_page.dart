import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/food_entry.dart';
import '../services/nutrition_service.dart';
import '../widgets/app_background.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/nutrition_bottom_sheet.dart';

class MealEntryPage extends StatefulWidget {
  const MealEntryPage({super.key});

  @override
  State<MealEntryPage> createState() => _MealEntryPageState();
}

class _MealEntryPageState extends State<MealEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final List<FoodEntry> _foodEntries = [];

  bool _isLoading = false;
  String? _errorMessage;

  final _foodNameController = TextEditingController();
  final _gramsController = TextEditingController();

  @override
  void dispose() {
    _foodNameController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  void _addFoodEntry() {
    if (_formKey.currentState!.validate()) {
      final foodName = _foodNameController.text.trim();
      final grams = int.parse(_gramsController.text);

      setState(() {
        _foodEntries.add(FoodEntry(name: foodName, grams: grams));
        _foodNameController.clear();
        _gramsController.clear();
        _errorMessage = null;
      });

      FocusScope.of(context).unfocus();
    }
  }

  void _removeFoodEntry(int index) {
    setState(() {
      _foodEntries.removeAt(index);
    });
  }

  Future<void> _calculateCalories() async {
    if (_foodEntries.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one food item';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response =
          await NutritionService.calculateCalories(_foodEntries);

      if (!mounted) return;

      setState(() => _isLoading = false);

      // Optional: slight delay for smoother UX
      await Future.delayed(const Duration(milliseconds: 150));

      showNutritionResult(context, response);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = "Something went wrong. Please try again.";
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    setState(() {
      _foodEntries.clear();
      _errorMessage = null;
    });
  }

  Widget _buildMacroItem(
      String label, double value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Track Your Meal',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.primaryGreen),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          'Add Food Items',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              CustomTextField(
                                controller: _foodNameController,
                                hintText:
                                    'Food name (e.g., chicken breast)',
                                prefixIcon: Icons.restaurant,
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'Please enter a food name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              CustomTextField(
                                controller: _gramsController,
                                hintText: 'Amount in grams',
                                prefixIcon: Icons.scale,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'Please enter the amount in grams';
                                  }
                                  if (int.tryParse(value) == null ||
                                      int.parse(value) <= 0) {
                                    return 'Please enter a valid positive number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              PrimaryButton(
                                text: 'Add Food Item',
                                onPressed: _addFoodEntry,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Food List
                        if (_foodEntries.isNotEmpty) ...[
                          Text(
                            'Food Items Added',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          ...List.generate(_foodEntries.length, (index) {
                            final food = _foodEntries[index];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cardFill,
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.inputBorder),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          food.name,
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${food.grams}g',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color:
                                                AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 20,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () =>
                                        _removeFoodEntry(index),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: PrimaryButton(
                                  text: 'Calculate Calories',
                                  onPressed: _calculateCalories,
                                  isLoading: _isLoading,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: _resetForm,
                                icon: const Icon(
                                  Icons.refresh,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Error Message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}