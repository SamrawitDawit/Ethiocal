import 'package:flutter/material.dart';

class BottomResultCard extends StatelessWidget {
  final Widget child;

  const BottomResultCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: child,
    );
  }
}