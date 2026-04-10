/// Food recognition models for AI-powered food detection
///
/// These models represent the response from the /api/v1/food/recognize endpoint
/// which uses YOLOv8 instance segmentation to detect foods in images.

import 'food_model.dart';

/// Bounding box coordinates for a detected food item
class BoundingBox {
  final double x1; // Top-left x coordinate
  final double y1; // Top-left y coordinate
  final double x2; // Bottom-right x coordinate
  final double y2; // Bottom-right y coordinate
  final double width;
  final double height;

  BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x1: (json['x1'] as num).toDouble(),
      y1: (json['y1'] as num).toDouble(),
      x2: (json['x2'] as num).toDouble(),
      y2: (json['y2'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        'width': width,
        'height': height,
      };
}

/// Segmentation mask data for a detected food item
class SegmentationMask {
  final List<List<double>> polygon; // List of [x, y] coordinate pairs
  final double? area; // Area of the mask in pixels

  SegmentationMask({
    required this.polygon,
    this.area,
  });

  factory SegmentationMask.fromJson(Map<String, dynamic> json) {
    final polygonData = json['polygon'] as List<dynamic>;
    final polygon = polygonData.map((point) {
      final p = point as List<dynamic>;
      return [
        (p[0] as num).toDouble(),
        (p[1] as num).toDouble(),
      ];
    }).toList();

    return SegmentationMask(
      polygon: polygon,
      area: json['area'] != null ? (json['area'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'polygon': polygon,
        'area': area,
      };
}

/// AI model prediction for a single food item in an image
class FoodRecognitionResult {
  final String label;
  final double confidence;
  final BoundingBox? boundingBox;
  final SegmentationMask? mask;
  final FoodItem? foodItem; // Matched DB entry, if found
  final double? portionGrams; // Estimated portion size in grams
  final double? estimatedCalories; // Calculated calories based on portion
  final String? estimationMethod; // 'mask_area' or 'standard_serving'

  FoodRecognitionResult({
    required this.label,
    required this.confidence,
    this.boundingBox,
    this.mask,
    this.foodItem,
    this.portionGrams,
    this.estimatedCalories,
    this.estimationMethod,
  });

  factory FoodRecognitionResult.fromJson(Map<String, dynamic> json) {
    return FoodRecognitionResult(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox: json['bounding_box'] != null
          ? BoundingBox.fromJson(json['bounding_box'])
          : null,
      mask:
          json['mask'] != null ? SegmentationMask.fromJson(json['mask']) : null,
      foodItem: json['food_item'] != null
          ? FoodItem.fromJson(json['food_item'])
          : null,
      portionGrams: json['portion_grams'] != null
          ? (json['portion_grams'] as num).toDouble()
          : null,
      estimatedCalories: json['estimated_calories'] != null
          ? (json['estimated_calories'] as num).toDouble()
          : null,
      estimationMethod: json['estimation_method'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'bounding_box': boundingBox?.toJson(),
        'mask': mask?.toJson(),
        'food_item': foodItem != null
            ? {
                'id': foodItem!.id,
                'name': foodItem!.name,
              }
            : null,
        'portion_grams': portionGrams,
        'estimated_calories': estimatedCalories,
        'estimation_method': estimationMethod,
      };

  /// Get confidence as percentage string
  String get confidencePercentage =>
      '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get display name (use food item name if matched, otherwise label)
  String get displayName => foodItem?.name ?? label;

  /// Get Amharic name if available
  String? get displayNameAmharic => foodItem?.nameAmharic;

  /// Get calories display string
  String get caloriesDisplay {
    if (estimatedCalories != null) {
      return '${estimatedCalories!.toStringAsFixed(0)} kcal';
    }
    return 'N/A';
  }

  /// Get portion display string
  String get portionDisplay {
    if (portionGrams != null) {
      return '${portionGrams!.toStringAsFixed(0)}g';
    }
    return 'N/A';
  }
}

/// Top-level response from the food recognition endpoint
class FoodRecognitionResponse {
  final List<FoodRecognitionResult> predictions;
  final String imageUrl;
  final int? imageWidth;
  final int? imageHeight;

  FoodRecognitionResponse({
    required this.predictions,
    required this.imageUrl,
    this.imageWidth,
    this.imageHeight,
  });

  factory FoodRecognitionResponse.fromJson(Map<String, dynamic> json) {
    final predictionsData = json['predictions'] as List<dynamic>;
    final predictions = predictionsData
        .map((p) => FoodRecognitionResult.fromJson(p as Map<String, dynamic>))
        .toList();

    return FoodRecognitionResponse(
      predictions: predictions,
      imageUrl: json['image_url'] as String,
      imageWidth: json['image_width'] as int?,
      imageHeight: json['image_height'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'predictions': predictions.map((p) => p.toJson()).toList(),
        'image_url': imageUrl,
        'image_width': imageWidth,
        'image_height': imageHeight,
      };

  /// Get total estimated calories across all predictions
  double get totalCalories {
    return predictions
        .where((p) => p.estimatedCalories != null)
        .fold(0.0, (sum, p) => sum + p.estimatedCalories!);
  }

  /// Check if any predictions were found
  bool get hasPredictions => predictions.isNotEmpty;

  /// Get number of detected food items
  int get count => predictions.length;
}
