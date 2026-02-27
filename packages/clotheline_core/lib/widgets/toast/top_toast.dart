import 'package:flutter/material.dart';


enum ToastType { success, error, info, warning }

class TopToast extends StatelessWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const TopToast({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color bgColor;
    Color iconColor;
    IconData icon;

    switch (type) {
      case ToastType.success:
        bgColor = Colors.green.withValues(alpha: 0.9);
        iconColor = Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case ToastType.error:
        bgColor = Colors.redAccent.withValues(alpha: 0.9);
        iconColor = Colors.white;
        icon = Icons.error_outline;
        break;
      case ToastType.warning:
        bgColor = Colors.orange.withValues(alpha: 0.9);
        iconColor = Colors.white;
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.info:
        bgColor = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF333333).withValues(alpha: 0.9);
        iconColor = isDark ? Colors.black : Colors.white;
        icon = Icons.info_outline;
        break;
    }

    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close, color: iconColor.withValues(alpha: 0.7), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
