import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../theme/app_theme.dart';
import '../../../../utils/toast_utils.dart';

class AdminEditAdminScreen extends StatefulWidget {
  final Map<String, dynamic>? admin; // If null, we are creating a new admin

  const AdminEditAdminScreen({super.key, this.admin});

  @override
  State<AdminEditAdminScreen> createState() => _AdminEditAdminScreenState();
}

class _AdminEditAdminScreenState extends State<AdminEditAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isRevoked = false;
  Map<String, bool> _permissions = {
    'manageCMS': false,
    'manageOrders': false,
    'manageServices': false,
    'manageProducts': false,
    'manageUsers': false,
  };

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.admin != null) {
      final admin = widget.admin!;
      _nameController.text = admin['name'] ?? '';
      _emailController.text = admin['email'] ?? '';
      _phoneController.text = admin['phone'] ?? '';
      _isRevoked = admin['isRevoked'] ?? false;
      
      if (admin['permissions'] != null) {
        _permissions = Map<String, bool>.from(admin['permissions']);
      }
    }
  }

  Future<void> _saveAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final adminData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'permissions': _permissions,
        'isRevoked': _isRevoked,
      };

      if (widget.admin == null) {
        // Create Mode
         adminData['password'] = _passwordController.text.trim();
        await authService.createAdmin(adminData);
      } else {
        // Update Mode
        await authService.updateAdmin(widget.admin!['_id'] ?? widget.admin!['id'], adminData);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'Error: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.admin != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isEditing ? "Edit Administrator" : "New Administrator", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassContainer(
                   opacity: 0.1,
                   padding: const EdgeInsets.all(20),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       const Text("Profile", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 15),
                       _buildInput("Name", _nameController),
                       const SizedBox(height: 10),
                       _buildInput("Email", _emailController),
                       const SizedBox(height: 10),
                       if (!isEditing) ...[
                         _buildInput("Password", _passwordController, isPassword: true),
                         const SizedBox(height: 10),
                       ],
                       _buildInput("Phone", _phoneController),
                     ],
                   ),
                ),

                const SizedBox(height: 20),

                GlassContainer(
                  opacity: 0.1,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Permissions", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildSwitch("Access CMS (Home, Ads, Branding)", 'manageCMS'),
                      _buildSwitch("Manage Orders", 'manageOrders'),
                      _buildSwitch("Manage Services", 'manageServices'),
                      _buildSwitch("Manage Products", 'manageProducts'),
                      _buildSwitch("Manage Users (Broadcast)", 'manageUsers'),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (isEditing && widget.admin?['isMasterAdmin'] != true)
                  GlassContainer(
                    opacity: 0.1,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Revoke Access", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Switch(
                          value: _isRevoked,
                          onChanged: (val) => setState(() => _isRevoked = val),
                          activeThumbColor: Colors.red,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _isLoading ? null : _saveAdmin,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("Save Administrator", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      validator: (val) => val!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
      ),
    );
  }

  Widget _buildSwitch(String label, String key) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Switch(
          value: _permissions[key] ?? false,
          onChanged: (val) {
            setState(() {
              _permissions[key] = val;
            });
          },
          activeThumbColor: AppTheme.primaryColor,
        ),
      ],
    );
  }
}
