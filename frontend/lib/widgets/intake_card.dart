import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../constants/app_constants.dart';
import 'meal_breakdown.dart';
import 'nutrient_breakdown.dart';

class IntakeCard extends StatelessWidget {
  final int todayCalories;
  final int targetCalories;
  final bool isLoading;
  final bool isLoadingHistorical;
  final DateTime? selectedDate;
  final DateTime today;
  final Map<String, dynamic>? mealBreakdown;
  final Map<String, dynamic>? nutrientBreakdown;
  final Map<DateTime, Map<String, dynamic>>? historicalData;
  final VoidCallback? onBackPressed;

  const IntakeCard({
    super.key,
    required this.todayCalories,
    required this.targetCalories,
    required this.isLoading,
    required this.isLoadingHistorical,
    this.selectedDate,
    required this.today,
    this.mealBreakdown,
    this.nutrientBreakdown,
    this.historicalData,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isShowingHistorical = selectedDate != null && !_isSameDay(selectedDate!, today);

    // LOADING HISTORICAL
    if (isLoadingHistorical) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    // HISTORICAL DATA VIEW
    if (isShowingHistorical && historicalData != null && historicalData!.containsKey(selectedDate!)) {
      final data = historicalData![selectedDate!]!;
      final calories = data['calories'] as int;
      final target = data['target'] as int;


      return Column(
        children: [
          _buildCircularProgress(calories, target),
          const SizedBox(height: 20),
          // NUTRIENT BREAKDOWN FOR HISTORICAL DATE
          if (historicalData != null && 
              historicalData!.containsKey(selectedDate!) &&
              historicalData![selectedDate!]!.containsKey('nutrientBreakdown'))
            NutrientBreakdown(
              nutrientBreakdown: historicalData![selectedDate!]!['nutrientBreakdown'] as Map<String, dynamic>,
              isHistorical: true,
            ),
          const SizedBox(height: 16),
          // MEAL BREAKDOWN FOR HISTORICAL DATE
          if (historicalData != null && 
              historicalData!.containsKey(selectedDate!) &&
              historicalData![selectedDate!]!.containsKey('mealBreakdown'))
            MealBreakdown(
              mealBreakdown: historicalData![selectedDate!]!['mealBreakdown'] as Map<String, dynamic>,
              isHistorical: true,
            ),
          const SizedBox(height: 16),
          if (onBackPressed != null) _buildBackButton(),
        ],
      );
    }

    // LOADING TODAY
    if (isLoading) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }


    return Column(
      children: [
        _buildCircularProgress(todayCalories, targetCalories),
        const SizedBox(height: 20),
        // NUTRIENT BREAKDOWN
        if (nutrientBreakdown != null) 
          NutrientBreakdown(nutrientBreakdown: nutrientBreakdown!),
        const SizedBox(height: 20),
        // MEAL BREAKDOWN
        if (mealBreakdown != null) 
          MealBreakdown(mealBreakdown: mealBreakdown!),
      ],
    );
  }

  Widget _buildCircularProgress(int calories, int target) {
    final isOverTarget = calories > target;
    final progress = (calories / target).clamp(0.0, 1.0);
    
    return CircularPercentIndicator(
      radius: 90,
      lineWidth: 12,
      percent: progress,
      animation: true,
      circularStrokeCap: CircularStrokeCap.round,
      backgroundColor: (isOverTarget ? AppColors.error : AppColors.primaryGreen).withOpacity(0.2),
      progressColor: isOverTarget ? AppColors.error : AppColors.primaryGreen,
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_fire_department, 
            color: isOverTarget ? AppColors.error : AppColors.primaryGreen, 
            size: 32
          ),
          const SizedBox(height: 6),
          Text(
            '$calories',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            'of $target',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieStats(int target, int remainingCalories) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '$target kcal',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              remainingCalories > 0 ? 'Remaining' : 'Over',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${remainingCalories.abs()} kcal',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: onBackPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryGreen),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, color: AppColors.primaryGreen, size: 16),
            const SizedBox(width: 4),
            Text(
              'Back to Today',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}
