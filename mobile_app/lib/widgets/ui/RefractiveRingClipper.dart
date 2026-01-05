import 'package:flutter/material.dart';

class RefractiveRingClipper extends CustomClipper<Path> {
  final double strokeWidth;
  final double radius;

  RefractiveRingClipper({this.strokeWidth = 10, this.radius = 24});

  @override
  Path getClip(Size size) {
    final outerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final innerPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(strokeWidth, strokeWidth, size.width - 2 * strokeWidth, size.height - 2 * strokeWidth),
        Radius.circular(radius - strokeWidth > 0 ? radius - strokeWidth : 0),
      ));

    return Path.combine(PathOperation.difference, outerPath, innerPath);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
