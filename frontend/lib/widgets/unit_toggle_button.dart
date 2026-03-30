import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class UnitToggleButton extends StatelessWidget {
  final String option1;
  final String option2;
  final String selectedOption;
  final Function(String) onOptionSelected;

  const UnitToggleButton({
    super.key,
    required this.option1,
    required this.option2,
    required this.selectedOption,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: GestureDetector(
              onTap: () => onOptionSelected(option1),
              child: Container(
                height: 36,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: selectedOption == option1
                      ? AppColors.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    option1,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selectedOption == option1
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            fit: FlexFit.tight,
            child: GestureDetector(
              onTap: () => onOptionSelected(option2),
              child: Container(
                height: 36,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: selectedOption == option2
                      ? AppColors.primaryGreen
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    option2,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selectedOption == option2
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
