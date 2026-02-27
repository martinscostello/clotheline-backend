import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import 'package:clotheline_admin/widgets/common/user_avatar.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';

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
  List<String> _assignedBranches = [];
  Map<String, bool> _permissions = {
    'manageCMS': false,
    'manageOrders': false,
    'manageServices': false,
    'manageProducts': false,
    'manageUsers': false,
    'manageChat': false,
    'manageSettings': false,
    'manageAdmins': false,
    'managePOS': false,
    'manageStaff': false,
    'manageFinancials': false,
    'viewRevenueOverview': false,
    'manageProductIllusions': false,
    'manageBackup': false,
  };

  String? _selectedAvatarId;
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
        _permissions.addAll(Map<String, bool>.from(admin['permissions']));
      }
      if (admin['assignedBranches'] != null) {
        _assignedBranches = List<String>.from(admin['assignedBranches'].map((b) => b is Map ? b['_id'] : b));
      }
      _selectedAvatarId = admin['avatarId'];
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
        'avatarId': _selectedAvatarId,
        'isRevoked': _isRevoked,
        'assignedBranches': _assignedBranches,
      };

      if (widget.admin == null) {
        // Create Mode
         adminData['password'] = _passwordController.text.trim();
        await authService.createAdmin(adminData);
      } else {
        // Update Mode
        await authService.updateAdmin((widget.admin!['_id'] ?? widget.admin!['id']).toString(), adminData);
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

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
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
                         Center(
                           child: Column(
                             children: [
                               UserAvatar(avatarId: _selectedAvatarId, name: _nameController.text.isNotEmpty ? _nameController.text : 'A', radius: 40, isDark: true),
                               const SizedBox(height: 10),
                               const Text("Select Exclusive Admin Avatar", style: TextStyle(color: Colors.white54, fontSize: 12)),
                               const SizedBox(height: 10),
                               SizedBox(
                                 height: 60,
                                 child: ListView.builder(
                                   scrollDirection: Axis.horizontal,
                                   itemCount: 10,
                                   itemBuilder: (context, index) {
                                     final avatarId = 'a_${index + 1}';
                                     final isSelected = _selectedAvatarId == avatarId;
                                     return GestureDetector(
                                       onTap: () => setState(() => _selectedAvatarId = avatarId),
                                       child: Container(
                                         margin: const EdgeInsets.only(right: 10),
                                         decoration: BoxDecoration(
                                           shape: BoxShape.circle,
                                           border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent, width: 2),
                                         ),
                                         child: UserAvatar(avatarId: avatarId, name: "", radius: 25, isDark: true),
                                       ),
                                     );
                                   },
                                 ),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(height: 20),
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
                        _buildSwitch("Manage Chat threads", 'manageChat'),
                        _buildSwitch("Manage App Settings (Tax/Fees)", 'manageSettings'),
                        _buildSwitch("Manage Admin accounts", 'manageAdmins'),
                        _buildSwitch("Access POS Checkout", 'managePOS'),
                        _buildSwitch("Manage Staff Profiles & Warnings", 'manageStaff'),
                        _buildSwitch("View Financial Reports (Investor)", 'manageFinancials'),
                        _buildSwitch("View Dashboard Revenue Chart", 'viewRevenueOverview'),
                        _buildSwitch("Manage Product Ext. Illusions", 'manageProductIllusions'),
                        _buildSwitch("Generate Database Backups", 'manageBackup'),
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
                        const Text("Branch Assignment", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        const Text("Admins can only see data from assigned branches.", style: TextStyle(color: Colors.white54, fontSize: 10)),
                        const SizedBox(height: 15),
                        Consumer<BranchProvider>(
                          builder: (context, bp, _) {
                            final allBranches = bp.branches;
                            if (allBranches.isEmpty) return const Text("No branches found", style: TextStyle(color: Colors.white24));
                            
                            return Column(
                              children: allBranches.map((branch) {
                                final isSelected = _assignedBranches.contains(branch.id);
                                return CheckboxListTile(
                                  title: Text(branch.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                  subtitle: Text(branch.address, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  value: isSelected,
                                  activeColor: AppTheme.primaryColor,
                                  checkColor: Colors.black,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _assignedBranches.add(branch.id);
                                      } else {
                                        _assignedBranches.remove(branch.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            );
                          },
                        ),
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
                            activeColor: Colors.red,
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
          activeColor: AppTheme.primaryColor,
        ),
      ],
    );
  }
}
