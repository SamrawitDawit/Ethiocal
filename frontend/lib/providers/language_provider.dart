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
    'leaderboard': 'Leaderboard',
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
    'male': 'Male',
    'female': 'Female',
    'sedentary': 'Sedentary',
    'lightly_active': 'Lightly Active',
    'moderately_active': 'Moderately Active',
    'very_active': 'Very Active',
    'type_1': 'Type 1',
    'type_2': 'Type 2',

    // Home
    'this_week': 'This Week',
    'todays_intake': "Today's Intake",
    'consumed': 'Consumed',
    'remaining': 'Remaining',
    'over': 'Over',
    'quick_actions': 'Quick Actions',
    'text_entry': 'Text Entry',
    'capture_food': 'Capture Food',
    'dashboard_load_failed': 'Failed to load dashboard data',
    'back_to_today': 'Back to Today',
    'meal_breakdown': 'Meal Breakdown',
    'protein': 'Protein',
    'carbs': 'Carbs',
    'fat': 'Fat',
    'day_mon_short': 'Mon',
    'day_tue_short': 'Tue',
    'day_wed_short': 'Wed',
    'day_thu_short': 'Thu',
    'day_fri_short': 'Fri',
    'day_sat_short': 'Sat',
    'day_sun_short': 'Sun',

    // Profile
    'edit_profile': 'Edit Profile',
    'help_support': 'Help & Support',
    'language': 'Language',
    'language_settings': 'Language Settings',
    'select_language': 'Select Language',
    'english': 'English',
    'amharic': 'Amharic',
    'save_profile': 'Save Profile',
    'basic_information': 'Basic Information',
    'physical_data': 'Physical Data',
    'app_settings': 'App Settings',
    'language_preference': 'Language Preference',
    'height_cm': 'Height (cm)',
    'weight_kg': 'Weight (kg)',
    'diabetes': 'Diabetes',
    'diabetes_type': 'Diabetes Type',
    'latest_hba1c': 'Latest HbA1c',
    'hypertension': 'Hypertension',
    'high_cholesterol': 'High Cholesterol',
    'profile_updated_successfully': 'Profile updated successfully',
    'profile_load_failed': 'Failed to load profile',
    'profile_update_failed': 'Failed to update profile',

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
    'meal': 'Meal',
    'food_details_unavailable': 'Food details unavailable',
    'review_meal_guidance': 'Review meal guidance',
    'edit_portion': 'Edit portion',
    'suggest_alternatives': 'Suggest alternatives',
    'add_anyway': 'Add anyway',
    'suggested_alternatives': 'Suggested alternatives',
    'alternative_lower_salt':
      'Lower-salt: choose less injera with stews that are heavily salted.',
    'alternative_lower_carb':
      'Lower-carb: favor vegetables, legumes, and smaller grain portions.',
    'alternative_higher_fiber':
      'Higher-fiber: add greens, cabbage, kale, or beans where possible.',
    'meal_type_label': 'Meal Type',
    'analyzing_food': 'Analyzing your food...',
    'add_missing_foods_or_ingredients': 'Add Missing Foods or Ingredients',
    'search_missing_food': 'Search for a missing food',
    'search_missing_food_desc':
      'Find the dish instead of loading the full food list.',
    'search_extra_ingredient': 'Search for an extra ingredient',
    'search_extra_ingredient_desc':
      'Add only what is missing instead of scrolling a dropdown.',
    'add_food_image': 'Add Food Image',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'no_analysis_result_to_save': 'No analysis result to save',
    'no_foods_found_to_save':
      'No foods found. Please add foods using the search controls below the results.',
    'meal_saved': 'Meal saved!',
    'calories_logged': 'calories logged.',
    'no_food_items_detected':
      'No food items detected. Try taking another photo.',
    'total_estimated_calories': 'Total Estimated Calories',
    'detected_foods': 'Detected Foods',
    'detected_item': 'detected item',
    'detected_items': 'detected items',
    'not_in_database_choose_correct_food':
      'Not in database - choose the correct food',
    'change_detected_food': 'Change detected food',
    'select_correct_food': 'Select the correct food',
    'meal_guidance': 'Meal guidance',
    'sodium': 'Sodium',
    'saturated_fat': 'Saturated fat',
    'todays_sodium': "Today's sodium",
    'used': 'used',
    'add_a_food_image': 'Add a food image',
    'analysis_complete': 'Analysis Complete',
    'save_to_history': 'Save to History',
    'total': 'Total',
    'search_food_items': 'Search food items',
    'search_foods_min_query': 'Type at least 2 letters to search foods.',
    'no_matching_foods_found': 'No matching foods found.',
    'search_foods_failed': 'Failed to search foods. Please try again.',
    'search_extra_ingredients': 'Search extra ingredients',
    'search_ingredients_min_query':
      'Type at least 2 letters to search ingredients.',
    'no_matching_ingredients_found': 'No matching ingredients found.',
    'search_ingredients_failed':
      'Failed to search ingredients. Please try again.',
    'nutrition_disclaimer':
      'These are general dietary targets based on 2026 ADA/AHA/Ethiopian NCD guidelines to support clinical goals (HbA1c <7.0%, BP <130/80, LDL <100 mg/dL or lower). They are not medical advice. Always consult your doctor.',
    'meal_warning_saturated_fat':
      "Projected saturated fat exceeds today's target.",
    'meal_warning_sodium': "Projected sodium exceeds today's target.",
    'meal_warning_high_carbs':
      'This meal is high in carbs for a single sitting.',
    'meal_warning_low_fiber': 'Very low fiber in this meal.',

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
    'history_load_failed': 'Failed to load meal history.',

    // Statistics
    'statistics': 'Statistics',
    'total_calories': 'Total Calories',
    'meals_logged': 'Meals Logged',
    'avg_calories': 'Avg Calories',
    'days_tracked': 'Days Tracked',
    'weekly_overview': 'Weekly Overview',
    'no_data': 'No data available yet',
    'start_logging_stats': 'Start logging meals to see your statistics',

    // Education & Awareness
    'education_awareness': 'Education & Awareness',
    'error_loading_content': 'Error loading content',
    'no_education_content': 'No education content available',
    'error_loading_article': 'Error loading article',
    'article_not_found': 'Article not found',

    // Leaderboard
    'leaderboard_load_failed': 'Failed to load leaderboard',
    'no_leaderboard_data': 'No leaderboard data available',
    'rankings': 'Rankings',
    'current': 'Current',
    'best': 'Best',
  };

  // --- Amharic Strings ---
  static const Map<String, String> _amharicStrings = {
    // General
    'app_name': 'ኢትዮካል',
    'home': 'ዋና ገጽ',
    'history': 'ታሪክ',
    'profile': 'መገለጫ',
    'stats': 'ስታቲስቲክስ',
    'leaderboard': 'ሊደርቦርድ',
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
    'male': 'ወንድ',
    'female': 'ሴት',
    'sedentary': 'ዝቅተኛ እንቅስቃሴ',
    'lightly_active': 'ትንሽ ንቁ',
    'moderately_active': 'መጠነኛ ንቁ',
    'very_active': 'በጣም ንቁ',
    'type_1': 'ዓይነት 1',
    'type_2': 'ዓይነት 2',

    // Home
    'this_week': 'ይህ ሳምንት',
    'todays_intake': 'የዛሬ ምግብ',
    'consumed': 'የተወሰደ',
    'remaining': 'የቀረ',
    'over': 'ከመጠን በላይ',
    'quick_actions': 'ፈጣን ድርጊቶች',
    'text_entry': 'የጽሑፍ ግቤት',
    'capture_food': 'ምግብ ቅረጽ',
    'dashboard_load_failed': 'የዳሽቦርድ መረጃን መጫን አልተሳካም',
    'back_to_today': 'ወደ ዛሬ ተመለስ',
    'meal_breakdown': 'የምግብ ክፍፍል',
    'protein': 'ፕሮቲን',
    'carbs': 'ካርቦሃይድሬት',
    'fat': 'ስብ',
    'day_mon_short': 'ሰኞ',
    'day_tue_short': 'ማክ',
    'day_wed_short': 'ረቡ',
    'day_thu_short': 'ሐሙ',
    'day_fri_short': 'ዓር',
    'day_sat_short': 'ቅዳ',
    'day_sun_short': 'እሑ',

    // Profile
    'edit_profile': 'መገለጫ አርትዕ',
    'help_support': 'እርዳታ እና ድጋፍ',
    'language': 'ቋንቋ',
    'language_settings': 'የቋንቋ ቅንብሮች',
    'select_language': 'ቋንቋ ይምረጡ',
    'english': 'English',
    'amharic': 'አማርኛ',
    'save_profile': 'መገለጫ አስቀምጥ',
    'basic_information': 'መሰረታዊ መረጃ',
    'physical_data': 'አካላዊ መረጃ',
    'app_settings': 'የመተግበሪያ ቅንብሮች',
    'language_preference': 'የቋንቋ ምርጫ',
    'height_cm': 'ቁመት (ሴሜ)',
    'weight_kg': 'ክብደት (ኪግ)',
    'diabetes': 'የስኳር በሽታ',
    'diabetes_type': 'የስኳር በሽታ አይነት',
    'latest_hba1c': 'የቅርብ HbA1c',
    'hypertension': 'የደም ግፊት',
    'high_cholesterol': 'ከፍተኛ ኮሌስትሮል',
    'profile_updated_successfully': 'መገለጫ በተሳካ ሁኔታ ተዘምኗል',
    'profile_load_failed': 'መገለጫን መጫን አልተሳካም',
    'profile_update_failed': 'መገለጫን ማዘመን አልተሳካም',

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
    'meal': 'ምግብ',
    'food_details_unavailable': 'የምግብ ዝርዝር አልተገኘም',
    'review_meal_guidance': 'የምግብ መመሪያን ይመልከቱ',
    'edit_portion': 'መጠኑን ያስተካክሉ',
    'suggest_alternatives': 'አማራጮችን ጠቁም',
    'add_anyway': 'እንደዚሁ ጨምር',
    'suggested_alternatives': 'የተጠቆሙ አማራጮች',
    'alternative_lower_salt':
      'ጨው ለመቀነስ: ብዙ ጨው ካለባቸው ወጦች ጋር የሚበላውን እንጀራ ያነሱ።',
    'alternative_lower_carb':
      'ካርቦሃይድሬት ለመቀነስ: አትክልቶችን፣ ጥራጥሬዎችን እና አነስ ያሉ የእህል መጠኖችን ይምረጡ።',
    'alternative_higher_fiber':
      'ፋይበር ለመጨመር: ጎመን፣ ካቦጅ፣ ቃሌ ወይም ባቄላ ይጨምሩ።',
    'meal_type_label': 'የምግብ አይነት',
    'analyzing_food': 'ምግብዎን በመተንተን ላይ...',
    'add_missing_foods_or_ingredients': 'የጎደሉ ምግቦች ወይም ንጥረ ነገሮችን ጨምር',
    'search_missing_food': 'የጎደለ ምግብ ፈልግ',
    'search_missing_food_desc':
      'ሙሉ ዝርዝሩን ከመጫን ይልቅ ምግቡን ይፈልጉ።',
    'search_extra_ingredient': 'ተጨማሪ ንጥረ ነገር ፈልግ',
    'search_extra_ingredient_desc':
      'ዝርዝር ሳይንቀሳቀሱ የጎደለውን ብቻ ይጨምሩ።',
    'add_food_image': 'የምግብ ምስል ጨምር',
    'camera': 'ካሜራ',
    'gallery': 'ጋለሪ',
    'no_analysis_result_to_save': 'ለማስቀመጥ የትንተና ውጤት የለም',
    'no_foods_found_to_save':
      'ምንም ምግብ አልተገኘም። ከውጤቶቹ በታች ያሉትን የፍለጋ መቆጣጠሪያዎች ተጠቅመው ምግቦችን ያክሉ።',
    'meal_saved': 'ምግቡ ተመዝግቧል!',
    'calories_logged': 'ካሎሪ ተመዝግቧል።',
    'no_food_items_detected': 'ምንም የምግብ አይነት አልተገኘም። ሌላ ፎቶ ይሞክሩ።',
    'total_estimated_calories': 'ጠቅላላ የተገመተ ካሎሪ',
    'detected_foods': 'የተገኙ ምግቦች',
    'detected_item': 'የተገኘ እቃ',
    'detected_items': 'የተገኙ እቃዎች',
    'not_in_database_choose_correct_food':
      'በመረጃ ቋቱ ውስጥ የለም - ትክክለኛውን ምግብ ይምረጡ',
    'change_detected_food': 'የተገኘውን ምግብ ቀይር',
    'select_correct_food': 'ትክክለኛውን ምግብ ይምረጡ',
    'meal_guidance': 'የምግብ መመሪያ',
    'sodium': 'ሶዲየም',
    'saturated_fat': 'ሳቹሬትድ ስብ',
    'todays_sodium': 'የዛሬ ሶዲየም',
    'used': 'ተጠቅመዋል',
    'add_a_food_image': 'የምግብ ምስል ያክሉ',
    'analysis_complete': 'ትንተናው ተጠናቋል',
    'save_to_history': 'ወደ ታሪክ አስቀምጥ',
    'total': 'ጠቅላላ',
    'search_food_items': 'የምግብ እቃዎችን ፈልግ',
    'search_foods_min_query': 'ምግቦችን ለመፈለግ ቢያንስ 2 ፊደላት ያስገቡ።',
    'no_matching_foods_found': 'ተመሳሳይ ምግቦች አልተገኙም።',
    'search_foods_failed': 'ምግቦችን መፈለግ አልተሳካም። እንደገና ይሞክሩ።',
    'search_extra_ingredients': 'ተጨማሪ ንጥረ ነገሮችን ፈልግ',
    'search_ingredients_min_query': 'ንጥረ ነገሮችን ለመፈለግ ቢያንስ 2 ፊደላት ያስገቡ።',
    'no_matching_ingredients_found': 'ተመሳሳይ ንጥረ ነገሮች አልተገኙም።',
    'search_ingredients_failed':
      'ንጥረ ነገሮችን መፈለግ አልተሳካም። እንደገና ይሞክሩ።',
    'nutrition_disclaimer':
      'እነዚህ የ2026 ADA/AHA/የኢትዮጵያ NCD መመሪያዎችን መሰረት ያደረጉ አጠቃላይ የአመጋገብ ግቦች ናቸው። የህክምና ምክር አይደሉም፤ ሁልጊዜ ሀኪምዎን ያማክሩ።',
    'meal_warning_saturated_fat': 'የተገመተው ሳቹሬትድ ስብ የዛሬውን ግብ ይበልጣል።',
    'meal_warning_sodium': 'የተገመተው ሶዲየም የዛሬውን ግብ ይበልጣል።',
    'meal_warning_high_carbs': 'ይህ ምግብ ለአንድ ጊዜ መመገቢያ ከፍተኛ ካርቦሃይድሬት አለው።',
    'meal_warning_low_fiber': 'በዚህ ምግብ ውስጥ ፋይበር በጣም ዝቅተኛ ነው።',

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
    'history_load_failed': 'የምግብ ታሪክን መጫን አልተሳካም',

    // Statistics
    'statistics': 'ስታቲስቲክስ',
    'total_calories': 'ጠቅላላ ካሎሪዎች',
    'meals_logged': 'የተመዘገቡ ምግቦች',
    'avg_calories': 'አማካይ ካሎሪ',
    'days_tracked': 'የተከታተሉ ቀናት',
    'weekly_overview': 'ሳምንታዊ ማጠቃለያ',
    'no_data': 'ገና ምንም መረጃ የለም',
    'start_logging_stats': 'ስታቲስቲክስዎን ለማየት ምግቦችን መመዝገብ ይጀምሩ',

    // Education & Awareness
    'education_awareness': 'ትምህርት እና ግንዛቤ',
    'error_loading_content': 'ይዘት በመጫን ላይ ስህተት ተከስቷል',
    'no_education_content': 'ምንም የትምህርት ይዘት የለም',
    'error_loading_article': 'ጽሑፍ በመጫን ላይ ስህተት ተከስቷል',
    'article_not_found': 'ጽሑፍ አልተገኘም',

    // Leaderboard
    'leaderboard_load_failed': 'ሊደርቦርዱን መጫን አልተሳካም',
    'no_leaderboard_data': 'ምንም የሊደርቦርድ መረጃ የለም',
    'rankings': 'ደረጃዎች',
    'current': 'አሁን',
    'best': 'ምርጥ',
  };
}
