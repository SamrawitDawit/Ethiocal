import 'package:flutter/material.dart';

/// Painter for drawing bounding boxes around detected food items
class BoundingBoxPainter extends CustomPainter {
  final List<BoundingBoxData> boxes;
  final Size imageSize;
  final Size displaySize;

  BoundingBoxPainter({
    required this.boxes,
    required this.imageSize,
    required this.displaySize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      final paint = Paint()
        ..color = box.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      // Scale coordinates from image size to display size
      final scaleX = displaySize.width / imageSize.width;
      final scaleY = displaySize.height / imageSize.height;

      final rect = Rect.fromLTRB(
        box.x1 * scaleX,
        box.y1 * scaleY,
        box.x2 * scaleX,
        box.y2 * scaleY,
      );

      // Draw rounded rectangle
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        paint,
      );

      // Draw label background
      if (box.label != null) {
        final labelPaint = Paint()
          ..color = box.color.withOpacity(0.9)
          ..style = PaintingStyle.fill;

        final textSpan = TextSpan(
          text: box.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final labelRect = Rect.fromLTWH(
          rect.left,
          rect.top - textPainter.height - 6,
          textPainter.width + 12,
          textPainter.height + 6,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
          labelPaint,
        );

        textPainter.paint(
          canvas,
          Offset(labelRect.left + 6, labelRect.top + 3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    return boxes != oldDelegate.boxes ||
        imageSize != oldDelegate.imageSize ||
        displaySize != oldDelegate.displaySize;
  }
}

/// Data class for bounding box information
class BoundingBoxData {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String? label;
  final Color color;

  BoundingBoxData({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.label,
    this.color = const Color(0xFF2E7D32),
  });
}

/// Painter for drawing segmentation mask polygons
class MaskPainter extends CustomPainter {
  final List<MaskData> masks;
  final Size imageSize;
  final Size displaySize;

  MaskPainter({
    required this.masks,
    required this.imageSize,
    required this.displaySize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final mask in masks) {
      if (mask.polygon.isEmpty) continue;

      // Scale coordinates from image size to display size
      final scaleX = displaySize.width / imageSize.width;
      final scaleY = displaySize.height / imageSize.height;

      final path = Path();
      bool isFirst = true;

      for (final point in mask.polygon) {
        final x = point[0] * scaleX;
        final y = point[1] * scaleY;

        if (isFirst) {
          path.moveTo(x, y);
          isFirst = false;
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      // Draw filled mask with transparency
      final fillPaint = Paint()
        ..color = mask.color.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Draw mask outline
      final strokePaint = Paint()
        ..color = mask.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(MaskPainter oldDelegate) {
    return masks != oldDelegate.masks ||
        imageSize != oldDelegate.imageSize ||
        displaySize != oldDelegate.displaySize;
  }
}

/// Data class for mask information
class MaskData {
  final List<List<double>> polygon;
  final Color color;

  MaskData({
    required this.polygon,
    this.color = const Color(0xFF2E7D32),
  });
}

/// Combined overlay widget that draws both boxes and masks
class FoodDetectionOverlay extends StatelessWidget {
  final List<BoundingBoxData> boxes;
  final List<MaskData> masks;
  final Size imageSize;

  const FoodDetectionOverlay({
    super.key,
    required this.boxes,
    required this.masks,
    required this.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            // Draw masks first (below boxes)
            if (masks.isNotEmpty)
              CustomPaint(
                size: displaySize,
                painter: MaskPainter(
                  masks: masks,
                  imageSize: imageSize,
                  displaySize: displaySize,
                ),
              ),
            // Draw bounding boxes on top
            if (boxes.isNotEmpty)
              CustomPaint(
                size: displaySize,
                painter: BoundingBoxPainter(
                  boxes: boxes,
                  imageSize: imageSize,
                  displaySize: displaySize,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Color palette for multiple food detections
class DetectionColors {
  static const List<Color> palette = [
    Color(0xFF2E7D32), // Green
    Color(0xFF1976D2), // Blue
    Color(0xFFD32F2F), // Red
    Color(0xFFF57C00), // Orange
    Color(0xFF7B1FA2), // Purple
    Color(0xFF00796B), // Teal
    Color(0xFFC2185B), // Pink
    Color(0xFF5D4037), // Brown
  ];

  static Color getColor(int index) {
    return palette[index % palette.length];
  }

  /// Get consistent color for a food name
  /// Same food names will always get the same color
  static Color getColorForFood(String foodName) {
    int hash = foodName.hashCode.abs();
    return palette[hash % palette.length];
  }
}
