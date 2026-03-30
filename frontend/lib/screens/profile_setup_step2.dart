import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/profile_setup_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_slider.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_indicator.dart';
import '../widgets/unit_toggle_button.dart';

class ProfileSetupStep2 extends StatefulWidget {
  const ProfileSetupStep2({super.key});

  @override
  State<ProfileSetupStep2> createState() => _ProfileSetupStep2State();
}

class _ProfileSetupStep2State extends State<ProfileSetupStep2> {
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ProfileSetupProvider>(context, listen: false);
    _heightController = TextEditingController(
        text: provider.heightUnit == 'ft'
            ? provider.height.toStringAsFixed(1)
            : provider.height.round().toString());
    _weightController = TextEditingController(text: provider.weight.toString());
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double _convertHeight(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    
    if (fromUnit == 'cm' && toUnit == 'ft') {
      return value / 30.48; // cm to feet
    } else if (fromUnit == 'ft' && toUnit == 'cm') {
      return value * 30.48; // feet to cm
    }
    return value;
  }

  double _convertWeight(double value, String fromUnit, String toUnit) {
    if (fromUnit == toUnit) return value;
    
    if (fromUnit == 'kg' && toUnit == 'lbs') {
      return value * 2.20462; // kg to lbs
    } else if (fromUnit == 'lbs' && toUnit == 'kg') {
      return value / 2.20462; // lbs to kg
    }
    return value;
  }

  String _formatHeight(double value, String unit) {
    return '${value.toStringAsFixed(1)} $unit';
  }

  String _formatWeight(double value, String unit) {
    return '${value.toStringAsFixed(1)} $unit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.cardFill,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    const AppLogo(),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  'Body Measurements',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your height and weight',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 30),

                Consumer<ProfileSetupProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      children: [
                        // Height Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardFill,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
Row(
                                children: [
                                  Text(
                                    'Height',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: 120,
                                    height: 40,
                                    child: UnitToggleButton(
                                      option1: 'cm',
                                      option2: 'ft',
                                      selectedOption: provider.heightUnit,
                                      onOptionSelected: (unit) {
                                        final currentValue = provider.height.toDouble();
                                        final convertedValue = _convertHeight(currentValue, provider.heightUnit, unit);
                                        if (unit == 'ft') {
                                          provider.setHeight(convertedValue);
                                          _heightController.text = convertedValue.toStringAsFixed(1);
                                        } else {
                                          provider.setHeight(convertedValue.roundToDouble());
                                          _heightController.text = convertedValue.round().toString();
                                        }
                                        provider.setHeightUnit(unit);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Input Field
                              CustomTextField(
                                controller: _heightController,
                                hintText: 'Enter height',
                                prefixIcon: Icons.height,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  final height = double.tryParse(value) ?? 0;
                                  if (height > 0) {
                                    if (provider.heightUnit == 'ft') {
                                      provider.setHeight(height);
                                    } else {
                                      provider.setHeight(height);
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // Display value
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatHeight(provider.height.toDouble(), provider.heightUnit),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Slider
                              CustomSlider(
                                value: provider.height.toDouble(),
                                min: provider.heightUnit == 'cm' ? 100 : 3.2,
                                max: provider.heightUnit == 'cm' ? 250 : 8.2,
                                unit: provider.heightUnit,
                                showValue: false,
                                onChanged: (value) {
                                  if (provider.heightUnit == 'ft') {
                                    provider.setHeight(value);
                                    _heightController.text = value.toStringAsFixed(1);
                                  } else {
                                    provider.setHeight(value.roundToDouble());
                                    _heightController.text = value.round().toString();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Weight Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardFill,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
Row(
                                children: [
                                  Text(
                                    'Weight',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: 120,
                                    height: 40,
                                    child: UnitToggleButton(
                                      option1: 'kg',
                                      option2: 'lbs',
                                      selectedOption: provider.weightUnit,
                                      onOptionSelected: (unit) {
                                        final currentValue = provider.weight.toDouble();
                                        final convertedValue = _convertWeight(currentValue, provider.weightUnit, unit);
                                        provider.setWeight(convertedValue);
                                        provider.setWeightUnit(unit);
                                        _weightController.text = convertedValue.toStringAsFixed(1);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Input Field
                              CustomTextField(
                                controller: _weightController,
                                hintText: 'Enter weight',
                                prefixIcon: Icons.monitor_weight,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  final weight = double.tryParse(value) ?? 0;
                                  if (weight > 0) {
                                    provider.setWeight(weight);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),

                              // Display value
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatWeight(provider.weight.toDouble(), provider.weightUnit),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Slider
                              CustomSlider(
                                value: provider.weight.toDouble(),
                                min: provider.weightUnit == 'kg' ? 30 : 66,
                                max: provider.weightUnit == 'kg' ? 200 : 441,
                                unit: provider.weightUnit,
                                showValue: false,
                                onChanged: (value) {
                                  provider.setWeight(value);
                                  _weightController.text = value.toStringAsFixed(1);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Centered Step Indicator
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: const StepIndicator(currentStep: 2, totalSteps: 3),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Navigation Buttons
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            text: 'Continue',
                            onPressed: provider.isStep2Valid()
                                ? () {
                                    provider.nextStep();
                                    Navigator.pushNamed(context, RouteNames.profileSetupStep3);
                                  }
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
