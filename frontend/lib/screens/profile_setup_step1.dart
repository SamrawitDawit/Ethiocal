import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/profile_setup_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_logo.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_indicator.dart';

class ProfileSetupStep1 extends StatefulWidget {
  const ProfileSetupStep1({super.key});

  @override
  State<ProfileSetupStep1> createState() => _ProfileSetupStep1State();
}

class _ProfileSetupStep1State extends State<ProfileSetupStep1> {
  late TextEditingController _ageController;
  late TextEditingController _calorieController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ProfileSetupProvider>(context, listen: false);
    _ageController = TextEditingController(text: provider.age.toString());
    _calorieController =
        TextEditingController(text: provider.dailyCalorieGoal.toString());
  }

  @override
  void dispose() {
    _ageController.dispose();
    _calorieController.dispose();
    super.dispose();
  }

  Future<void> _skipSetup() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      loggedIn ? RouteNames.mainNavigation : RouteNames.login,
      (route) => false,
    );
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
                    const Spacer(),
                    TextButton(
                      onPressed: _skipSetup,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.poppins(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  'Create Your Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Let\'s get to know you better',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                Consumer<ProfileSetupProvider>(
                  builder: (context, provider, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Age Field
                        Text(
                          'Age',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _ageController,
                                hintText: 'Enter your age',
                                prefixIcon: Icons.person,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your age';
                                  }
                                  final age = int.tryParse(value);
                                  if (age == null || age <= 0) {
                                    return 'Please enter a valid age';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  final age = int.tryParse(value) ?? 0;
                                  provider.setAge(age);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      final currentAge =
                                          int.tryParse(_ageController.text) ??
                                              0;
                                      final newAge = currentAge + 1;
                                      _ageController.text = newAge.toString();
                                      provider.setAge(newAge);
                                    },
                                    child: const Icon(
                                      Icons.keyboard_arrow_up,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      final currentAge =
                                          int.tryParse(_ageController.text) ??
                                              0;
                                      final newAge =
                                          (currentAge > 0) ? currentAge - 1 : 0;
                                      _ageController.text = newAge.toString();
                                      provider.setAge(newAge);
                                    },
                                    child: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Gender Selection
                        Text(
                          'Gender',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => provider.setGender('Male'),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: provider.gender == 'Male'
                                        ? AppColors.primaryGreen
                                        : AppColors.cardFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: provider.gender == 'Male'
                                          ? AppColors.primaryGreen
                                          : AppColors.inputBorder,
                                    ),
                                  ),
                                  child: Text(
                                    'Male',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: provider.gender == 'Male'
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => provider.setGender('Female'),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: provider.gender == 'Female'
                                        ? AppColors.primaryGreen
                                        : AppColors.cardFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: provider.gender == 'Female'
                                          ? AppColors.primaryGreen
                                          : AppColors.inputBorder,
                                    ),
                                  ),
                                  child: Text(
                                    'Female',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: provider.gender == 'Female'
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Activity Level
                        Text(
                          'Activity Level',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.inputBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: provider.activityLevel,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                    value: 'Sedentary',
                                    child: Text('Sedentary')),
                                DropdownMenuItem(
                                    value: 'Lightly Active',
                                    child: Text('Lightly Active')),
                                DropdownMenuItem(
                                    value: 'Moderately Active',
                                    child: Text('Moderately Active')),
                                DropdownMenuItem(
                                    value: 'Very Active',
                                    child: Text('Very Active')),
                                DropdownMenuItem(
                                    value: 'Extra Active',
                                    child: Text('Extra Active')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  provider.setActivityLevel(value);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Target Calorie
                        Text(
                          'Target Calorie',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _calorieController,
                          hintText: 'Enter daily calorie goal',
                          prefixIcon: Icons.local_fire_department,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your daily calorie goal';
                            }
                            final calories = int.tryParse(value);
                            if (calories == null || calories <= 0) {
                              return 'Please enter a valid calorie goal';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            final calories = int.tryParse(value) ?? 0;
                            provider.setDailyCalorieGoal(calories);
                          },
                        ),
                        const SizedBox(height: 40),

                        // Step Indicator
                        const StepIndicator(currentStep: 1, totalSteps: 3),
                        const SizedBox(height: 20),

                        // Continue Button
                        PrimaryButton(
                          text: 'Continue',
                          onPressed: provider.isStep1Valid()
                              ? () {
                                  provider.nextStep();
                                  Navigator.pushNamed(
                                      context, RouteNames.profileSetupStep2);
                                }
                              : null,
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
