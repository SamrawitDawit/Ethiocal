import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'screens/landing_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/meal_entry_page.dart';
import 'screens/profile_setup_step1.dart';
import 'screens/profile_setup_step2.dart';
import 'screens/profile_setup_step3.dart';
import 'providers/profile_setup_provider.dart';
import 'screens/food_recognition_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EthioCalApp());
}

class EthioCalApp extends StatelessWidget {
  const EthioCalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfileSetupProvider(),
      child: MaterialApp(
        title: 'EthioCal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
          scaffoldBackgroundColor: AppColors.background,
          useMaterial3: true,
        ),
        initialRoute: RouteNames.landing,
        routes: {
          RouteNames.landing: (context) => const LandingPage(),
          RouteNames.signUp: (context) => const SignUpPage(),
          RouteNames.login: (context) => const LoginPage(),
          RouteNames.home: (context) => const HomePage(),
          RouteNames.mealEntry: (context) => const MealEntryPage(),
          RouteNames.profileSetupStep1: (context) => const ProfileSetupStep1(),
          RouteNames.profileSetupStep2: (context) => const ProfileSetupStep2(),
          RouteNames.profileSetupStep3: (context) => const ProfileSetupStep3(),
          RouteNames.foodRecognition: (context) => const FoodRecognitionPage(),
        },
      ),
    );
  }
}
