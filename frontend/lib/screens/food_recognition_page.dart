import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../constants/app_constants.dart';
import '../widgets/app_background.dart';

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
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isAnalyzing = true;
        });
        // Simulate analysis delay
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _isAnalyzing = false;
        });
      }
    } catch (e) {
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
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isAnalyzing = true;
        });
        // Simulate analysis delay
        await Future.delayed(const Duration(seconds: 2));
        setState(() {
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
                      'Label',
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
