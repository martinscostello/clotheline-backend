import 'package:flutter/material.dart';
import 'package:clotheline_core/clotheline_core.dart';

class PulseOverlay extends StatefulWidget {
  final List<WalkthroughTarget> targets;
  final VoidCallback onData;
  final VoidCallback onComplete;

  const PulseOverlay({
    super.key,
    required this.targets,
    required this.onData, 
    required this.onComplete,
  });

  @override
  State<PulseOverlay> createState() => _PulseOverlayState();
}

class _PulseOverlayState extends State<PulseOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentIndex = 0;
  Rect? _targetRect;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       duration: const Duration(seconds: 2), 
       vsync: this
    )..repeat();
    
    // Calculate first target position after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateTarget());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _calculateTarget() {
    if (_currentIndex >= widget.targets.length) {
      widget.onComplete();
      return;
    }

    final target = widget.targets[_currentIndex];
    final RenderBox? renderBox = target.key.currentContext?.findRenderObject() as RenderBox?;
    
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      setState(() {
        _targetRect = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
      });
    } else {
      // If target not found (e.g. off screen), skip or end
      _nextStep();
    }
  }

  void _nextStep() {
    if (_currentIndex < widget.targets.length - 1) {
      setState(() {
        _currentIndex++;
        _targetRect = null; // Clear to trigger recalc
      });
      // Small delay to allow UI to settle if we were moving stuff (optional, here we assume static page)
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateTarget());
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) return const SizedBox.shrink();

    final target = widget.targets[_currentIndex];

    return Scaffold( // Scaffold needed for Material/Theme context
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Hole-Punched Scrim (CustomPainter)
          Positioned.fill(
            child: GestureDetector(
              onTap: _nextStep, // Tap anywhere to advance
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
                painter: _HoleOverlayPainter(targetRect: _targetRect!),
              ),
            ),
          ),

          // 2. Pulse Animation Ring
          Positioned.fromRect(
            rect: _targetRect!.inflate(16), 
            child: IgnorePointer( // Don't block touches on the target itself
              child: AnimatedBuilder(
                animation: _controller,
                builder: (ctx, child) {
                  return CustomPaint(
                    painter: _PulsePainter(_controller.value),
                  );
                },
              ),
            ),
          ),

          // 3. Info Card (Smart Positioning)
          Positioned(
            top: _targetRect!.bottom > MediaQuery.of(context).size.height * 0.7 
                 ? _targetRect!.top - 180 
                 : _targetRect!.bottom + 40,
            left: 20,
            right: 20,
            child: SafeArea( // Ensure within bounds
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      target.title,
                      style: const TextStyle(
                        color: Color(0xFF0EA5E9),
                        fontSize: 28, // Larger
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(blurRadius: 12, color: Colors.black, offset: Offset(0, 2))],
                        fontFamily: 'Roboto', // Or app theme font
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      target.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _nextStep,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))
                            ]
                          ),
                          child: const Text(
                            "NEXT", 
                            style: TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2
                            )
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoleOverlayPainter extends CustomPainter {
  final Rect targetRect;

  _HoleOverlayPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Create hole
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(12)));
    
    // Combine (Difference)
    final clipPath = Path.combine(PathOperation.difference, path, holePath);

    canvas.drawPath(
      clipPath, 
      Paint()..color = Colors.black.withValues(alpha: 0.85) // Darker background (85%)
    );
  }

  @override
  bool shouldRepaint(covariant _HoleOverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}

class _PulsePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _PulsePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Beaming Color: 0EA5E9
    const color = Color(0xFF0EA5E9);
    
    // Multiple ripples
    for (int i = 0; i < 3; i++) {
        final shift = (progress + (i * 0.3)) % 1.0;
        final radius = (size.width / 2) * shift;
        // Fade out as it expands
        final opacity = (1.0 - shift) * (1.0 - shift); 
        
        final paint = Paint()
          ..color = color.withValues(alpha: opacity * 0.8) // [FIX] .withValues
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * opacity
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
          
        canvas.drawCircle(center, radius, paint);
    }
    
    // Glowing Core Border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(12)), 
      borderPaint
    );
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) => true; // [FIX] Force repaint for animation
}
