import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/health_condition_model.dart';

class HealthConditionCard extends StatelessWidget {
  final HealthCondition condition;
  final VoidCallback onTap;

  const HealthConditionCard({
    super.key,
    required this.condition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: condition.isSelected ? AppColors.primaryGreen : AppColors.cardFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: condition.isSelected
                ? AppColors.primaryGreen
                : AppColors.inputBorder,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: condition.isSelected
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.inputFill,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                _getIconForCondition(condition.conditionName),
                color: condition.isSelected
                    ? Colors.white
                    : AppColors.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    condition.conditionName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: condition.isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Restricted: ${condition.restrictedNutrients}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: condition.isSelected
                          ? Colors.white.withOpacity(0.8)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: condition.isSelected
                    ? Colors.white
                    : Colors.transparent,
                border: Border.all(
                  color: condition.isSelected
                      ? Colors.white
                      : AppColors.inputBorder,
                  width: 2,
                ),
              ),
              child: condition.isSelected
                  ? const Icon(
                      Icons.check,
                      color: AppColors.primaryGreen,
                      size: 16,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCondition(String conditionName) {
    switch (conditionName.toLowerCase()) {
      case 'hypertension':
        return Icons.favorite;
      case 'diabetes':
        return Icons.local_hospital;
      case 'cholestrol':
        return Icons.monitor_heart;
      default:
        return Icons.medical_services;
    }
  }
}
