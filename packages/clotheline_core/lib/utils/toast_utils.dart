import 'package:flutter/material.dart';
import '../widgets/toast/top_toast.dart';
export '../widgets/toast/top_toast.dart';

class ToastUtils {
  static OverlayEntry? _overlayEntry;
  static bool _isVisible = false;

  static void show(BuildContext context, String message, {ToastType type = ToastType.info}) {
    if (_isVisible) {
      _removeToast();
    }

    final overlay = Overlay.of(context);
    
    // Create Animation Controller Logic Wrapper
    // Since we can't easily perform animations in a static method without a StatefulWidget wrapper,
    // we'll use a simple approach: Insert, wait, remove. 
    // Ideally, for animations, the Widget itself should handle entrance/exit animations 
    // or we wrap it in a StatefulWidget in the Overlay.
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _ToastAnimator(
        child: TopToast(
          message: message,
          type: type,
          onDismiss: _removeToast,
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
    _isVisible = true;

    // Auto dismiss
    Future.delayed(const Duration(seconds: 3), () {
      if (_isVisible) _removeToast();
    });
  }

  static void _removeToast() {
    if (_overlayEntry != null && _isVisible) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isVisible = false;
    }
  }
}

class _ToastAnimator extends StatefulWidget {
  final Widget child;
  const _ToastAnimator({required this.child});

  @override
  State<_ToastAnimator> createState() => _ToastAnimatorState();
}

class _ToastAnimatorState extends State<_ToastAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
