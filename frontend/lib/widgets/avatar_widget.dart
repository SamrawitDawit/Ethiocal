import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final double radius;
  final Color backgroundColor;
  final Color textColor;
  final bool useFruitAvatar;
  final String? variantSeed;

  const AvatarWidget({
    super.key,
    required this.name,
    this.radius = 24,
    this.backgroundColor = const Color(0xFF8BC34A),
    this.textColor = Colors.white,
    this.useFruitAvatar = false,
    this.variantSeed,
  });

  String _getInitials(String name) {
    return name
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();
  }

  int _avatarIndex(String seed) {
    return seed.hashCode.abs();
  }

  static const List<_FruitAvatarData> _fruitAvatars = [
    _FruitAvatarData('🍎', Color(0xFFE57373)),
    _FruitAvatarData('🍊', Color(0xFFFFB74D)),
    _FruitAvatarData('🍋', Color(0xFFFFF176)),
    _FruitAvatarData('🍐', Color(0xFFB4E05E)),
    _FruitAvatarData('🍇', Color(0xFF9575CD)),
    _FruitAvatarData('🍓', Color(0xFFF06292)),
    _FruitAvatarData('🍑', Color(0xFFFFA726)),
    _FruitAvatarData('🍒', Color(0xFFE53935)),
    _FruitAvatarData('🍉', Color(0xFF66BB6A)),
    _FruitAvatarData('🥝', Color(0xFF9CCC65)),
    _FruitAvatarData('🍍', Color(0xFFFFD54F)),
    _FruitAvatarData('🫐', Color(0xFF5C6BC0)),
  ];

  @override
  Widget build(BuildContext context) {
    if (useFruitAvatar) {
      final seed = variantSeed ?? name;
      final avatar = _fruitAvatars[_avatarIndex(seed) % _fruitAvatars.length];

      return CircleAvatar(
        radius: radius,
        backgroundColor: avatar.backgroundColor,
        child: Text(
          avatar.emoji,
          style: TextStyle(
            fontSize: radius * 0.95,
          ),
        ),
      );
    }

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

class _FruitAvatarData {
  final String emoji;
  final Color backgroundColor;

  const _FruitAvatarData(this.emoji, this.backgroundColor);
}
