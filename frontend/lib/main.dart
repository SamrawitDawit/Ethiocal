import 'package:flutter/material.dart';
import 'constants/app_constants.dart';
import 'screens/landing_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/login_page.dart';
import 'screens/food_recognition_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EthioCalApp());
}

class EthioCalApp extends StatelessWidget {
  const EthioCalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EthioCal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      initialRoute: RouteNames.foodRecognition,
      routes: {
        RouteNames.landing: (context) => const LandingPage(),
        RouteNames.signUp: (context) => const SignUpPage(),
        RouteNames.login: (context) => const LoginPage(),
        RouteNames.foodRecognition: (context) => const FoodRecognitionPage(),
      },
    );
  }
}
