import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_logo.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/intake_card.dart';
import '../widgets/quick_actions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime today = DateTime.now();
  List<DateTime> weekDates = [];
  int todayCalories = 0;
  int targetCalories = 2000;
  bool isLoading = true;
  String? errorMessage;
  Map<DateTime, Map<String, dynamic>>? historicalData;
  DateTime? selectedDate;
  bool isLoadingHistorical = false;
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? mealBreakdown;
  Map<String, dynamic>? nutrientBreakdown;

  @override
  void initState() {
    super.initState();
    _generateWeekDates();
    selectedDate = today; // Set today as selected by default
    _fetchDashboardData();
  }

  void _generateWeekDates() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    // Generate dates for current week + 4 weeks of past dates for scrolling
    weekDates = List.generate(35, (index) {
      return startOfWeek.subtract(Duration(days: 28 - index));
    });
    
    // Scroll to show current week initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Calculate position to show current week (days 28-34 in our list)
        const currentWeekStartIndex = 28;
        const itemWidth = 58.0; // 50 width + 8 padding
        const scrollOffset = currentWeekStartIndex * itemWidth;
        _scrollController.animateTo(
          scrollOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final dashboardData = await DashboardService.fetchUserDashboard();
      setState(() {
        targetCalories = dashboardData['dailyCalorieGoal'] ?? 2000;
        todayCalories = dashboardData['todayCalories'] ?? 0;
        mealBreakdown = dashboardData['mealBreakdown'] ?? {};
        nutrientBreakdown = dashboardData['nutrientBreakdown'] ?? {};
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load dashboard data';
      });
    }
  }

  Future<void> _refreshDashboard() async {
    await _fetchDashboardData();
  }

  Future<void> _onDateTapped(DateTime date) async {
    if (date.isAfter(today) && !_isSameDay(date, today)) {
      return; // Don't allow future dates
    }

    setState(() {
      selectedDate = date;
      isLoadingHistorical = true;
    });

    try {
      final data = await DashboardService.fetchCaloriesForDate(date);
      setState(() {
        historicalData ??= {};
        historicalData![date] = {
          ...data,
          'mealBreakdown': data['mealBreakdown'] ?? {},
          'nutrientBreakdown': data['nutrientBreakdown'] ?? {},
        };
        // Always set mealBreakdown and nutrientBreakdown for the selected date (today or historical)
        mealBreakdown = data['mealBreakdown'] ?? {};
        nutrientBreakdown = data['nutrientBreakdown'] ?? {};
        isLoadingHistorical = false;
      });
    } catch (e) {
      setState(() {
        isLoadingHistorical = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.clearTokens();
    if (mounted) {
      Navigator.pushReplacementNamed(context, RouteNames.landing);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      WeeklyCalendar(
                        weekDates: weekDates,
                        today: today,
                        selectedDate: selectedDate,
                        scrollController: _scrollController,
                        historicalData: historicalData,
                        onDateTapped: _onDateTapped,
                      ),
                      const SizedBox(height: 24),
                      IntakeCard(
                        todayCalories: todayCalories,
                        targetCalories: targetCalories,
                        isLoading: isLoading,
                        isLoadingHistorical: isLoadingHistorical,
                        selectedDate: selectedDate,
                        today: today,
                        mealBreakdown: mealBreakdown,
                        nutrientBreakdown: nutrientBreakdown,
                        historicalData: historicalData,
                        onBackPressed: () {
                          setState(() {
                            selectedDate = null;
                          });
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh,
                                    color: AppColors.error),
                                onPressed: _refreshDashboard,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const QuickActions(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AppLogo(imageHeight: 28, fontSize: 18),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.school, color: AppColors.textSecondary),
                onPressed: () {
                  Navigator.pushNamed(context, RouteNames.educationList);
                },
                tooltip: 'Education & Awareness',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                onPressed: _logout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
