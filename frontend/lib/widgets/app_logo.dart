import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppLogo extends StatelessWidget {
  final double imageHeight;
  final double fontSize;

  const AppLogo({
    super.key,
    this.imageHeight = 40,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/food_basket.png',
          height: imageHeight,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Text(
          'EthioCal',
          style: GoogleFonts.dancingScript(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryGreen,
          ),
        ),
      ],
    );
  }
}
