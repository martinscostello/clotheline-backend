import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/custom_cached_image.dart'; // [FIX] Imported for web-safe images
import 'admin_edit_staff_screen.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final staff = await _staffService.fetchStaff(branchId: _currentBranch?.id);
      if (mounted) {
        setState(() {
          // Sort: Active (isArchived: false) first, then Inactive
          staff.sort((a, b) {
            if (a.isArchived == b.isArchived) {
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
            return a.isArchived ? 1 : -1;
          });

          _staffList = staff;
          _isLoading = false;
          // Auto-select first staff on tablet if none selected
          if (staff.isNotEmpty && MediaQuery.of(context).size.width >= 600) {
            if (_selectedStaff == null) {
              _selectedStaff = staff.first;
            } else {
              try {
                _selectedStaff = staff.firstWhere((s) => s.id == _selectedStaff!.id);
              } catch (_) {
                _selectedStaff = staff.first;
              }
            }
          } else if (staff.isEmpty) {
            _selectedStaff = null;
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

  void _onBranchChanged(String? newId) {
    if (newId == null) return;
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final branch = branchProvider.branches.firstWhere((b) => b.id == newId);
    branchProvider.selectBranch(branch);
    setState(() {
      _currentBranch = branch;
      _selectedStaff = null;
    });
    _fetchStaff();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Staff Profiles", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Consumer<BranchProvider>(
              builder: (context, branchProvider, _) {
                if (branchProvider.branches.isEmpty) return const SizedBox();
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xFF1E1E2C),
                      value: branchProvider.selectedBranch?.id,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryColor, size: 20),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      onChanged: _onBranchChanged,
                      items: branchProvider.branches.map((b) {
                        return DropdownMenuItem(value: b.id, child: Text(b.name));
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminEditStaffScreen(branch: _currentBranch))
                );
                if (result == true) _fetchStaff();
              },
              tooltip: "Add Staff Member",
            ),
            const SizedBox(width: 15),
          ],
        ),
        body: LiquidBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 600;
              
              if (isTablet) {
                return Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _buildStaffList(true)),
                      const VerticalDivider(color: Colors.white10, width: 1),
                      Expanded(flex: 7, child: _selectedStaff == null 
                        ? const Center(child: Text("Select a staff member", style: TextStyle(color: Colors.white24)))
                        : _buildStaffProfile(_selectedStaff!, true)),
                    ],
                  ),
                );
              } else {
                return _buildStaffList(false);
              }
            },
          ),
        ),
      ),
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
            child: Opacity(
              opacity: staff.isArchived ? 0.5 : 1.0,
              child: GlassContainer(
                opacity: isSelected ? 0.25 : 0.1,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildProfileImage(staff, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  staff.name, 
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (staff.isArchived) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text("INACTIVE", style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          Text(staff.position, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (warningCount > 0 && !staff.isArchived)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: warningCount >= 3 ? Colors.red.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: warningCount >= 3 ? Colors.red : Colors.orange, width: 1),
                        ),
                        child: Text(
                          "$warningCount Warning${warningCount > 1 ? 's' : ''}",
                          style: TextStyle(color: warningCount >= 3 ? Colors.red : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileImage(Staff staff, {double radius = 40}) {
    if (staff.passportPhoto != null && staff.passportPhoto!.isNotEmpty) {
       return ClipRRect(
         borderRadius: BorderRadius.circular(radius),
         child: SizedBox(
           width: radius * 2,
           height: radius * 2,
           child: CustomCachedImage(imageUrl: staff.passportPhoto!, fit: BoxFit.cover),
         ),
       );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      child: Text(staff.name[0].toUpperCase(), style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: radius * 0.8)),
    );
  }

  Widget _buildStaffProfile(Staff staff, bool isTablet) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionHeader(staff),
          const SizedBox(height: 20),
          _buildVisualIDCard(staff),
          const SizedBox(height: 10),
          _buildIDActions(staff),
          const SizedBox(height: 30),
          _buildInfoSection("Account Details", [
            _buildDetailRow("Residential Address", staff.address ?? "Not Set"),
            _buildDetailRow("Bank Name", staff.bankDetails?.bankName ?? "Not Set"),
            _buildDetailRow("Account Number", staff.bankDetails?.accountNumber ?? "Not Set"),
            _buildDetailRow("Account Name", staff.bankDetails?.accountName ?? "Not Set"),
          ]),
          const SizedBox(height: 20),
          _buildGuarantorSection(staff),
          const SizedBox(height: 20),
          _buildSalaryPerformanceSection(staff),
          const SizedBox(height: 20),
          _buildWarningSection(staff),
          const SizedBox(height: 20),
          _buildAgreementSection(staff),
          const SizedBox(height: 20),
          _buildProbationSection(staff),
          const SizedBox(height: 20),
          _buildSignatureSection(staff),
          const SizedBox(height: 20),
          _buildFutureReadySection("Attendance (Coming Soon)"),
          const SizedBox(height: 60),
          _buildSystemActions(staff),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildActionHeader(Staff staff) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(staff.isSuspended ? "SUSPENDED" : "ACTIVE", 
              style: TextStyle(color: staff.isSuspended ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
             const Text("Staff Status", style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: AppTheme.secondaryColor),
              onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminEditStaffScreen(staff: staff)));
                if (res == true) _fetchStaff();
              },
            ),
            Switch(
              value: !staff.isSuspended,
              activeColor: Colors.green,
              onChanged: (val) => _toggleSuspension(staff),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVisualIDCard(Staff staff) {
    return Consumer<BranchProvider>(
      builder: (context, bp, _) {
        final branchName = bp.branches.any((b) => b.id == staff.branchId)
            ? bp.branches.firstWhere((b) => b.id == staff.branchId).name
            : "N/A";

        return Center(
          child: Container(
            width: 300,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black45, blurRadius: 10, offset: const Offset(0, 5))
              ],
              border: Border.all(color: Colors.white10)
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20, top: -20,
                  child: Opacity(opacity: 0.1, child: const Icon(Icons.badge, size: 150, color: Colors.white))
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildIDCardPhoto(staff),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(staff.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(staff.position, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w500)),
                          const Spacer(),
                            _buildIDCardInfo("BRANCH", branchName),
                            _buildIDCardInfo("STAFF ID", staff.staffId),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (staff.idCardImage != null)
                             GestureDetector(
                               onTap: () => showDialog(
                                 context: context,
                                 builder: (_) => InteractiveViewer(child: Dialog(backgroundColor: Colors.transparent, child: CustomCachedImage(imageUrl: staff.idCardImage!)))
                               ),
                               child: Container(
                                 width: 50, height: 35,
                                 decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(5),
                                   boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                                 ),
                                 child: ClipRRect(
                                   borderRadius: BorderRadius.circular(5),
                                   child: CustomCachedImage(imageUrl: staff.idCardImage!, fit: BoxFit.cover),
                                 ),
                               ),
                             )
                          else
                             QrImageView(
                               data: staff.staffId,
                               version: QrVersions.auto,
                               size: 50.0,
                               eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.white),
                               dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.white),
                             ),
                          const SizedBox(height: 5),
                          const Text("VERIFIED", style: TextStyle(color: Colors.greenAccent, fontSize: 6, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIDActions(Staff staff) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
          icon: const Icon(Icons.download, size: 16),
          label: const Text("DOWNLOAD ID", style: TextStyle(fontSize: 10)),
          onPressed: () => _generateIDCardPDF(staff),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
          icon: const Icon(Icons.chat, size: 16),
          label: const Text("SEND TO STAFF", style: TextStyle(fontSize: 10)),
          onPressed: () => _sendDocumentViaWhatsApp(staff, "ID Card"),
        ),
      ],
    );
  }

  Future<void> _sendDocumentViaWhatsApp(Staff staff, String type) async {
    try {
      final branchProvider = Provider.of<BranchProvider>(context, listen: false);
      final branch = branchProvider.branches.firstWhere((b) => b.id == staff.branchId);
      
      await WhatsAppService.sendStaffDocument(
        phone: staff.phone,
        staffName: staff.name,
        documentType: type,
        branchName: branch.name,
      );
      
      if (mounted) ToastUtils.show(context, "$type sent via WhatsApp!", type: ToastType.success);
    } catch (e) {
      if (mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
    }
  }

  Widget _buildIDCardPhoto(Staff staff) {
    final image = staff.passportPhoto;
    return Container(
      width: 70, height: 90,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: image != null 
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomCachedImage(imageUrl: image, fit: BoxFit.cover),
            )
          : const Icon(Icons.person, color: Colors.white24, size: 40),
    );
  }

  Widget _buildIDCardInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        GlassContainer(
          opacity: 0.05,
          padding: const EdgeInsets.all(15),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildGuarantorSection(Staff staff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Guarantor Details", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        GlassContainer(
          opacity: 0.1,
          child: ListTile(
            leading: const Icon(Icons.security, color: Colors.blueAccent),
            title: Text(staff.guarantor?.name ?? "No Guarantor Set", style: const TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(staff.guarantor?.relationship ?? "Tap to view details", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.open_in_new, color: Colors.white24, size: 16),
            onTap: () => _showGuarantorModal(staff),
          ),
        ),
      ],
    );
  }

  void _showGuarantorModal(Staff staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: AppTheme.darkTheme,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            left: 25, right: 25, top: 25,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
          ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Guarantor Details", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white10, height: 30),
              _buildDetailRow("Full Name", staff.guarantor?.name ?? "N/A"),
              _buildDetailRow("Phone", staff.guarantor?.phone ?? "N/A"),
              _buildDetailRow("Address", staff.guarantor?.address ?? "N/A"),
              _buildDetailRow("Relationship", staff.guarantor?.relationship ?? "N/A"),
              _buildDetailRow("Occupation", staff.guarantor?.occupation ?? "N/A"),
              const SizedBox(height: 20),
              if (staff.guarantor?.idImage != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ID Card / Document", style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 8),
                    AspectRatio(
                      aspectRatio: 1.586, // Standard ID card ratio
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: CustomCachedImage(
                            imageUrl: staff.guarantor!.idImage!, 
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSalaryPerformanceSection(Staff staff) {
    return Row(
      children: [
        Expanded(
          child: _buildInfoSection("Salary System", [
            _buildDetailRow("Grade", staff.salary?.grade ?? "Level 1"),
            _buildDetailRow("Base Salary", NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(staff.salary?.baseSalary ?? 0)),
            _buildDetailRow("Cycle", staff.salary?.cycle ?? "Monthly"),
            GestureDetector(
              onTap: () => _showPaymentDialog(staff),
              child: _buildDetailRow("Status", staff.salary?.status ?? "Pending", valueColor: staff.salary?.status == 'Paid' ? Colors.green : Colors.amber),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _showPaymentHistoryModal(staff),
              child: const Text("View History", style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, decoration: TextDecoration.underline)),
            ),
            if (staff.paymentHistory.isNotEmpty) ...[
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.picture_as_pdf, size: 14),
                  label: const Text("Latest Pay Slip", style: TextStyle(fontSize: 10)),
                  onPressed: () => _generatePaySlip(staff, staff.paymentHistory.last),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Performance", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              GlassContainer(
                opacity: 0.1,
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) => Icon(
                        index < (staff.performance?.rating ?? 0) ? Icons.star : Icons.star_border,
                        color: Colors.amber, size: 20,
                      )),
                    ),
                    const SizedBox(height: 10),
                    const Text("Rating History", style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 5),
                    const Text("View Logs", style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, decoration: TextDecoration.underline)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text("Benefits", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              _buildFutureReadySection("Coming Soon"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningSection(Staff staff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Warning System", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16, color: Colors.redAccent),
              label: const Text("Issue Warning", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              onPressed: () => _showIssueWarningDialog(staff),
            ),
          ],
        ),
        if (staff.warnings.isEmpty)
           const Padding(
             padding: EdgeInsets.symmetric(vertical: 20),
             child: Center(child: Text("Consistent Performance. No Warnings.", style: TextStyle(color: Colors.green, fontSize: 12, fontStyle: FontStyle.italic))),
           )
        else
          ...staff.warnings.reversed.map((w) => _buildWarningCard(w, staff)),
      ],
    );
  }

  Widget _buildWarningCard(StaffWarning warning, Staff staff) {
    Color severityColor = warning.severity == 'Severe' ? Colors.red : (warning.severity == 'Medium' ? Colors.orange : Colors.yellow);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassContainer(
        opacity: 0.08,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: severityColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: severityColor.withValues(alpha: 0.5))),
                  child: Text(warning.severity.toUpperCase(), style: TextStyle(color: severityColor, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
                Text(DateFormat('MMM dd, yyyy').format(warning.timestamp), style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 5),
            Text(warning.reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const Divider(color: Colors.white10, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Issued by: ${warning.issuedBy ?? 'Admin'}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.green, size: 20),
                      onPressed: () => _sendWhatsAppWarning(staff, warning),
                      tooltip: "Send via WhatsApp",
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _removeWarning(staff, warning.id),
                      tooltip: "Remove Warning",
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbationSection(Staff staff) {
    final months = staff.probation?.durationMonths ?? 3;
    final employmentDate = staff.employmentDate;
    final now = DateTime.now();
    
    // Calculate if probation is over
    final probationEndDate = DateTime(
      employmentDate.year, 
      employmentDate.month + months, 
      employmentDate.day
    );
    
    final isCompleted = now.isAfter(probationEndDate);
    final status = isCompleted ? 'Completed' : (staff.probation?.status ?? 'On Probation');
    
    // Progress calculation
    double progress = 0.0;
    if (isCompleted) {
      progress = 1.0;
    } else {
      final totalDays = probationEndDate.difference(employmentDate).inDays;
      final elapsedDays = now.difference(employmentDate).inDays;
      progress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    }

    return _buildInfoSection("Probation System", [
      _buildDetailRow("Duration", "$months Months"),
      _buildDetailRow("Status", status),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : Colors.amber),
        ),
      ),
      if (!isCompleted)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${probationEndDate.difference(now).inDays} days remaining", 
                style: const TextStyle(color: Colors.white24, fontSize: 10)
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                icon: const Icon(Icons.chat, size: 12, color: Colors.white),
                label: const Text("NOTIFY WHATSAPP", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                onPressed: () => _notifyProbation(staff),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildSignatureSection(Staff staff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Digital Signature", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        GlassContainer(
          height: 250, // Even bigger
          width: double.infinity,
           opacity: 0.1,
           child: staff.signature != null && staff.signature!.isNotEmpty
             ? ClipRRect(
                 borderRadius: BorderRadius.circular(15),
                 child: InteractiveViewer(
                   panEnabled: true,
                   boundaryMargin: const EdgeInsets.all(20),
                   minScale: 0.5,
                   maxScale: 4.0,
                   child: Container(
                     color: Colors.white, // Ensure white background for contrast
                     width: double.infinity,
                     height: double.infinity,
                     alignment: Alignment.center,
                     child: staff.signature!.startsWith('data:image') 
                       ? Image.memory(base64Decode(staff.signature!.split(',').last), fit: BoxFit.contain)
                       : Image.network(staff.signature!, fit: BoxFit.contain),
                   ),
                 ),
               )
             : const Center(child: Text("No signature captured", style: TextStyle(color: Colors.white24, fontSize: 12))),
        ),
      ],
    );
  }

  Widget _buildFutureReadySection(String title) {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: Text(title, style: const TextStyle(color: Colors.white24, fontStyle: FontStyle.italic))),
    );
  }

  Widget _buildSystemActions(Staff staff) {
    return Center(
      child: Column(
        children: [
          if (staff.isArchived)
            TextButton.icon(icon: const Icon(Icons.unarchive, size: 16), label: const Text("Restore Staff (Unarchive)"), 
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor.withValues(alpha: 0.7)),
              onPressed: () => _unarchiveStaff(staff))
          else
            TextButton.icon(icon: const Icon(Icons.archive, size: 16), label: const Text("Archive Staff"), 
              style: TextButton.styleFrom(foregroundColor: Colors.white24),
              onPressed: () => _confirmArchiveStaff(staff)),
          TextButton.icon(icon: const Icon(Icons.delete_forever, size: 16), label: const Text("Permanently Delete"), 
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent.withValues(alpha: 0.5)),
            onPressed: () => _confirmPermanentDelete(staff)),
        ],
      ),
    );
  }

  Future<void> _unarchiveStaff(Staff staff) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Restore Staff Member?", style: TextStyle(color: Colors.white)),
        content: Text("Do you want to restore ${staff.name} to the active list?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("RESTORE"),
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _staffService.updateStaff(staff.id, {'isArchived': false});
      await _fetchStaff();
      if (mounted) ToastUtils.show(context, "Staff restored successfully", type: ToastType.success);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.show(context, "Error restoring staff: $e", type: ToastType.error);
      }
    }
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
      if (mounted) _fetchStaff();
    } catch (e) {
      if (mounted) ToastUtils.show(context, "Status error: $e", type: ToastType.error);
    }
  }

  Future<void> _removeWarning(Staff staff, String warningId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Remove Warning?", style: TextStyle(color: Colors.white)),
        content: const Text("This will remove the warning and restore the performance rating deduction. Continue?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("REMOVE", style: TextStyle(color: Colors.redAccent))),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _staffService.removeWarning(staff.id, warningId);
      await _fetchStaff(); // Refresh list to get updated rating
      if (mounted) ToastUtils.show(context, "Warning removed and rating restored", type: ToastType.success);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.show(context, "Failed to remove warning: $e", type: ToastType.error);
      }
    }
  }

  void _showIssueWarningDialog(Staff staff) {
    final reasonController = TextEditingController();
    final noteController = TextEditingController();
    String severity = 'Low';

    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: AppTheme.darkTheme,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Text("Issue Warning to ${staff.name}", style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogInput("Reason (e.g. Lateness)", reasonController),
                DropdownButton<String>(
                  value: severity,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  items: ['Low', 'Medium', 'Severe'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setDialogState(() => severity = val!),
                ),
                _buildDialogInput("Additional Notes", noteController, maxLines: 2),
              ],
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
                    if (mounted) _fetchStaff();
                  } catch (e) {
                    if (mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
                  }
                },
                child: const Text("ISSUE"),
              ),
            ],
          ),
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
             const Text("Staff will be marked as inactive and moved to the bottom of the list.", style: TextStyle(color: Colors.white70)),
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

     if (confirm == true && mounted) {
       try {
         await _staffService.archiveStaff(staff.id, reasonController.text);
         if (mounted) {
           _fetchStaff();
           setState(() => _selectedStaff = null);
         }
       } catch (e) {
         if (mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
       }
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

    if (confirm == true && mounted) {
      try {
        await _staffService.deleteStaff(staff.id);
        if (mounted) {
          _fetchStaff();
          setState(() => _selectedStaff = null);
          ToastUtils.show(context, "Staff permanently deleted", type: ToastType.success);
        }
      } catch (e) {
        if (mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
      }
    }
  }

  void _showMobileStaffDetails(Staff staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101020),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => Theme(
        data: AppTheme.darkTheme,
        child: SizedBox(height: MediaQuery.of(context).size.height * 0.9, child: _buildStaffProfile(staff, false)),
      ),
    );
  }

  void _showPaymentDialog(Staff staff) {
    final amountController = TextEditingController(text: (staff.salary?.baseSalary ?? 0).toStringAsFixed(0));
    final refController = TextEditingController(text: "PAY-${DateFormat('yyyyMM').format(DateTime.now())}");
    String method = 'Transfer';

    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: AppTheme.darkTheme,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text("Record Salary Payment", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogInput("Amount (₦)", amountController, keyboard: TextInputType.number),
                  const SizedBox(height: 15),
                  const Text("Payment Method", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  DropdownButton<String>(
                    value: method,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A2E),
                    style: const TextStyle(color: Colors.white),
                    items: ['Cash', 'Transfer'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setDialogState(() => method = val!),
                  ),
                  const SizedBox(height: 15),
                  _buildDialogInput("Reference / Month", refController),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => _recordPayment(staff.id, double.tryParse(amountController.text) ?? 0, method, refController.text),
                child: const Text("RECORD PAID", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordPayment(String staffId, double amount, String method, String reference) async {
    Navigator.pop(context); // Close dialog
    setState(() => _isLoading = true);
    try {
      await _staffService.recordPayment(staffId, amount, method, reference);
      await _fetchStaff(); // Refresh data
      if (mounted) ToastUtils.show(context, "Payment Recorded Successfully", type: ToastType.success);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.show(context, "Failed to record payment: $e", type: ToastType.error);
      }
    }
  }

  void _showPaymentHistoryModal(Staff staff) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Theme(
        data: AppTheme.darkTheme,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Payment History", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              if (staff.paymentHistory.isEmpty)
                const Expanded(child: Center(child: Text("No payment records found", style: TextStyle(color: Colors.white24))))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: staff.paymentHistory.length,
                    itemBuilder: (ctx, index) {
                      final p = staff.paymentHistory[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.reference ?? "Salary Payment", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(DateFormat('MMM dd, yyyy').format(p.date), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(p.amount), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                Text(p.status, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _notifyProbation(Staff staff) async {
    try {
      final branchProvider = Provider.of<BranchProvider>(context, listen: false);
      final branch = branchProvider.branches.firstWhere((b) => b.id == staff.branchId);
      await WhatsAppService.sendProbationAnnouncement(
        phone: staff.phone,
        staffName: staff.name,
        branchName: branch.name,
      );
      if (mounted) ToastUtils.show(context, "Probation notification sent!", type: ToastType.success);
    } catch (e) {
      if (mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
    }
  }

  Future<void> _generatePaySlip(Staff staff, StaffPayment payment) async {
    try {
      final branchProvider = Provider.of<BranchProvider>(context, listen: false);
      final branch = branchProvider.branches.firstWhere((b) => b.id == staff.branchId);
      await StaffPdfService.generatePaySlip(staff: staff, branch: branch, payment: payment);
    } catch (e) {
       if (mounted) ToastUtils.show(context, "PDF Error: $e", type: ToastType.error);
    }
  }

  Widget _buildAgreementSection(Staff staff) {
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final branchName = branchProvider.branches.any((b) => b.id == staff.branchId)
        ? branchProvider.branches.firstWhere((b) => b.id == staff.branchId).name
        : "N/A";
    
    final isAbuja = branchName.toLowerCase().contains('abuja');
    final companyName = isAbuja ? 'Brimarck Cleaning Services' : 'Clotheline Services';
    final ceoName = isAbuja ? 'Mrs Natalie Usigbe Izuwagbe' : 'Mr Martins Usigbe';

    // Probation logic
    final months = staff.probation?.durationMonths ?? 3;
    final probationEndDate = DateTime(staff.employmentDate.year, staff.employmentDate.month + months, staff.employmentDate.day);
    final isProbationOver = DateTime.now().isAfter(probationEndDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Contract Agreement", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        GlassContainer(
          opacity: 0.1,
          child: ExpansionTile(
            title: const Text("View Service Agreement", style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(isProbationOver ? "Ready for signing" : "Locked during probation", 
              style: TextStyle(color: isProbationOver ? Colors.green : Colors.white24, fontSize: 12)),
            leading: Icon(Icons.description, color: isProbationOver ? Colors.green : Colors.white24),
            childrenPadding: const EdgeInsets.all(15),
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CONTRACT AGREEMENT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      "We are pleased to offer you a contract as a ${staff.position} at $companyName. "
                      "Your commencement date takes effect from ${DateFormat('dd MMMM yyyy').format(staff.employmentDate)}.\n\n"
                      "Key Terms:\n"
                      "● Annual Salary: ₦720,000\n"
                      "● Probation: 3 Months\n"
                      "● Working Days: Mon-Sat (8am-6pm)\n"
                      "● Resignation: 30 days written notice required.\n\n"
                      "Confidentiality: You must maintain complete confidentiality about clients and the company.",
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Divider(color: Colors.white10, height: 30),
                    if (isProbationOver) ...[
                       if (staff.signature == null)
                         SizedBox(
                           width: double.infinity,
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                             onPressed: () => _showSigningInterface(staff),
                             child: const Text("SIGN AGREEMENT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                           ),
                         )
                       else
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             const Text("SIGNED ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                             IconButton(
                               icon: const Icon(Icons.picture_as_pdf, color: AppTheme.primaryColor),
                               onPressed: () => _generateAgreementPDF(staff),
                               tooltip: "Download PDF",
                             ),
                             IconButton(
                               icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                               onPressed: () => _sendDocumentViaWhatsApp(staff, "Contract Agreement"),
                               tooltip: "Send via WhatsApp",
                             ),
                           ],
                         )
                    ] else
                       const Center(child: Text("Agreement can only be signed after 3 months probation.", 
                         style: TextStyle(color: Colors.amber, fontSize: 10, fontStyle: FontStyle.italic))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSigningInterface(Staff staff) {
    // This would typically lead to a signing screen
    ToastUtils.show(context, "Please use the 'Edit Staff' screen to capture a signature first.", type: ToastType.info);
  }

  Future<void> _generateAgreementPDF(Staff staff) async {
    try {
      final branchProvider = Provider.of<BranchProvider>(context, listen: false);
      final branch = branchProvider.branches.firstWhere((b) => b.id == staff.branchId);
      await StaffPdfService.generateAgreement(
        staff: staff, 
        branch: branch, 
        signingDate: DateFormat('dd MMMM yyyy').format(DateTime.now())
      );
    } catch (e) {
      if (mounted) ToastUtils.show(context, "PDF Error: $e", type: ToastType.error);
    }
  }

  Future<void> _generateIDCardPDF(Staff staff) async {
    try {
      final branchProvider = Provider.of<BranchProvider>(context, listen: false);
      final branch = branchProvider.branches.firstWhere((b) => b.id == staff.branchId);
      await StaffPdfService.generateIDCard(staff: staff, branch: branch);
    } catch (e) {
      if (mounted) ToastUtils.show(context, "PDF Error: $e", type: ToastType.error);
    }
  }

  Widget _buildDialogInput(String label, TextEditingController controller, {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
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
