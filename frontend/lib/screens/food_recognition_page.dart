import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../widgets/app_background.dart';

enum PlateGuideShape { circle, oval, rectangle }

class PlateGuidePainter extends CustomPainter {
  final PlateGuideShape shape;
  final Color color;

  PlateGuidePainter({required this.shape, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final guideWidth = size.width * 0.72;
    final guideHeight = size.height * 0.52;
    final guideRect = Rect.fromCenter(
      center: center,
      width: guideWidth,
      height: guideHeight,
    );

    switch (shape) {
      case PlateGuideShape.circle:
        final radius = guideRect.shortestSide / 2;
        canvas.drawCircle(center, radius, fillPaint);
        canvas.drawCircle(center, radius, strokePaint);
        break;
      case PlateGuideShape.oval:
        canvas.drawOval(guideRect, fillPaint);
        canvas.drawOval(guideRect, strokePaint);
        break;
      case PlateGuideShape.rectangle:
        const radius = Radius.circular(18);
        final rrect = RRect.fromRectAndRadius(guideRect, radius);
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant PlateGuidePainter oldDelegate) {
    return oldDelegate.shape != shape || oldDelegate.color != color;
  }
}

class CornerBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerSize;

  CornerBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final margin = strokeWidth / 2;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(margin, cornerSize + margin)
        ..lineTo(margin, margin)
        ..lineTo(cornerSize + margin, margin),
      paint,
    );

    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize - margin, margin)
        ..lineTo(size.width - margin, margin)
        ..lineTo(size.width - margin, cornerSize + margin),
      paint,
    );

    // Bottom-left corner
    canvas.drawPath(
      Path()
        ..moveTo(margin, size.height - cornerSize - margin)
        ..lineTo(margin, size.height - margin)
        ..lineTo(cornerSize + margin, size.height - margin),
      paint,
    );

    // Bottom-right corner
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerSize - margin, size.height - margin)
        ..lineTo(size.width - margin, size.height - margin)
        ..lineTo(size.width - margin, size.height - cornerSize - margin),
      paint,
    );
  }

  @override
  bool shouldRepaint(CornerBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerSize != cornerSize;
  }
}

class FoodRecognitionPage extends StatefulWidget {
  const FoodRecognitionPage({super.key});

  @override
  State<FoodRecognitionPage> createState() => _FoodRecognitionPageState();
}

class _FoodRecognitionPageState extends State<FoodRecognitionPage> {
  File? _selectedImage;
  bool _isAnalyzing = false;
  final ImagePicker _imagePicker = ImagePicker();
  PlateGuideShape _selectedPlateShape = PlateGuideShape.circle;
  List<Map<String, dynamic>> _predictions = [];
  String? _errorMessage;

  static const Map<PlateGuideShape, String> _shapeLabel = {
    PlateGuideShape.circle: 'Circle plate',
    PlateGuideShape.oval: 'Oval plate',
    PlateGuideShape.rectangle: 'Rectangle plate',
  };

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Food Image',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Camera option
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen.withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.primaryGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Camera',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Gallery option
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen.withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          color: AppColors.primaryGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gallery',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        setState(() {
          _selectedImage = imageFile;
          _errorMessage = null;
          _predictions = [];
        });
        await _analyzeImage(imageFile);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        setState(() {
          _selectedImage = imageFile;
          _errorMessage = null;
          _predictions = [];
        });
        await _analyzeImage(imageFile);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final url = Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.foodRecognizeEndpoint}');
      final request = http.MultipartRequest('POST', url)
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw Exception(
            'Recognition failed (${streamedResponse.statusCode}): $responseBody');
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final predictions = (decoded['predictions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _predictions = predictions;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Widget _buildPredictionCard(Map<String, dynamic> prediction) {
    final label = (prediction['label'] ?? 'Unknown').toString();
    final confidence = (prediction['confidence'] as num?)?.toDouble() ?? 0;
    final foodItem = prediction['food_item'] as Map<String, dynamic>?;
    final calories = foodItem?['calories'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (calories != null)
                  Text(
                    'Calories: $calories',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlateGuideSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.dinner_dining,
            size: 20,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 10),
          Text(
            'Plate guide',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<PlateGuideShape>(
              value: _selectedPlateShape,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              borderRadius: BorderRadius.circular(12),
              items: PlateGuideShape.values
                  .map(
                    (shape) => DropdownMenuItem<PlateGuideShape>(
                      value: shape,
                      child: Text(
                        _shapeLabel[shape]!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (shape) {
                if (shape == null) {
                  return;
                }
                setState(() {
                  _selectedPlateShape = shape;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Food Recognition',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Analyzing text
              if (_isAnalyzing)
                Text(
                  'Analysing your dish',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                )
              else if (_selectedImage == null)
                Text(
                  'Add a food image',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _buildPlateGuideSelector(),
              const SizedBox(height: 24),
              // Image frame with corner borders
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Main image container
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E8D8),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 80,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      // Corner borders overlay
                      Positioned.fill(
                        child: CustomPaint(
                          painter: CornerBorderPainter(
                            color: AppColors.primaryGreen,
                            strokeWidth: 4,
                            cornerSize: 32,
                          ),
                        ),
                      ),
                      // Dynamic plate guide overlay
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: PlateGuidePainter(
                              shape: _selectedPlateShape,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Guide: ${_shapeLabel[_selectedPlateShape]}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_predictions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) =>
                          _buildPredictionCard(_predictions[index]),
                    ),
                  ),
                ),
              if (_predictions.isNotEmpty) const SizedBox(height: 12),
              // Action button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Large add button
                    GestureDetector(
                      onTap: _showImageSourceOptions,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreen,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGreen.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
