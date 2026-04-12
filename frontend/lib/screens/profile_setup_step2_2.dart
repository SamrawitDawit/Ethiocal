import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/profile_setup_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_indicator.dart';

class ProfileSetupStep2_2 extends StatefulWidget {
  const ProfileSetupStep2_2({super.key});

  @override
  State<ProfileSetupStep2_2> createState() => _ProfileSetupStep2_2State();
}

class _ProfileSetupStep2_2State extends State<ProfileSetupStep2_2> {
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
                  'Your Daily Calorie Goal',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Based on your profile information',
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
                      children: [
                        // Profile Summary Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
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
                              Text(
                                'Your Profile',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildProfileRow('Age', '${_calculateAge(provider.birthDate)} years'),
                              _buildProfileRow('Gender', provider.gender),
                              _buildProfileRow('Height', '${provider.height.toStringAsFixed(1)} ${provider.heightUnit}'),
                              _buildProfileRow('Weight', '${provider.weight.toStringAsFixed(1)} ${provider.weightUnit}'),
                              _buildProfileRow('Activity Level', provider.activityLevel),
                              _buildProfileRow('Goal', _formatGoal(provider.goal)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Calorie Goal Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryGreen.withOpacity(0.1),
                                AppColors.primaryGreen.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primaryGreen.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 48,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Daily Calorie Goal',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${provider.dailyCalorieGoal}',
                                style: GoogleFonts.poppins(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              Text(
                                'kcal per day',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Goal Adjustment Options
                        Text(
                          'Adjust Your Goal',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => provider.setGoal('lose_weight'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: provider.goal == 'lose_weight'
                                        ? AppColors.primaryGreen
                                        : AppColors.cardFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: provider.goal == 'lose_weight'
                                          ? AppColors.primaryGreen
                                          : AppColors.inputBorder,
                                    ),
                                  ),
                                  child: Text(
                                    'Lose Weight',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: provider.goal == 'lose_weight'
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
                                onTap: () => provider.setGoal('maintain'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: provider.goal == 'maintain'
                                        ? AppColors.primaryGreen
                                        : AppColors.cardFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: provider.goal == 'maintain'
                                          ? AppColors.primaryGreen
                                          : AppColors.inputBorder,
                                    ),
                                  ),
                                  child: Text(
                                    'Maintain',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: provider.goal == 'maintain'
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
                                onTap: () => provider.setGoal('gain_weight'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: provider.goal == 'gain_weight'
                                        ? AppColors.primaryGreen
                                        : AppColors.cardFill,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: provider.goal == 'gain_weight'
                                          ? AppColors.primaryGreen
                                          : AppColors.inputBorder,
                                    ),
                                  ),
                                  child: Text(
                                    'Gain Weight',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: provider.goal == 'gain_weight'
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Step Indicator
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: const StepIndicator(currentStep: 3, totalSteps: 4),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Navigation Buttons
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            text: 'Continue',
                            onPressed: () {
                              provider.nextStep();
                              Navigator.pushNamed(context, RouteNames.profileSetupStep3);
                            },
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

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatGoal(String goal) {
    switch (goal) {
      case 'lose_weight':
        return 'Lose Weight';
      case 'maintain':
        return 'Maintain Weight';
      case 'gain_weight':
        return 'Gain Weight';
      default:
        return goal;
    }
  }

  int _calculateAge(String birthDate) {
    try {
      final birthDateParts = birthDate.split('-');
      final birthYear = int.parse(birthDateParts[0]);
      final birthMonth = int.parse(birthDateParts[1]);
      final birthDay = int.parse(birthDateParts[2]);
      
      final now = DateTime.now();
      var age = now.year - birthYear;
      
      // Check if birthday has occurred this year
      if (now.month < birthMonth || (now.month == birthMonth && now.day < birthDay)) {
        age--;
      }
      
      return age;
    } catch (e) {
      return 25; // Default age
    }
  }
}
