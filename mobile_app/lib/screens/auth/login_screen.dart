import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:laundry_app/widgets/branding/WashingMachineLogo.dart';
import 'package:laundry_app/widgets/ui/liquid_glass_container.dart';
import '../../widgets/medical/MedicalLogo.dart';
import '../user/main_layout.dart';
import '../admin/admin_main_layout.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  const LoginScreen({super.key, required this.onThemeChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.login(
        _emailController.text.trim(), 
        _passwordController.text.trim()
      );
      if (!mounted) return;
      if (user['role'] == 'admin') {
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminMainLayout()));
      } else {
         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.redAccent)
      );
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgImage = isDark ? 'assets/images/laundry_dark.png' : 'assets/images/laundry_light.png';

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(bgImage, fit: BoxFit.cover),
          ),
          
          // Scrollable Content
          SingleChildScrollView(
            child: SizedBox(
              height: MediaQuery.of(context).size.height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Liquid Glass Container (Reusable Component)
                    LiquidGlassContainer(
                      radius: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const WashingMachineLogo(size: 100),
                          const SizedBox(height: 20),
                          Text(
                            "Clotheline",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Fresh clothes, delivered.",
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontFamily: 'SF Pro Text',
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildMedicalInput(
                            label: "Email Address",
                            hint: "Enter your email",
                            controller: _emailController,
                          ),
                          const SizedBox(height: 16),
                           _buildMedicalInput(
                            label: "Password",
                            hint: "Enter your password",
                            controller: _passwordController,
                            isPassword: true,
                          ),
                          const SizedBox(height: 30),
                          _isLoading 
                            ? const CircularProgressIndicator()
                            : Column(
                                children: [
                                  _buildPrimaryButton("Login", _handleLogin),
                                  const SizedBox(height: 12),
                                  _buildOutlineButton("Sign Up", () {}),
                                ],
                              ),
                          const SizedBox(height: 24),
                          TextButton(
                            onPressed: () {},
                            child: const Text("Privacy & Terms", style: TextStyle(color: Color(0xFF64748B), decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            labelStyle: const TextStyle(color: Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF94A3B8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A80F0), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A80F0), // Medical Blue
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }

  Widget _buildOutlineButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4A80F0),
          side: const BorderSide(color: Color(0xFF4A80F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white.withOpacity(0.3),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
    );
  }
}
