import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import '../../../utils/toast_utils.dart';

class ManagePasswordScreen extends StatefulWidget {
  const ManagePasswordScreen({super.key});

  @override
  State<ManagePasswordScreen> createState() => _ManagePasswordScreenState();
}

class _ManagePasswordScreenState extends State<ManagePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePassword() async {
    if (_currentController.text.isEmpty || _newController.text.isEmpty || _confirmController.text.isEmpty) {
        ToastUtils.show(context, "Please fill all fields", type: ToastType.error);
        return;
    }
    if (_newController.text != _confirmController.text) {
        ToastUtils.show(context, "New passwords do not match", type: ToastType.error);
        return;
    }

    setState(() => _isLoading = true);

    // TODO: Call actual API endpoint
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
       setState(() => _isLoading = false);
       _currentController.clear();
       _newController.clear();
       _confirmController.clear();
       ToastUtils.show(context, "Password updated successfully", type: ToastType.success);
       Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Global Background Consistency
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Manage Password", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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
             _buildInput(isDark, "Current Password", _currentController, true, textInputAction: TextInputAction.next),
             const SizedBox(height: 16),
             _buildInput(isDark, "New Password", _newController, true, textInputAction: TextInputAction.next),
             const SizedBox(height: 16),
             _buildInput(isDark, "Confirm New Password", _confirmController, true, textInputAction: TextInputAction.done),
             
             const SizedBox(height: 48),

             SizedBox(
               width: double.infinity,
               height: 52,
               child: ElevatedButton(
                 onPressed: _isLoading ? null : _updatePassword,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF4A80F0),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   elevation: 2,
                 ),
                 child: _isLoading 
                   ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                   : const Text("Update Password", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
               ),
             )
           ],
         ),
      ),
    ),
    );
  }

  Widget _buildInput(bool isDark, String label, TextEditingController controller, bool isPassword, {
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 8),
        Container(
           decoration: BoxDecoration(
             color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
           ),
           child: TextField(
             controller: controller,
             obscureText: isPassword,
             textInputAction: textInputAction,
             keyboardType: keyboardType,
             style: TextStyle(color: isDark ? Colors.white : Colors.black87),
             decoration: const InputDecoration(
               border: InputBorder.none,
               contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
             ),
           ),
        ),
      ],
    );
  }
}
