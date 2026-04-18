import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final double radius;
  final Color backgroundColor;
  final Color textColor;

  const AvatarWidget({
    super.key,
    required this.name,
    this.radius = 24,
    this.backgroundColor = const Color(0xFF8BC34A),
    this.textColor = Colors.white,
  });

  String _getInitials(String name) {
    return name
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.5,
        ),
      ),
    );
  }
}
