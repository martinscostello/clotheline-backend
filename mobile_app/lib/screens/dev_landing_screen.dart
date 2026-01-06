import 'package:flutter/material.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/screens/user/main_layout.dart';
import 'package:laundry_app/screens/admin/admin_main_layout.dart';
import 'package:provider/provider.dart';
import 'package:laundry_app/services/auth_service.dart';

class DevLandingScreen extends StatelessWidget {
  const DevLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Development Mode", 
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            const Text(
              "Bypassing Auth for faster testing",
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 50),
            
            // User App Button
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.person, color: Colors.black),
                label: const Text("Go to USER App"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => const MainLayout())
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Admin App Button
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                label: const Text("Go to ADMIN App"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                   // Enable Dev Mode (Master Admin access)
                   // We need to import provider first at top
                   final auth = Provider.of<AuthService>(context, listen: false);
                   auth.enableDevMode();
                   
                   Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => const AdminMainLayout())
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
