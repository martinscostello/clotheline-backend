import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../models/staff_model.dart';
import '../../../models/branch_model.dart';
import '../../../services/staff_service.dart';
import '../../../providers/branch_provider.dart';
import '../../../utils/toast_utils.dart';
import '../../../services/auth_service.dart';

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  final StaffService _staffService = StaffService();
  List<Staff> _staffList = [];
  bool _isLoading = true;
  Staff? _selectedStaff;
  Branch? _currentBranch;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    setState(() => _currentBranch = branchProvider.selectedBranch);
    await _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _isLoading = true);
    try {
      final staff = await _staffService.fetchStaff(branchId: _currentBranch?.id);
      if (mounted) {
        setState(() {
          _staffList = staff;
          _isLoading = false;
          // Auto-select first staff on tablet if none selected
          if (_selectedStaff == null && staff.isNotEmpty && MediaQuery.of(context).size.width >= 840) {
            _selectedStaff = staff.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.show(context, 'Error fetching staff: $e', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BranchProvider>(
      builder: (context, branchProvider, _) {
        // Sync branch if changed globally
        if (_currentBranch?.id != branchProvider.selectedBranch?.id) {
          _currentBranch = branchProvider.selectedBranch;
          _fetchStaff();
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text("Staff Profiles", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                onPressed: _showAddStaffDialog,
                tooltip: "Add Staff Member",
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: LiquidBackground(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 840;
                
                if (isTablet) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: _buildStaffList(isTablet)),
                        const VerticalDivider(color: Colors.white10, width: 1),
                        Expanded(flex: 5, child: _selectedStaff == null 
                          ? const Center(child: Text("Select a staff member", style: TextStyle(color: Colors.white24)))
                          : _buildStaffProfile(_selectedStaff!, isTablet)),
                      ],
                    ),
                  );
                } else {
                  return _buildStaffList(false);
                }
              },
            ),
          ),
        );
      }
    );
  }

  Widget _buildStaffList(bool isTablet) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    if (_staffList.isEmpty) return const Center(child: Text("No staff found in this branch", style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: EdgeInsets.only(top: isTablet ? 0 : 100, bottom: 100, left: 15, right: 15),
      itemCount: _staffList.length,
      itemBuilder: (context, index) {
        final staff = _staffList[index];
        final isSelected = _selectedStaff?.id == staff.id;
        final warningCount = staff.warnings.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              if (isTablet) {
                setState(() => _selectedStaff = staff);
              } else {
                _showMobileStaffDetails(staff);
              }
            },
            child: GlassContainer(
              opacity: isSelected ? 0.2 : 0.1,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                    child: Text(staff.name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(staff.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(staff.position, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            if (staff.isSuspended) ...[
                              const SizedBox(width: 8),
                              const Text("• SUSPENDED", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (warningCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: warningCount >= 3 ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: warningCount >= 3 ? Colors.red : Colors.orange, width: 1),
                      ),
                      child: Text(
                        "$warningCount Warning${warningCount > 1 ? 's' : ''}",
                        style: TextStyle(color: warningCount >= 3 ? Colors.red : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffProfile(Staff staff, bool isTablet) {
    final warningCount = staff.warnings.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(staff),
          const SizedBox(height: 15),
          _buildStatusActions(staff),
          const SizedBox(height: 25),
          const Text("Internal Notes", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GlassContainer(
            opacity: 0.05,
            padding: const EdgeInsets.all(15),
            child: Text(staff.salaryNotes ?? "No salary or internal notes added.", style: const TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Warning History", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.report_problem_outlined, size: 16),
                label: const Text("Issue Warning"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                  foregroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent)),
                ),
                onPressed: () => _showIssueWarningDialog(staff),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (warningCount == 0)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("Exemplary Staff: Zero Warnings.", style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic)),
            ))
          else
            ...staff.warnings.reversed.map((w) => _buildWarningCard(w, staff)),
          
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.archive_outlined, color: Colors.white38),
                  label: const Text("Archive Staff Member", style: TextStyle(color: Colors.white38)),
                  onPressed: () => _confirmArchiveStaff(staff),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 16),
                  label: const Text("Permanently Delete staff", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  onPressed: () => _confirmPermanentDelete(staff),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Staff staff) {
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            child: Text(staff.name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(staff.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    if (staff.isSuspended) ...[
                       const SizedBox(width: 10),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                         child: const Text("SUSPENDED", style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                       ),
                    ]
                  ],
                ),
                Text(staff.position, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone, color: Colors.white38, size: 14),
                    const SizedBox(width: 5),
                    Text(staff.phone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                if (staff.email != null && staff.email!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.email, color: Colors.white38, size: 14),
                      const SizedBox(width: 5),
                      Text(staff.email!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActions(Staff staff) {
    return Row(
      children: [
        Expanded(
          child: GlassContainer(
            opacity: 0.05,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Staff Status", style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text(staff.isSuspended ? "Suspended" : "Active", style: TextStyle(color: staff.isSuspended ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                Switch(
                  value: !staff.isSuspended,
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.redAccent,
                  inactiveTrackColor: Colors.redAccent.withOpacity(0.2),
                  onChanged: (val) => _toggleSuspension(staff),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard(StaffWarning warning, Staff staff) {
    Color severityColor;
    switch (warning.severity) {
      case 'Severe': severityColor = Colors.red; break;
      case 'Medium': severityColor = Colors.orange; break;
      default: severityColor = Colors.yellow;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: GlassContainer(
        opacity: 0.08,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: severityColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: severityColor.withOpacity(0.5))),
                  child: Text(warning.severity.toUpperCase(), style: TextStyle(color: severityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                Text(DateFormat('MMM dd, yyyy').format(warning.timestamp), style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text(warning.reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (warning.notes != null && warning.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(warning.notes!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            const Divider(color: Colors.white10, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Issued by: ${warning.issuedBy ?? 'Admin'}", style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                TextButton.icon(
                  onPressed: () => _sendWhatsAppWarning(staff, warning),
                  icon: const Icon(Icons.whatsapp, color: Colors.green, size: 18),
                  label: const Text("Send via WhatsApp", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Actions ---

  void _showMobileStaffDetails(Staff staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101020),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: _buildStaffProfile(staff, false),
      ),
    );
  }

  Future<void> _sendWhatsAppWarning(Staff staff, StaffWarning warning) async {
    try {
      await _staffService.sendWarningToWhatsApp(
        phone: staff.phone,
        staffName: staff.name,
        position: staff.position,
        branchName: _currentBranch?.name ?? "Main",
        severity: warning.severity,
        reason: warning.reason,
        notes: warning.notes,
        warningCount: staff.warnings.length,
      );
      // Mark as sent in backend? Ideally, but currently URL-based.
    } catch (e) {
      ToastUtils.show(context, 'WhatsApp error: $e', type: ToastType.error);
    }
  }

  Future<void> _toggleSuspension(Staff staff) async {
    try {
      final newStatus = !staff.isSuspended;
      await _staffService.updateStaff(staff.id, {
        'isSuspended': newStatus,
        'status': newStatus ? 'Suspended' : 'Active'
      });
      _fetchStaff();
      if (_selectedStaff?.id == staff.id) {
        // Optimistic UI update or just wait for fetch
      }
    } catch (e) {
      if (mounted) ToastUtils.show(context, "Error updating status: $e", type: ToastType.error);
    }
  }

  Future<void> _confirmPermanentDelete(Staff staff) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Delete permanently?", style: TextStyle(color: Colors.white)),
        content: Text("This will permanently remove ${staff.name} and all their records. This action cannot be undone.", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE PERMANENTLY"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _staffService.deleteStaff(staff.id);
        _fetchStaff();
        if (mounted) {
          setState(() => _selectedStaff = null);
          ToastUtils.show(context, "Staff permanently deleted", type: ToastType.success);
        }
      } catch (e) {
        if (mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
      }
    }
  }

  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final posController = TextEditingController();
    final emailController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("New Staff Member", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogInput("Full Name", nameController),
              _buildDialogInput("Position / Role", posController),
              _buildDialogInput("Phone Number", phoneController),
              _buildDialogInput("Email (Optional)", emailController),
              _buildDialogInput("Internal Notes", noteController, maxLines: 3),
              const SizedBox(height: 10),
              Text("Attached to: ${_currentBranch?.name ?? 'No Branch Selected'}", style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty || _currentBranch == null) {
                ToastUtils.show(context, "Please fill required fields and select a branch", type: ToastType.info);
                return;
              }
              Navigator.pop(ctx);
              try {
                await _staffService.createStaff({
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'position': posController.text,
                  'email': emailController.text,
                  'branchId': _currentBranch!.id,
                  'salaryNotes': noteController.text,
                });
                _fetchStaff();
              } catch (e) {
                ToastUtils.show(context, "Error: $e", type: ToastType.error);
              }
            },
            child: const Text("Create", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showIssueWarningDialog(Staff staff) {
    final reasonController = TextEditingController();
    final noteController = TextEditingController();
    String severity = 'Low';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: Text("Issue Warning to ${staff.name}", style: const TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogInput("Reason (e.g. Lateness)", reasonController),
                const SizedBox(height: 15),
                const Align(alignment: Alignment.centerLeft, child: Text("Severity", style: TextStyle(color: Colors.white54, fontSize: 12))),
                DropdownButton<String>(
                  value: severity,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  items: ['Low', 'Medium', 'Severe'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setDialogState(() => severity = val!),
                ),
                const SizedBox(height: 10),
                _buildDialogInput("Additional Notes", noteController, maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                if (reasonController.text.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _staffService.addWarning({
                    'staffId': staff.id,
                    'reason': reasonController.text,
                    'severity': severity,
                    'notes': noteController.text,
                  });
                  _fetchStaff();
                  // Re-select to update UI
                  if (_selectedStaff?.id == staff.id) {
                     _selectedStaff = _staffList.firstWhere((s) => s.id == staff.id, orElse: () => staff);
                  }
                } catch (e) {
                  ToastUtils.show(context, "Error: $e", type: ToastType.error);
                }
              },
              child: const Text("ISSUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmArchiveStaff(Staff staff) async {
    final reasonController = TextEditingController();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Archive Staff Member?", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Are you sure? This will remove them from the active list.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 15),
             _buildDialogInput("Reason for archiving", reasonController),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Archive"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _staffService.archiveStaff(staff.id, reasonController.text);
        _fetchStaff();
        if (mounted) setState(() => _selectedStaff = null);
      } catch (e) {
        if (mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
      }
    }
  }

  Widget _buildDialogInput(String label, TextEditingController controller, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
      ),
    );
  }
}
