import 'dart:ui';
import 'package:flutter/material.dart';
import 'PremiumNavBar.dart';
import 'package:clotheline_core/clotheline_core.dart';

class GlassSidebar extends StatefulWidget {
  final int currentIndex;
  final List<PremiumNavItem> items;
  final Function(int) onTap;
  final VoidCallback? onLogout;

  const GlassSidebar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.onLogout,
  });

  @override
  State<GlassSidebar> createState() => _GlassSidebarState();
}

class _GlassSidebarState extends State<GlassSidebar> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  
  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.items.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark 
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.85);

    return Container(
      width: 100,
      height: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Branding / Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wash, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = index == widget.currentIndex;

                    return GestureDetector(
                      onTap: () {
                        _controllers[index].forward(from: 0.0);
                        widget.onTap(index);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: isSelected ? 1.0 : 0.0,
                            child: Container(
                              width: 80,
                              height: 70,
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? Colors.white.withValues(alpha: 0.1) 
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white60 : Colors.black54),
                                size: isSelected ? 28 : 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white60 : Colors.black54),
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (widget.onLogout != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    onPressed: widget.onLogout,
                    tooltip: "Logout",
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
