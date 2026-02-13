import 'package:flutter/material.dart';

class WashingMachineLogo extends StatelessWidget {
  final double size;

  const WashingMachineLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700), // Yellow machine body
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Control Panel
          Positioned(
            top: size * 0.1,
            left: size * 0.1,
            right: size * 0.1,
            height: size * 0.15,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(size * 0.05),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(backgroundColor: Colors.white, radius: size * 0.03),
                  CircleAvatar(backgroundColor: Colors.white, radius: size * 0.03),
                  Container(width: size * 0.2, height: size * 0.08, color: Colors.black26),
                ],
              ),
            ),
          ),
          // Door Border
          Container(
            width: size * 0.6,
            height: size * 0.6,
            margin: EdgeInsets.only(top: size * 0.15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: size * 0.05),
              color: Colors.grey[800],
            ),
          ),
          // Door Glass (Blue gradient)
          Container(
            width: size * 0.45,
            height: size * 0.45,
            margin: EdgeInsets.only(top: size * 0.15),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                center: Alignment(-0.3, -0.3),
              ),
            ),
          ),
          // Reflection
          Positioned(
            top: size * 0.35,
            right: size * 0.35,
            child: Container(
              width: size * 0.1,
              height: size * 0.1,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
