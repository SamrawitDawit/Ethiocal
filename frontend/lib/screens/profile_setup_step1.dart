import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/profile_setup_provider.dart';
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
  late TextEditingController _birthDateController;

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)), // Default to 25 years ago
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 120)), // 120 years ago
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)), // 13 years ago (minimum age)
    );
    
    if (picked != null) {
      final formattedDate = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _birthDateController.text = formattedDate;
      Provider.of<ProfileSetupProvider>(context, listen: false).setBirthDate(formattedDate);
    }
  }

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ProfileSetupProvider>(context, listen: false);
    _birthDateController = TextEditingController(text: provider.birthDate);
  }

  @override
  void dispose() {
    _birthDateController.dispose();
    super.dispose();
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
                        // Birth Date Field
                        Text(
                          'Birth Date',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectBirthDate(context),
                          child: AbsorbPointer(
                            child: CustomTextField(
                              controller: _birthDateController,
                              hintText: 'YYYY-MM-DD',
                              prefixIcon: Icons.cake,
                              keyboardType: TextInputType.none,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select your birth date';
                                }
                                // Basic date format validation
                                final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                                if (!dateRegex.hasMatch(value)) {
                                  return 'Please enter a valid date (YYYY-MM-DD)';
                                }
                                return null;
                              },
                              onChanged: (value) {
                                provider.setBirthDate(value);
                              },
                            ),
                          ),
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
                                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                                DropdownMenuItem(value: 'Sedentary', child: Text('Sedentary')),
                                DropdownMenuItem(value: 'Lightly Active', child: Text('Lightly Active')),
                                DropdownMenuItem(value: 'Moderately Active', child: Text('Moderately Active')),
                                DropdownMenuItem(value: 'Very Active', child: Text('Very Active')),
                                DropdownMenuItem(value: 'Extra Active', child: Text('Extra Active')),
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

                        // Goal Selection
                        Text(
                          'Fitness Goal',
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
                              value: provider.goal,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'maintain', child: Text('Maintain Weight')),
                                DropdownMenuItem(value: 'lose_weight', child: Text('Lose Weight')),
                                DropdownMenuItem(value: 'gain_weight', child: Text('Gain Weight')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  provider.setGoal(value);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Step Indicator
                        const StepIndicator(currentStep: 1, totalSteps: 4),
                        const SizedBox(height: 20),

                        // Continue Button
                        PrimaryButton(
                          text: 'Continue',
                          onPressed: provider.isStep1Valid()
                              ? () {
                                  provider.nextStep();
                                  Navigator.pushNamed(context, RouteNames.profileSetupStep2);
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
