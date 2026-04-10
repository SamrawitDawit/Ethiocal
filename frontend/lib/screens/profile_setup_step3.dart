import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/profile_setup_provider.dart';
import '../services/auth_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_logo.dart';
import '../widgets/health_condition_card.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_indicator.dart';

class ProfileSetupStep3 extends StatefulWidget {
  const ProfileSetupStep3({super.key});

  @override
  State<ProfileSetupStep3> createState() => _ProfileSetupStep3State();
}

class _ProfileSetupStep3State extends State<ProfileSetupStep3> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProfileSetupProvider>(context, listen: false)
          .loadHealthConditions();
    });
  }

  Future<void> _submitProfile(ProfileSetupProvider provider) async {
    try {
      await provider.submitProfile();
      if (mounted) {
        final loggedIn = await AuthService.isLoggedIn();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          loggedIn ? RouteNames.mainNavigation : RouteNames.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create profile: ${provider.submitError}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
                  'Health Conditions',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select any health conditions you have',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                Consumer<ProfileSetupProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoadingHealthConditions)
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      );

                    if (provider.healthConditionsError.isNotEmpty)
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Text(
                          'Error loading health conditions: ${provider.healthConditionsError}',
                          style: GoogleFonts.poppins(
                            color: AppColors.error,
                            fontSize: 14,
                          ),
                        ),
                      );

                    return Column(
                      children: provider.healthConditions.map((condition) {
                        return HealthConditionCard(
                          condition: condition,
                          onTap: () =>
                              provider.toggleHealthCondition(condition.id),
                        );
                      }).toList(),
                    );
                  },
                ),
                Consumer<ProfileSetupProvider>(
                  builder: (context, provider, child) {
                    if (!provider.isLoadingHealthConditions &&
                        provider.healthConditionsError.isEmpty) {
                      return Column(
                        children: [
                          const SizedBox(height: 40),

                          // Step Indicator
                          const StepIndicator(currentStep: 3, totalSteps: 3),
                          const SizedBox(height: 20),

                          // Finish Button
                          PrimaryButton(
                            text: 'Finish',
                            isLoading: provider.isSubmitting,
                            onPressed: () => _submitProfile(provider),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
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
