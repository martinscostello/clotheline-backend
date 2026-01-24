import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import '../../common/legal_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Global Background Consistency
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("About Clotheline", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: LaundryGlassBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70, left: 24, right: 24, bottom: 24),
          child: Column(
          children: [
            const SizedBox(height: 20),
            // Logo
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_laundry_service, size: 50, color: Color(0xFF4A80F0)),
            ),
            const SizedBox(height: 16),
            Text("Clotheline", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text("Version 1.2.0", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
            
            const SizedBox(height: 48),

            _buildLinkItem(context, isDark, "Privacy Policy", () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.privacyPolicy)));
            }),
            _buildLinkItem(context, isDark, "Terms of Use", () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.termsOfUse)));
            }),
            
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Column(
                children: [
                  Text("Contact Support", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    child: const Text("support@brimarcglobal.com", style: TextStyle(color: Color(0xFF4A80F0), decoration: TextDecoration.underline)),
                  ),
                  const SizedBox(height: 4),
                  Text("Lagos, Nigeria", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
                ],
              ),
            ),
            
            const SizedBox(height: 50),
            Text("© 2026 Clotheline. All rights reserved.", style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.black26)),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildLinkItem(BuildContext context, bool isDark, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white30 : Colors.black26),
    );
  }
}
