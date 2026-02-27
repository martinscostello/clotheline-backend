import 'package:flutter/material.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_customer/widgets/branding/WashingMachineLogo.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'verify_email_screen.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../widgets/dialogs/auth_error_dialog.dart';
// For navigation back

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  Branch? _selectedBranch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // Fetch branches if empty
       Provider.of<BranchProvider>(context, listen: false).fetchBranches();
    });
  }

  Future<void> _handleSignup() async {
    if (_nameController.text.trim().isEmpty || 
        _emailController.text.trim().isEmpty || 
        _passwordController.text.trim().isEmpty) {
       ToastUtils.show(context, "Please fill in all required fields", type: ToastType.info);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Call AuthService signup
      await Provider.of<AuthService>(context, listen: false).signup(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        branchId: _selectedBranch?.id, // [FIX] Pass selected branch ID
      );

      if (!mounted) return;
      
      // Save Branch Selection
      if (_selectedBranch != null) {
         await Provider.of<BranchProvider>(context, listen: false).selectBranch(_selectedBranch!);
      }
      
      // Navigate to Verification on success
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: _emailController.text.trim())));
      
    } catch (e) {
      if (!mounted) return;
      
      final err = e.toString().toLowerCase();
      if (err.contains("exists") || err.contains("taken") || err.contains("email")) {
         showDialog(
           context: context,
           builder: (ctx) => AuthErrorDialog(
             title: "Email Already Exists",
             message: "This email address is already being used. If you have an account, please log in.",
             primaryButtonLabel: "Log In",
             onPrimaryPressed: () {
                Navigator.pop(ctx); // Close Dialog
                Navigator.pop(context); // Go back to Login Screen
             },
             secondaryButtonLabel: "Cancel",
           )
         );
      } else {
         // Generic Error
         ToastUtils.show(context, "Signup Failed: ${e.toString()}", type: ToastType.error);
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Background gradient colors (Same as LoginScreen)
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
          
          // 2. Subtle Background Pattern/Bubbles
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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Consumer<BranchProvider>(
                   builder: (context, branchProvider, _) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         // ... Logo & Branding ...
                         Hero(
                           tag: 'app_logo',
                           child: Container(
                             padding: const EdgeInsets.all(16),
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
                             child: const WashingMachineLogo(size: 50),
                           ),
                         ),
                         const SizedBox(height: 24),
                         Text(
                           "Create Account",
                           style: TextStyle(
                             fontSize: 28,
                             fontWeight: FontWeight.bold,
                             color: isDark ? Colors.white : const Color(0xFF1E293B),
                             letterSpacing: -0.5,
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text(
                           "Join the freshest laundry community",
                           style: TextStyle(
                             fontSize: 16,
                             color: isDark ? Colors.white70 : const Color(0xFF64748B),
                           ),
                         ),
                         const SizedBox(height: 32),
  
                         // Inputs
                         _buildGlassInput(
                           isDark: isDark,
                           controller: _nameController,
                           icon: Icons.person_outline,
                           hint: "Full Name",
                           keyboardType: TextInputType.name,
                           textInputAction: TextInputAction.next,
                         ),
                         const SizedBox(height: 16),
                         _buildGlassInput(
                           isDark: isDark,
                           controller: _emailController,
                           icon: Icons.email_outlined,
                           hint: "Email Address",
                           keyboardType: TextInputType.emailAddress,
                           textInputAction: TextInputAction.next,
                         ),
                         const SizedBox(height: 16),
                         _buildGlassInput(
                           isDark: isDark,
                           controller: _phoneController,
                           icon: Icons.phone_outlined,
                           hint: "Phone Number",
                           keyboardType: TextInputType.phone,
                           textInputAction: TextInputAction.next,
                         ),
                         const SizedBox(height: 16),
                         
                         // Branch Selection (Styled to match inputs)
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                           child: DropdownButtonHideUnderline(
                             child: DropdownButton<Branch>(
                               isExpanded: true,
                               dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                               icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white54 : Colors.black45),
                               hint: Row(children: [
                                 Icon(Icons.location_on_outlined, color: isDark ? Colors.white54 : Colors.black45),
                                 const SizedBox(width: 12),
                                 Text("Select Your Location", style: TextStyle(color: isDark ? Colors.white30 : Colors.black38))
                               ]),
                               value: _selectedBranch,
                               items: branchProvider.branches.map((b) => DropdownMenuItem(
                                 value: b,
                                 child: Row(children: [
                                    const Icon(Icons.location_on, color: Color(0xFF4A80F0), size: 20),
                                    const SizedBox(width: 12),
                                    Text(b.name, style: TextStyle(color: isDark ? Colors.white : Colors.black87))
                                 ]),
                               )).toList(),
                               onChanged: (val) => setState(() => _selectedBranch = val),
                             ),
                           ),
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
                           textInputAction: TextInputAction.done,
                         ),
       
                         const SizedBox(height: 32),
  
                         // Actions
                         SizedBox(
                           width: double.infinity,
                           height: 56,
                           child: ElevatedButton(
                             onPressed: _isLoading ? null : _handleSignup,
                             style: ElevatedButton.styleFrom(
                               backgroundColor: const Color(0xFF4A80F0),
                               foregroundColor: Colors.white,
                               elevation: 4,
                               shadowColor: const Color(0xFF4A80F0).withOpacity(0.4),
                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                             ),
                             child: _isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                           ),
                         ),
                         const SizedBox(height: 24),
                         
                         // Already have account?
                         Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           children: [
                             Text("Already have an account? ", style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
                             GestureDetector(
                               onTap: () => Navigator.pop(context),
                               child: const Text("Sign In", style: TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.bold)),
                             )
                           ],
                         ),
                         const SizedBox(height: 30),
                      ],
                    );
                   }
                ),
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
    TextInputAction? textInputAction,
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
        textInputAction: textInputAction,
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
