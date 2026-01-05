import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ColorPickerSheet extends StatefulWidget {
  final String initialColor;
  final Function(String) onColorSelected;

  const ColorPickerSheet({super.key, required this.initialColor, required this.onColorSelected});

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late TextEditingController _hexController;
  late String _selectedColor;

  final List<String> _presets = [
    "0xFFFFFFFF", // White
    "0xFF000000", // Black
    "0xFF26A69A", // Primary (Teal)
    "0xFFFF9800", // Secondary (Orange)
    "0xFFE91E63", // Pink
    "0xFF2196F3", // Blue
    "0xFF9C27B0", // Purple
    "0xFFF44336", // Red
    "0xFF4CAF50", // Green
    "0xFFFFC107", // Amber
    "0xFF795548", // Brown
    "0xFF607D8B", // Blue Grey
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    // ensure hex format
    if (!_selectedColor.startsWith("0x")) {
      _selectedColor = "0xFFFFFFFF";
    }
    _hexController = TextEditingController(text: _selectedColor.replaceAll("0x", ""));
  }

  Color _getColorFromHex(String hex) {
    try {
      String cleanHex = hex.replaceAll("0x", "").replaceAll("#", "");
      if (cleanHex.length == 6) cleanHex = "FF$cleanHex";
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return Colors.white;
    }
  }

  void _onHexChanged(String val) {
    String hex = val.toUpperCase().replaceAll("#", "");
    if (hex.length == 6 || hex.length == 8) {
       setState(() {
         _selectedColor = "0x${hex.length == 6 ? "FF$hex" : hex}";
       });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Pick Color", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Preview & Input
          Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: _getColorFromHex(_selectedColor),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24)
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  controller: _hexController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Hex Code",
                    prefixText: "0x",
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
                  ),
                  onChanged: _onHexChanged,
                ),
              )
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Presets
          Wrap(
            spacing: 15,
            runSpacing: 15,
            children: _presets.map((colorHex) {
              final color = _getColorFromHex(colorHex);
              final isSelected = _selectedColor == colorHex;
              
              return GestureDetector(
                onTap: () {
                   setState(() {
                     _selectedColor = colorHex;
                     _hexController.text = colorHex.replaceAll("0x", "");
                   });
                },
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: [
                      if (isSelected) BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5)
                    ]
                  ),
                  child: isSelected ? const Icon(Icons.check, color: Colors.black54, size: 20) : null,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15)
              ),
              onPressed: () {
                widget.onColorSelected(_selectedColor);
                Navigator.pop(context);
              },
              child: const Text("Select Color", style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
