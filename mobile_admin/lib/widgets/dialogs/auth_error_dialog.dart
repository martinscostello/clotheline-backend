import 'package:flutter/material.dart';
import 'dart:ui';

class AuthErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String primaryButtonLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  const AuthErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.primaryButtonLabel = "Okay",
    this.onPrimaryPressed,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Caution Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFDE047).withValues(alpha: 0.2), // Yellow/Amber tint
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEAB308), size: 36),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 28),
              
              // Actions
              Row(
                children: [
                   if (secondaryButtonLabel != null)
                     Expanded(
                       child: TextButton(
                         onPressed: onSecondaryPressed ?? () => Navigator.pop(context),
                         style: TextButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 14),
                           foregroundColor: isDark ? Colors.white60 : Colors.black54,
                         ),
                         child: Text(secondaryButtonLabel!),
                       ),
                     ),
                   
                   if (secondaryButtonLabel != null)
                      const SizedBox(width: 12),

                   Expanded(
                     child: ElevatedButton(
                       onPressed: onPrimaryPressed ?? () => Navigator.pop(context),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF4A80F0),
                         foregroundColor: Colors.white,
                         elevation: 0,
                         padding: const EdgeInsets.symmetric(vertical: 14),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       child: Text(primaryButtonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                     ),
                   )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
