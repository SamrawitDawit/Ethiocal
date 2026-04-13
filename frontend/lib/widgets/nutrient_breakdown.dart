import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class NutrientBreakdown extends StatelessWidget {
  final Map<String, dynamic>? nutrientBreakdown;
  final bool isHistorical;

  const NutrientBreakdown({
    super.key,
    this.nutrientBreakdown,
    this.isHistorical = false,
  });

  @override
  Widget build(BuildContext context) {
    if (nutrientBreakdown == null) return const SizedBox.shrink();

    final protein = nutrientBreakdown!['totalProtein'] as double? ?? 0.0;
    final carbs = nutrientBreakdown!['totalCarbohydrates'] as double? ?? 0.0;
    final fat = nutrientBreakdown!['totalFat'] as double? ?? 0.0;
    final calories = nutrientBreakdown!['totalCalories'] as double? ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   'Nutrient Breakdown',
        //   style: GoogleFonts.poppins(
        //     fontSize: 16,
        //     fontWeight: FontWeight.w600,
        //     color: AppColors.textPrimary,
        //   ),
        // ),
        // const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNutrientItem(
                label: 'Protein',
                value: protein,
                unit: 'g',
                color: AppColors.primaryGreen,
              ),
              _buildNutrientItem(
                label: 'Carbs',
                value: carbs,
                unit: 'g',
                color: Colors.orange,
              ),
              _buildNutrientItem(
                label: 'Fat',
                value: fat,
                unit: 'g',
                color: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNutrientItem({
    required String label,
    required double value,
    required String unit,
    required Color color,
  }) {
    // Calculate progress percentage (assuming max values: protein 100g, carbs 300g, fat 100g)
    final maxValue = label == 'Carbs' ? 300.0 : 100.0;
    final progress = (value / maxValue).clamp(0.0, 1.0);
    
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: value > 0 ? AppColors.textSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
          ),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.inputBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              label == 'Protein' ? Colors.blue :
              label == 'Carbs' ? Colors.yellow : Colors.red
            ),
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value.toStringAsFixed(1),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: value > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
