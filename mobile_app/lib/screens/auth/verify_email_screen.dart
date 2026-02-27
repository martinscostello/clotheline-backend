import 'package:flutter/material.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_customer/widgets/branding/WashingMachineLogo.dart';
import '../user/main_layout.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:clotheline_core/clotheline_core.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ToastUtils.show(context, "Please enter a valid 6-digit OTP", type: ToastType.info);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).verifyEmail(widget.email, otp);
      
      if (!mounted) return;
      // Success -> Main Layout
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const MainLayout()), 
        (route) => false
      );
      
    } catch (e) {
      if (!mounted) return;
      ToastUtils.show(context, "Verification Failed: $e", type: ToastType.error);
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
    Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Background gradient colors (Same as Login/Signup)
    final bgColors = isDark 
      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] 
      : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)];

    return Scaffold(
      backgroundColor: bgColors.first,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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

          // 3. Main Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // Logo & Branding
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
                     "Verify Email",
                     style: TextStyle(
                       fontSize: 28,
                       fontWeight: FontWeight.bold,
                       color: isDark ? Colors.white : const Color(0xFF1E293B),
                       letterSpacing: -0.5,
                     ),
                   ),
                   const SizedBox(height: 8),
                   Text(
                     "Enter the 6-digit code sent to\n${widget.email}",
                     textAlign: TextAlign.center,
                     style: TextStyle(
                       fontSize: 16,
                       color: isDark ? Colors.white70 : const Color(0xFF64748B),
                     ),
                   ),
                   const SizedBox(height: 32),

                   // Glass OTP Input
                   Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        boxShadow: isDark ? [] : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ]
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 32, 
                              letterSpacing: 8, 
                              fontWeight: FontWeight.bold, 
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLength: 6,
                            decoration: InputDecoration(
                              counterText: "",
                              hintText: "000000",
                              hintStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black12),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleVerify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A80F0),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading 
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Verify & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                   ),
                   
                   const SizedBox(height: 24),
                   
                   // Resend Timer
                   TextButton(
                     onPressed: _canResend && !_isLoading ? _handleResend : null, 
                     child: Text(
                       _canResend 
                         ? "Resend Code" 
                         : "Resend in ${_resendSeconds}s",
                       style: TextStyle(
                         color: _canResend ? const Color(0xFF4A80F0) : (isDark ? Colors.white38 : Colors.grey),
                         fontWeight: FontWeight.bold,
                         fontSize: 16
                       )
                     ),
                   ),
                   const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Timer Variables
  int _resendSeconds = 60;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _resendSeconds = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        if(mounted) setState(() => _resendSeconds--);
      } else {
        if(mounted) setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _handleResend() async {
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(context, listen: false).resendOtp(widget.email);
       if (!mounted) return;
      ToastUtils.show(context, "Code sent!", type: ToastType.success);
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      ToastUtils.show(context, "Resend Failed: $e", type: ToastType.error);
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }
}
