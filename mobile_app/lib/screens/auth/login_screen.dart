import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import 'package:laundry_app/widgets/branding/WashingMachineLogo.dart';
import '../../utils/toast_utils.dart';
import '../user/main_layout.dart';
import '../admin/admin_main_layout.dart';
import '../common/legal_screen.dart';
import '../../widgets/dialogs/auth_error_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
        ToastUtils.show(context, "Please enter email and password", type: ToastType.error);
        return;
    }

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
      
      final err = e.toString().toLowerCase();
      // "Invalid credentials", "User not found", "Password incorrect"
      if (err.contains("credential") || err.contains("password") || err.contains("found") || err.contains("match")) {
         showDialog(
           context: context,
           builder: (ctx) => AuthErrorDialog(
             title: "Incorrect Password",
             message: "We couldn't sign you in. Please check your email and password, or reset it if you've forgotten.",
             primaryButtonLabel: "Try Again",
             secondaryButtonLabel: "Forgot Password?",
             onSecondaryPressed: () {
                Navigator.pop(ctx);
                ToastUtils.show(context, "Password Reset coming soon", type: ToastType.info);
             },
           )
         );
      } else {
         ToastUtils.show(context, "Login Failed: $e", type: ToastType.error);
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Background gradient colors
    final bgColors = isDark 
      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] 
      : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)];

    return Scaffold(
      backgroundColor: bgColors.first,
      body: Stack(
        children: [
          // 1. Soft Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: bgColors,
              )
            ),
          ),
          
          // 2. Subtle Background Pattern/Bubbles (Optional Elegant Touch)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.blue : Colors.lightBlue).withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -30,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.blue : Colors.lightBlue).withOpacity(0.05),
              ),
            ),
          ),

          // 3. Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // Logo & Branding
                   Hero(
                     tag: 'app_logo',
                     child: Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         shape: BoxShape.circle,
                         color: isDark ? Colors.white10 : Colors.white,
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(0.05),
                             blurRadius: 20,
                             offset: const Offset(0, 10),
                           )
                         ]
                       ),
                       child: const WashingMachineLogo(size: 60),
                     ),
                   ),
                   const SizedBox(height: 24),
                   Text(
                     "Welcome Back",
                     style: TextStyle(
                       fontSize: 28,
                       fontWeight: FontWeight.bold,
                       color: isDark ? Colors.white : const Color(0xFF1E293B),
                       letterSpacing: -0.5,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     "Sign in to manage your laundry",
                     style: TextStyle(
                       fontSize: 16,
                       color: isDark ? Colors.white70 : const Color(0xFF64748B),
                     ),
                   ),
                   const SizedBox(height: 48),

                   // Inputs
                   _buildGlassInput(
                     isDark: isDark,
                     controller: _emailController,
                     icon: Icons.email_outlined,
                     hint: "Email Address",
                     keyboardType: TextInputType.emailAddress,
                   ),
                   const SizedBox(height: 16),
                   _buildGlassInput(
                     isDark: isDark,
                     controller: _passwordController,
                     icon: Icons.lock_outline,
                     hint: "Password",
                     isPassword: true,
                     isVisible: _isPasswordVisible,
                     onVisibilityToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                   ),

                   const SizedBox(height: 12),
                   Align(
                     alignment: Alignment.centerRight,
                     child: TextButton(
                       onPressed: () {
                         // TODO: Implement Forgot Password navigation
                         ToastUtils.show(context, "Feature coming soon", type: ToastType.info); 
                       },
                       child: Text("Forgot Password?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                     ),
                   ),
                   const SizedBox(height: 24),

                   // Actions
                   SizedBox(
                     width: double.infinity,
                     height: 56,
                     child: ElevatedButton(
                       onPressed: _isLoading ? null : _handleLogin,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFF4A80F0),
                         foregroundColor: Colors.white,
                         elevation: 4,
                         shadowColor: const Color(0xFF4A80F0).withOpacity(0.4),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                       ),
                       child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                     ),
                   ),
                   const SizedBox(height: 24),
                   
                   // New here?
                   Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Text("New to Clotheline? ", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                       GestureDetector(
                         onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                         },
                         child: const Text("Create Account", style: TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.bold)),
                       )
                     ],
                   ),
                   
                   const SizedBox(height: 40),

                   // Legal Links
                   Wrap(
                     alignment: WrapAlignment.center,
                     children: [
                       GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.privacyPolicy))),
                         child: const Text("Privacy", style: TextStyle(color: Colors.grey, fontSize: 12))
                       ),
                       const Text("  •  ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                       GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.termsOfUse))),
                         child: const Text("Terms", style: TextStyle(color: Colors.grey, fontSize: 12))
                       ),
                     ],
                   )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassInput({
    required bool isDark,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black45),
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: isDark ? Colors.white38 : Colors.grey),
                onPressed: onVisibilityToggle,
              )
            : null,
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
