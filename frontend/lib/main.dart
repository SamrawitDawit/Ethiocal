import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'screens/landing_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/meal_entry_page.dart';
import 'screens/main_navigation.dart';
import 'screens/history_page.dart';
import 'screens/profile_page.dart';
import 'screens/food_recognition_page.dart';
import 'screens/stats_page.dart';
import 'screens/profile_setup_step1.dart';
import 'screens/profile_setup_step2.dart';
import 'screens/profile_setup_step3.dart';
import 'screens/notification_settings_page.dart';
import 'screens/language_settings_page.dart';
import 'providers/profile_setup_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/language_provider.dart';
import 'services/local_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.initialize();
  runApp(const EthioCalApp());
}

class EthioCalApp extends StatelessWidget {
  const EthioCalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileSetupProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(
            create: (_) => LanguageProvider()..loadLanguage()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, lang, _) {
          return MaterialApp(
            title: lang.t('app_name'),
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
              scaffoldBackgroundColor: AppColors.background,
              useMaterial3: true,
            ),
            initialRoute: RouteNames.landing,
            routes: {
              RouteNames.landing: (context) => const LandingPage(),
              RouteNames.signUp: (context) => const SignUpPage(),
              RouteNames.login: (context) => const LoginPage(),
              RouteNames.home: (context) => const HomePage(),
              RouteNames.mainNavigation: (context) => const MainNavigation(),
              RouteNames.mealEntry: (context) => const MealEntryPage(),
              RouteNames.profileSetupStep1: (context) =>
                  const ProfileSetupStep1(),
              RouteNames.profileSetupStep2: (context) =>
                  const ProfileSetupStep2(),
              RouteNames.profileSetupStep3: (context) =>
                  const ProfileSetupStep3(),
              RouteNames.foodRecognition: (context) =>
                  const FoodRecognitionPage(),
              RouteNames.history: (context) => const HistoryPage(),
              RouteNames.profile: (context) => const ProfilePage(),
              RouteNames.stats: (context) => const StatsPage(),
              RouteNames.notificationSettings: (context) =>
                  const NotificationSettingsPage(),
              RouteNames.languageSettings: (context) =>
                  const LanguageSettingsPage(),
            },
          );
        },
      ),
    );
  }
}
