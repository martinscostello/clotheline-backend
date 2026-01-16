import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:laundry_app/widgets/branding/WashingMachineLogo.dart';
import 'package:laundry_app/widgets/ui/liquid_glass_container.dart';
import '../user/main_layout.dart';
import 'package:provider/provider.dart';
import 'verify_email_screen.dart'; // Added Import
import '../../providers/branch_provider.dart';
import '../../models/branch_model.dart';

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
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields"), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Call AuthService signup
      await Provider.of<AuthService>(context, listen: false).signup(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim()
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(bgImage, fit: BoxFit.cover),
          ),
          
          // Scrollable Content
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LiquidGlassContainer(
                    radius: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    child: Consumer<BranchProvider>(
                      builder: (context, branchProvider, _) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const WashingMachineLogo(size: 80),
                            const SizedBox(height: 16),
                            Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                                fontFamily: 'SF Pro Display',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Join the freshest laundry community",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontFamily: 'SF Pro Text',
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            _buildInput(label: "Full Name", hint: "John Doe", controller: _nameController, icon: Icons.person),
                            const SizedBox(height: 12),
                            _buildInput(label: "Email", hint: "john@example.com", controller: _emailController, icon: Icons.email),
                            const SizedBox(height: 12),
                            _buildInput(label: "Phone", hint: "123-456-7890", controller: _phoneController, icon: Icons.phone),
                            const SizedBox(height: 12),
                            
                            // Branch Selection Dropdown
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Select Your Location", style: TextStyle(color: const Color(0xFF64748B), fontSize: 12)),
                                      IconButton(
                                        icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF4A80F0)),
                                        onPressed: () => branchProvider.fetchBranches(force: true),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: "Refresh Locations",
                                      )
                                    ],
                                  ),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<Branch>(
                                      isExpanded: true,
                                      hint: Row(children: [
                                        const Icon(Icons.location_on, color: Color(0xFF64748B), size: 20),
                                        const SizedBox(width: 12),
                                        Text("Select Your Location", style: TextStyle(color: const Color(0xFF64748B)))
                                      ]),
                                      value: _selectedBranch,
                                      items: branchProvider.branches.map((b) => DropdownMenuItem(
                                        value: b,
                                        child: Row(children: [
                                           const Icon(Icons.location_on, color: Color(0xFF4A80F0), size: 20),
                                           const SizedBox(width: 12),
                                           Text(b.name, style: const TextStyle(color: Colors.black87))
                                        ]),
                                      )).toList(),
                                      onChanged: (val) => setState(() => _selectedBranch = val),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            _buildInput(label: "Password", hint: "Create a password", controller: _passwordController, isPassword: true, icon: Icons.lock),
                            
                            const SizedBox(height: 24),
                            _isLoading 
                              ? const CircularProgressIndicator()
                              : SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _handleSignup,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A80F0),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 2,
                                    ),
                                    child: const Text("Sign Up", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  ),
                                ),
                          ],
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF94A3B8))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4A80F0), width: 2)),
      ),
    );
  }
}
