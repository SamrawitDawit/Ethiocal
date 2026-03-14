import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          // Large top-right blob
          Positioned(
            top: -60,
            right: -50,
            child: _blob(180, AppColors.blobGreen.withOpacity(0.18)),
          ),
          // Top-left yellow blob
          Positioned(
            top: 40,
            left: -60,
            child: _blob(140, AppColors.blobYellow.withOpacity(0.2)),
          ),
          // Mid-right blob
          Positioned(
            top: size.height * 0.35,
            right: -40,
            child: _blob(100, AppColors.blobGreen.withOpacity(0.15)),
          ),
          // Mid-left small blob
          Positioned(
            top: size.height * 0.5,
            left: -20,
            child: _blob(60, AppColors.lightGreen.withOpacity(0.15)),
          ),
          // Large bottom-left blob
          Positioned(
            bottom: 60,
            left: -70,
            child: _blob(180, AppColors.blobGreen.withOpacity(0.18)),
          ),
          // Bottom-right yellow blob
          Positioned(
            bottom: -50,
            right: -30,
            child: _blob(150, AppColors.blobYellow.withOpacity(0.18)),
          ),
          // Small accent near center-right
          Positioned(
            top: size.height * 0.65,
            right: 30,
            child: _blob(40, AppColors.lightGreen.withOpacity(0.12)),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
