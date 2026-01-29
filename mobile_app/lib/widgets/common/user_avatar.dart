import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarId;
  final String name;
  final double radius;
  final bool isDark;

  const UserAvatar({
    super.key,
    this.avatarId,
    required this.name,
    this.radius = 35,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarId != null && avatarId!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: Image.asset(
            'assets/images/avatars/$avatarId.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to initials if local asset is missing (e.g., u16-u20 or admin a1-a10)
              final isAppAdmin = avatarId!.startsWith('a_');
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isAppAdmin 
                    ? LinearGradient(
                        colors: [const Color(0xFF2C3E50), const Color(0xFF4CA1AF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  color: isAppAdmin ? null : (isDark ? Colors.white12 : Colors.black12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: radius * 0.8,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Default Fallback: Initials
    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: radius * 0.7,
          color: isDark ? Colors.white : Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
