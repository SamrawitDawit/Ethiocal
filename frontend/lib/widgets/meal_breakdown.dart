import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/language_provider.dart';

class MealBreakdown extends StatelessWidget {
  final Map<String, dynamic>? mealBreakdown;
  final bool isHistorical;

  const MealBreakdown({
    super.key,
    this.mealBreakdown,
    this.isHistorical = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mealBreakdown == null) return const SizedBox.shrink();

    final lang = context.watch<LanguageProvider>();

    final mealTypes = [
      {
        'type': 'breakfast',
        'icon': Icons.breakfast_dining,
        'label': lang.t('breakfast')
      },
      {'type': 'lunch', 'icon': Icons.lunch_dining, 'label': lang.t('lunch')},
      {
        'type': 'dinner',
        'icon': Icons.dinner_dining,
        'label': lang.t('dinner')
      },
      {'type': 'snack', 'icon': Icons.cookie, 'label': lang.t('snack')},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.t('meal_breakdown'),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 110, 
              ),
          itemCount: mealTypes.length,
              itemBuilder: (context, index) {
                final mealType = mealTypes[index];
                final data =
                    mealBreakdown![mealType['type']] as Map<String, dynamic>? ??
                        {'calories': 0, 'count': 0};
                final calories = data['calories'] as int;
                final count = data['count'] as int;

                return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: calories > 0
                      ? AppColors.primaryGreen.withOpacity(0.3)
                      : AppColors.inputBorder,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        mealType['icon'] as IconData,
                        color: calories > 0
                            ? AppColors.primaryGreen
                            : AppColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mealType['label'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$calories kcal',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: calories > 0
                          ? AppColors.primaryGreen
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      lang.isAmharic
                          ? '$count ${lang.t('meal')}'
                          : '$count meal${count > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            );
              },
            );
          },
        ),
      ],
    );
  }
}
