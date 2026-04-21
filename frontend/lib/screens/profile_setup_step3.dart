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

class ProfileSetupStep3 extends StatefulWidget {
  const ProfileSetupStep3({super.key});

  @override
  State<ProfileSetupStep3> createState() => _ProfileSetupStep3State();
}

class _ProfileSetupStep3State extends State<ProfileSetupStep3> {
  final TextEditingController _hba1cController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProfileSetupProvider>(context, listen: false)
          .loadHealthConditions();
    });
  }

  @override
  void dispose() {
    _hba1cController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile(ProfileSetupProvider provider) async {
    final success = await provider.submitProfile();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.login,
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create profile: ${provider.submitError}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
                const SizedBox(height: 20),
                Consumer<ProfileSetupProvider>(
                  builder: (context, provider, child) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                            'Dietary Health Flags',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quick yes/no answers for diet guidance.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Do you have diabetes?'),
                            value: provider.hasDiabetes,
                            onChanged: provider.setHasDiabetes,
                          ),
                          if (provider.hasDiabetes) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.inputBorder),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text('Select diabetes type'),
                                  value: provider.diabetesType,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Type 1', child: Text('Type 1')),
                                    DropdownMenuItem(
                                        value: 'Type 2', child: Text('Type 2')),
                                  ],
                                  onChanged: provider.setDiabetesType,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            CustomTextField(
                              controller: _hba1cController,
                              hintText: 'Latest HbA1c (optional)',
                              prefixIcon: Icons.monitor_heart_outlined,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (value) {
                                provider.setLatestHbA1c(double.tryParse(value));
                              },
                            ),
                          ],
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Do you have hypertension?'),
                            value: provider.hasHypertension,
                            onChanged: provider.setHasHypertension,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Do you have high cholesterol?'),
                            value: provider.hasHighCholesterol,
                            onChanged: provider.setHasHighCholesterol,
                          ),
                        ],
                      ),
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
