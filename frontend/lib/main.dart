import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'providers/profile_setup_provider.dart';
import 'screens/landing_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/login_page.dart';
import 'screens/profile_setup_step1.dart';
import 'screens/profile_setup_step2.dart';
import 'screens/profile_setup_step3.dart';

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
          '/profile-setup/step1': (context) => const ProfileSetupStep1(),
          '/profile-setup/step2': (context) => const ProfileSetupStep2(),
          '/profile-setup/step3': (context) => const ProfileSetupStep3(),
        },
      ),
    );
  }
}
