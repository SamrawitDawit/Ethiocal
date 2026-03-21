import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class CustomSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final Function(double) onChanged;
  final String unit;
  final bool showValue;

  const CustomSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.unit,
    this.showValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showValue)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardFill,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${value.toInt()} $unit',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        if (showValue) const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primaryGreen,
            inactiveTrackColor: AppColors.inputBorder,
            thumbColor: AppColors.primaryGreen,
            overlayColor: AppColors.primaryGreen.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
            trackHeight: 6,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
