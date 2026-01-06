import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'liquid_glass_container.dart';

/// A reusable Dropdown with:
/// - Button: Solid Card (Normal styling).
/// - Menu: Liquid Glass (Translucent + Blur).
/// - Animation: "Warp" / Bouncy Open Effect.
class LiquidGlassDropdown<T> extends StatefulWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isDark;

  const LiquidGlassDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.isDark,
  });

  @override
  State<LiquidGlassDropdown> createState() => _LiquidGlassDropdownState<T>();
}

class _LiquidGlassDropdownState<T> extends State<LiquidGlassDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    
    // Position menu:
    // Slightly overlap the button (top offset) or just below?
    // User wants "Warp" animation. Standard dropdowns usually appear right over or below.
    // Let's place it *just below* with a small gap, but animate it "warping" out.
    
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // 1. Transparent Closer
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
                child: Container(color: Colors.transparent),
              ),
            ),
            
            // 2. The Menu
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8), // 8px gap below button
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                   // Constrain width to button width
                   width: size.width,
                   child: Animate(
                     effects: [
                       FadeEffect(duration: 150.ms),
                       ScaleEffect(
                         begin: const Offset(0.9, 0.0), // Start slightly squashed horizontally, flat vertically
                         end: const Offset(1.0, 1.0),
                         curve: Curves.elasticOut, // Bouncy/Warping
                         duration: 600.ms,
                         alignment: Alignment.topCenter,
                       ),
                     ],
                     child: LiquidGlassContainer(
                       radius: 16,
                       padding: const EdgeInsets.symmetric(vertical: 8),
                       opacity: 1.0, 
                       blur: 5.0, // Increased Blur
                       borderRadius: BorderRadius.circular(16),
                       child: ConstrainedBox(
                         constraints: const BoxConstraints(maxHeight: 300),
                         child: SingleChildScrollView(
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: widget.items.map((item) {
                               final isSelected = item.value == widget.value;
                                 return InkWell(
                                   onTap: () {
                                     widget.onChanged(item.value);
                                     _closeDropdown();
                                   },
                                   child: Container(
                                     width: double.infinity,
                                     padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                     decoration: BoxDecoration(
                                        color: isSelected 
                                            ? (widget.isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
                                            : null,
                                     ),
                                     child: DefaultTextStyle(
                                       style: TextStyle(
                                         color: widget.isDark ? Colors.white : Colors.black87,
                                         fontSize: 14,
                                         fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                       ),
                                       child: Row(
                                         children: [
                                           Expanded(child: item.child),
                                           if (isSelected) 
                                             Icon(Icons.check, size: 16, color: widget.isDark ? Colors.white : Colors.black87),
                                         ],
                                       ),
                                     ),
                                   ),
                                 );
                             }).toList(),
                           ),
                         ),
                       ),
                     ),
                   ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    if (_isOpen) {
      _overlayEntry?.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.items.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => widget.items.first,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF2C2C2C) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Hug content or expand? Usually expandable.
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  child: selectedItem.child,
                ),
              ),
              const SizedBox(width: 8),
              if (_isOpen)
                Icon(Icons.keyboard_arrow_up, color: widget.isDark ? Colors.white70 : Colors.black54)
                .animate().scale(duration: 200.ms)
              else 
                Icon(Icons.keyboard_arrow_down, color: widget.isDark ? Colors.white70 : Colors.black54)
                 .animate().scale(duration: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
}
