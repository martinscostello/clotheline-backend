import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomCachedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final bool showBorder;
  final Color borderColor;
  final Widget? errorWidget;

  const CustomCachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 8.0,
    this.showBorder = false,
    this.borderColor = Colors.grey,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder(context);
    }

    Widget imageWidget;

    if (imageUrl.startsWith('http') || imageUrl.startsWith('https')) {
      imageWidget = CachedNetworkImage(
        // Optimize: Downsample images in memory to max 1000px.
        // This prevents 12MP photos from consuming 50MB RAM each.
        memCacheWidth: 1000, 
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildSkeleton(context),
        errorWidget: (context, url, error) {
           // On error, show skeleton or custom error widget
           // NEVER show a "default laundry photo" here.
           // If errorWidget is provided (e.g. for user avatar), use it.
           // Otherwise, stay as skeleton which is better than wrong data.
           return errorWidget ?? _buildErrorState(context);
        },
        fadeInDuration: const Duration(milliseconds: 300),
      );
    } else if (imageUrl.startsWith('assets/')) {
       imageWidget = Image.asset(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorState(context),
       );
    } else {
       // Assume local file path
       File file = File(imageUrl);
       if (file.existsSync()) {
          imageWidget = Image.file(
             file,
             width: width,
             height: height,
             fit: fit,
             errorBuilder: (context, error, stackTrace) => _buildErrorState(context),
          );
       } else {
          imageWidget = _buildErrorState(context);
       }
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder ? Border.all(color: borderColor, width: 1) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      color: isDark ? Colors.white10 : Colors.grey.shade300,
    );
  }
  
  Widget _buildPlaceholder(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: width,
        height: height,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
        child: Icon(Icons.image_not_supported, color: isDark ? Colors.white24 : Colors.grey, size: (width ?? 40) * 0.4),
      );
  }

  Widget _buildErrorState(BuildContext context) {
     // If we fail, just show a muted icon. Don't mislead the user with a stock photo.
     return _buildPlaceholder(context);
  }
}
