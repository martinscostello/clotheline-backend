import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/LaundryGlassBackground.dart';
import '../../../../widgets/glass/UnifiedGlassHeader.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../services/review_service.dart';
import '../../../../services/store_service.dart';
import '../../../../widgets/custom_cached_image.dart';

class SubmitReviewScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String? productImageUrl; // Added
  final String orderId;

  const SubmitReviewScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.orderId,
  });

  @override
  State<SubmitReviewScreen> createState() => _SubmitReviewScreenState();
}

class _SubmitReviewScreenState extends State<SubmitReviewScreen> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;
  String? _fetchedImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchedImageUrl = widget.productImageUrl;
    if (_fetchedImageUrl == null || _fetchedImageUrl!.isEmpty) {
       Future.microtask(() => _fetchProductImage());
    }
  }

  Future<void> _fetchProductImage() async {
    try {
      final storeService = Provider.of<StoreService>(context, listen: false);
      
      // 1. Try local list
      try {
        final product = storeService.products.firstWhere((p) => p.id == widget.productId);
        if (mounted) {
          setState(() {
            _fetchedImageUrl = product.imagePath;
          });
          return;
        }
      } catch (_) {}

      // 2. Fetch from API if not found or list empty
      await storeService.fetchProducts();
      
      try {
        final product = storeService.products.firstWhere((p) => p.id == widget.productId);
        if (mounted) {
          setState(() {
            _fetchedImageUrl = product.imagePath;
          });
        }
      } catch (e) {
        debugPrint("Could not find product for image even after fetch: $e");
      }
    } catch (e) {
      debugPrint("Error fetching product image: $e");
    }
  }

  Future<void> _pickImage() async {
    if (_images.length >= 5) {
      ToastUtils.show(context, "Maximum 5 images allowed", type: ToastType.warning);
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Compression
    );

    if (image != null) {
      setState(() {
        _images.add(File(image.path));
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (_rating <= 3 && _commentController.text.trim().isEmpty) {
      ToastUtils.show(context, "Please provide a comment for ratings of 3 stars or less", type: ToastType.warning);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final reviewService = Provider.of<ReviewService>(context, listen: false);
      final result = await reviewService.submitReview(
        productId: widget.productId,
        orderId: widget.orderId,
        rating: _rating,
        comment: _commentController.text.trim(),
        images: _images,
      );

      if (context.mounted) {
        if (result['success']) {
          ToastUtils.show(context, result['message'], type: ToastType.success);
          Navigator.pop(context);
        } else {
          ToastUtils.show(context, result['message'], type: ToastType.error);
        }
      }
    } catch (e) {
      if (context.mounted) ToastUtils.show(context, "An error occurred: $e", type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? Colors.white.withOpacity(0.05) : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: LaundryGlassBackground(
        child: Column(
          children: [
            UnifiedGlassHeader(
              isDark: isDark,
              title: const Text("Write a Review", style: TextStyle(fontWeight: FontWeight.bold)),
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Product Details Card
                    _buildCard(
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CustomCachedImage(
                              imageUrl: _fetchedImageUrl ?? '',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              widget.productName,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Rating Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Overall Rating",
                            style: TextStyle(color: textColor.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return GestureDetector(
                                onTap: () => setState(() => _rating = index + 1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    index < _rating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 44,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Feedback Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Feedback",
                            style: TextStyle(color: textColor.withOpacity(0.7), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _commentController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: "Tell others about your experience...",
                              hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.05),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: TextStyle(color: textColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. Photos Card
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Add Photos (Max 5)",
                            style: TextStyle(color: textColor.withOpacity(0.7), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _images.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _images.length) {
                                  return GestureDetector(
                                    onTap: _pickImage,
                                    child: _DottedPlaceHolder(),
                                  );
                                }
                                return Stack(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: FileImage(_images[index]),
                                          fit: BoxFit.cover,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 16,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 5,
                          shadowColor: AppTheme.primaryColor.withOpacity(0.5),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "SUBMIT REVIEW",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class _DottedPlaceHolder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3);
    final iconColor = isDark ? Colors.white70 : Colors.black87;

    return CustomPaint(
      painter: _DottedPainter(color: color),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Icon(Icons.add, color: iconColor, size: 30),
      ),
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  _DottedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ));
    
    // Simple dash logic
    const dashWidth = 6;
    const dashSpace = 3;
    double distance = 0;
    
    for (final pathMetric in path.computeRemainingMetric()) {
      while (distance < pathMetric.length) {
        canvas.drawPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

extension PathMetricsExtension on Path {
  Iterable<PathMetric> computeRemainingMetric() {
    return computeMetrics();
  }
}
