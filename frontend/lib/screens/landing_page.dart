import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../widgets/app_background.dart';
import '../widgets/app_logo.dart';
import '../widgets/primary_button.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                const AppLogo(imageHeight: 48, fontSize: 28),
                const Spacer(flex: 1),
                // Hero image - large, close to the button
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Image.asset(
                      'assets/images/landing_hero.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'Get Started',
                  onPressed: () {
                    Navigator.pushNamed(context, RouteNames.signUp);
                  },
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  text: 'Track Meal (Test)',
                  onPressed: () {
                    Navigator.pushNamed(context, RouteNames.mealEntry);
                  },
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, RouteNames.login);
                  },
                  child: Text(
                    'I already have an account',
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
