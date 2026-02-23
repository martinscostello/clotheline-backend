import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../glass/GlassContainer.dart';

class SplitCheckoutModal extends StatelessWidget {
  final List<String> modes;
  final Function(String) onSelectMode;

  const SplitCheckoutModal({
    super.key,
    required this.modes,
    required this.onSelectMode,
  });

  String _getModeLabel(String mode) {
    switch (mode) {
      case 'logistics': return 'Laundry & Products';
      case 'deployment': return 'Home & Office Cleaning';
      case 'bulky': return 'Rug Cleaning';
      default: return mode;
    }
  }

  IconData _getModeIcon(String mode) {
    switch (mode) {
      case 'logistics': return Icons.local_laundry_service;
      case 'deployment': return Icons.house;
      case 'bulky': return Icons.water_drop;
      default: return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: GlassContainer(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.splitscreen, size: 50, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                "Separate Bookings Required",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "These services require separate scheduling and logistics. Please select which one to book first. Your other items will remain in the cart.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ...modes.map((mode) => Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => onSelectMode(mode),
                    icon: Icon(_getModeIcon(mode)),
                    label: Text(_getModeLabel(mode)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
