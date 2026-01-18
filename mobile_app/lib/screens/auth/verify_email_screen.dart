import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:laundry_app/widgets/branding/WashingMachineLogo.dart';
import 'package:laundry_app/widgets/ui/liquid_glass_container.dart';
import '../user/main_layout.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../utils/toast_utils.dart';

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
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Stack(
        children: [
           // Reuse login background if possible, or just solid
           Positioned.fill(
             child: Image.asset(
               isDark ? 'assets/images/laundry_dark.png' : 'assets/images/laundry_light.png',
               fit: BoxFit.cover,
             ),
           ),
           Center(
             child: SingleChildScrollView(
               padding: const EdgeInsets.symmetric(horizontal: 24),
               child: LiquidGlassContainer(
                 child: Column(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(Icons.mark_email_read_outlined, size: 60, color: Color(0xFF4A80F0)),
                     const SizedBox(height: 20),
                     Text(
                       "Verify Email",
                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                     ),
                     const SizedBox(height: 10),
                     Text(
                       "Enter the 6-digit code sent to\n${widget.email}",
                       textAlign: TextAlign.center,
                       style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                     ),
                     const SizedBox(height: 30),
                     
                     TextField(
                       controller: _otpController,
                       keyboardType: TextInputType.number,
                       textAlign: TextAlign.center,
                       style: TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                       maxLength: 6,
                       decoration: InputDecoration(
                         counterText: "",
                         filled: true,
                         fillColor: Colors.white.withOpacity(0.5),
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                         hintText: "000000"
                       ),
                     ),
                     
                     const SizedBox(height: 20),
                     _isLoading 
                       ? const CircularProgressIndicator()
                       : Column(
                           children: [
                             SizedBox(
                               width: double.infinity,
                               height: 50,
                               child: ElevatedButton(
                                 onPressed: _handleVerify,
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: const Color(0xFF4A80F0),
                                   foregroundColor: Colors.white,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                 ),
                                 child: const Text("Verify & Login"),
                               ),
                             ),
                             const SizedBox(height: 16),
                             TextButton(
                               onPressed: _canResend && !_isLoading ? _handleResend : null, 
                               child: Text(
                                 _canResend 
                                   ? "Resend Code" 
                                   : "Resend in ${_resendSeconds}s",
                                 style: TextStyle(
                                   color: _canResend ? const Color(0xFF4A80F0) : Colors.grey,
                                   fontWeight: FontWeight.bold
                                 )
                               ),
                             )
                           ],
                         ),
                   ],
                 ),
               ),
             ),
           )
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
