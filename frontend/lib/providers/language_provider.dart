import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'language_preference';
  String _currentLanguage = 'English';

  String get currentLanguage => _currentLanguage;
  bool get isAmharic => _currentLanguage == 'Amharic';

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_prefKey) ?? 'English';
    notifyListeners();
  }

  Future<void> switchLanguage(String language) async {
    if (language != 'English' && language != 'Amharic') return;
    _currentLanguage = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, language);
    notifyListeners();

    // Persist to backend
    try {
      await ApiService.patch(
        ApiConstants.meEndpoint,
        {'language_preference': language},
        requireAuth: true,
      );
    } catch (_) {
      // Preference saved locally even if backend fails
    }
  }

  String t(String key) {
    final map = isAmharic ? _amharicStrings : _englishStrings;
    return map[key] ?? _englishStrings[key] ?? key;
  }

  // --- English Strings ---
  static const Map<String, String> _englishStrings = {
    // General
    'app_name': 'EthioCal',
    'home': 'Home',
    'history': 'History',
    'profile': 'Profile',
    'stats': 'Stats',
    'settings': 'Settings',
    'logout': 'Logout',
    'save': 'Save',
    'cancel': 'Cancel',
    'ok': 'OK',
    'error': 'Error',
    'loading': 'Loading...',
    'retry': 'Retry',

    // Auth
    'login': 'Login',
    'sign_up': 'Sign Up',
    'email': 'Email',
    'password': 'Password',
    'full_name': 'Full Name',
    'welcome_back': 'Welcome Back',
    'create_account': 'Create Account',

    // Home
    'this_week': 'This Week',
    'todays_intake': "Today's Intake",
    'consumed': 'Consumed',
    'remaining': 'Remaining',
    'over': 'Over',
    'quick_actions': 'Quick Actions',
    'text_entry': 'Text Entry',
    'capture_food': 'Capture Food',

    // Profile
    'edit_profile': 'Edit Profile',
    'help_support': 'Help & Support',
    'language': 'Language',
    'language_settings': 'Language Settings',
    'select_language': 'Select Language',
    'english': 'English',
    'amharic': 'Amharic',

    // Notifications
    'notifications': 'Notifications',
    'notification_preferences': 'Notification Preferences',
    'meal_reminders': 'Meal Reminders',
    'meal_reminders_desc': 'Get reminded to log your meals',
    'health_alerts': 'Health Alerts',
    'health_alerts_desc': 'Get notified when dietary limits are exceeded',
    'reminder_times': 'Reminder Times',
    'recent_notifications': 'Recent Notifications',
    'mark_all_read': 'Mark all read',
    'no_notifications': 'No notifications yet',

    // Meal
    'meal_entry': 'Meal Entry',
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snack',
    'food_recognition': 'Food Recognition',

    // Profile Setup
    'profile_setup': 'Profile Setup',
    'age': 'Age',
    'gender': 'Gender',
    'height': 'Height',
    'weight': 'Weight',
    'activity_level': 'Activity Level',
    'daily_calorie_goal': 'Daily Calorie Goal',
    'health_conditions': 'Health Conditions',

    // History
    'meal_history': 'Meal History',
    'meal_history_desc':
        'Your recent meals and nutritional data will appear here.',
    'no_meals_logged': 'No meals logged yet',
    'start_tracking': 'Start tracking your meals to see your history here',

    // Statistics
    'statistics': 'Statistics',
    'total_calories': 'Total Calories',
    'meals_logged': 'Meals Logged',
    'avg_calories': 'Avg Calories',
    'days_tracked': 'Days Tracked',
    'weekly_overview': 'Weekly Overview',
    'no_data': 'No data available yet',
    'start_logging_stats': 'Start logging meals to see your statistics',
  };

  // --- Amharic Strings ---
  static const Map<String, String> _amharicStrings = {
    // General
    'app_name': 'ኢትዮካል',
    'home': 'ዋና ገጽ',
    'history': 'ታሪክ',
    'profile': 'መገለጫ',
    'stats': 'ስታቲስቲክስ',
    'settings': 'ቅንብሮች',
    'logout': 'ውጣ',
    'save': 'አስቀምጥ',
    'cancel': 'ሰርዝ',
    'ok': 'እሺ',
    'error': 'ስህተት',
    'loading': 'በመጫን ላይ...',
    'retry': 'ደግም',

    // Auth
    'login': 'ግባ',
    'sign_up': 'ተመዝገብ',
    'email': 'ኢሜይል',
    'password': 'የይለፍ ቃል',
    'full_name': 'ሙሉ ስም',
    'welcome_back': 'እንኳን ደህና መጡ',
    'create_account': 'መለያ ፍጠር',

    // Home
    'this_week': 'ይህ ሳምንት',
    'todays_intake': 'የዛሬ ምግብ',
    'consumed': 'የተወሰደ',
    'remaining': 'የቀረ',
    'over': 'ከመጠን በላይ',
    'quick_actions': 'ፈጣን ድርጊቶች',
    'text_entry': 'የጽሑፍ ግቤት',
    'capture_food': 'ምግብ ቅረጽ',

    // Profile
    'edit_profile': 'መገለጫ አርትዕ',
    'help_support': 'እርዳታ እና ድጋፍ',
    'language': 'ቋንቋ',
    'language_settings': 'የቋንቋ ቅንብሮች',
    'select_language': 'ቋንቋ ይምረጡ',
    'english': 'English',
    'amharic': 'አማርኛ',

    // Notifications
    'notifications': 'ማሳወቂያዎች',
    'notification_preferences': 'የማሳወቂያ ምርጫዎች',
    'meal_reminders': 'የምግብ ማስታወሻ',
    'meal_reminders_desc': 'ምግብዎን እንዲመዘግቡ ያስታውስዎታል',
    'health_alerts': 'የጤና ማንቂያዎች',
    'health_alerts_desc': 'የአመጋገብ ገደቦች ሲበልጡ ያሳውቅዎታል',
    'reminder_times': 'የማስታወሻ ሰዓቶች',
    'recent_notifications': 'የቅርብ ማሳወቂያዎች',
    'mark_all_read': 'ሁሉንም አንብብ',
    'no_notifications': 'ገና ምንም ማሳወቂያ የለም',

    // Meal
    'meal_entry': 'የምግብ ግቤት',
    'breakfast': 'ቁርስ',
    'lunch': 'ምሳ',
    'dinner': 'እራት',
    'snack': 'መክሰስ',
    'food_recognition': 'የምግብ ማወቅ',

    // Profile Setup
    'profile_setup': 'የመገለጫ ማዋቀር',
    'age': 'ዕድሜ',
    'gender': 'ጾታ',
    'height': 'ቁመት',
    'weight': 'ክብደት',
    'activity_level': 'የእንቅስቃሴ ደረጃ',
    'daily_calorie_goal': 'የቀን ካሎሪ ግብ',
    'health_conditions': 'የጤና ሁኔታዎች',

    // History
    'meal_history': 'የምግብ ታሪክ',
    'meal_history_desc': 'የቅርብ ጊዜ ምግቦችዎ እና የአመጋገብ መረጃዎ እዚህ ይታያሉ።',
    'no_meals_logged': 'ገና ምንም ምግብ አልተመዘገበም',
    'start_tracking': 'ታሪክዎን ለማየት ምግቦችዎን መመዝገብ ይጀምሩ',

    // Statistics
    'statistics': 'ስታቲስቲክስ',
    'total_calories': 'ጠቅላላ ካሎሪዎች',
    'meals_logged': 'የተመዘገቡ ምግቦች',
    'avg_calories': 'አማካይ ካሎሪ',
    'days_tracked': 'የተከታተሉ ቀናት',
    'weekly_overview': 'ሳምንታዊ ማጠቃለያ',
    'no_data': 'ገና ምንም መረጃ የለም',
    'start_logging_stats': 'ስታቲስቲክስዎን ለማየት ምግቦችን መመዝገብ ይጀምሩ',
  };
}
