import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../models/staff_model.dart';
import '../../../models/branch_model.dart';
import '../../../services/staff_service.dart';
import '../../../providers/branch_provider.dart';
import '../../../utils/toast_utils.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

class AdminEditStaffScreen extends StatefulWidget {
  final Staff? staff;
  final Branch? branch;

  const AdminEditStaffScreen({super.key, this.staff, this.branch});

  @override
  State<AdminEditStaffScreen> createState() => _AdminEditStaffScreenState();
}

class _AdminEditStaffScreenState extends State<AdminEditStaffScreen> {
  final StaffService _staffService = StaffService();
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _posController;
  DateTime _employmentDate = DateTime.now();
  Branch? _selectedBranch;

  // Bank Details
  late TextEditingController _bankNameController;
  late TextEditingController _accNumController;
  late TextEditingController _accNameController;

  // Guarantor
  late TextEditingController _gNameController;
  late TextEditingController _gPhoneController;
  late TextEditingController _gAddrController;
  late TextEditingController _gRelController;
  late TextEditingController _gOccController;
  String? _gIdImage;

  // Salary & Probation
  String _salaryGrade = 'Level 1';
  late TextEditingController _baseSalaryController;
  String _paymentCycle = 'Monthly';
  int _probationMonths = 3;

  String? _passportPhoto;
  String? _signatureBase64;
  bool _isSaving = false;
  bool _isUploadingPassport = false;
  bool _isUploadingGuarantor = false;
  bool _isUploadingIdCard = false;
  String? _idCardImage;
  String _salaryStatus = 'Pending';

  final NumberFormat _currencyFormat = NumberFormat("#,##0", "en_US");

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _nameController = TextEditingController(text: s?.name);
    _emailController = TextEditingController(text: s?.email);
    _phoneController = TextEditingController(text: s?.phone);
    _addressController = TextEditingController(text: s?.address);
    _posController = TextEditingController(text: s?.position);
    _employmentDate = s?.employmentDate ?? DateTime.now();
    
    _bankNameController = TextEditingController(text: s?.bankDetails?.bankName);
    _accNumController = TextEditingController(text: s?.bankDetails?.accountNumber);
    _accNameController = TextEditingController(text: s?.bankDetails?.accountName);

    _gNameController = TextEditingController(text: s?.guarantor?.name);
    _gPhoneController = TextEditingController(text: s?.guarantor?.phone);
    _gAddrController = TextEditingController(text: s?.guarantor?.address);
    _gRelController = TextEditingController(text: s?.guarantor?.relationship);
    _gOccController = TextEditingController(text: s?.guarantor?.occupation);
    _gIdImage = s?.guarantor?.idImage;

    _salaryGrade = s?.salary?.grade ?? 'Level 1';
    final baseSal = s?.salary?.baseSalary ?? 0;
    _baseSalaryController = TextEditingController(text: _currencyFormat.format(baseSal));
    _paymentCycle = s?.salary?.cycle ?? 'Monthly';
    _salaryStatus = s?.salary?.status ?? 'Pending';
    _probationMonths = s?.probation?.durationMonths ?? 3;

    _passportPhoto = s?.passportPhoto;
    _idCardImage = s?.idCardImage;
    _signatureBase64 = s?.signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final branchProvider = Provider.of<BranchProvider>(context, listen: false);
      setState(() {
        if (s != null) {
          _selectedBranch = branchProvider.branches.any((b) => b.id == s.branchId)
              ? branchProvider.branches.firstWhere((b) => b.id == s.branchId)
              : widget.branch ?? branchProvider.selectedBranch;
        } else {
          _selectedBranch = widget.branch ?? branchProvider.selectedBranch;
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _posController.dispose();
    _bankNameController.dispose();
    _accNumController.dispose();
    _accNameController.dispose();
    _gNameController.dispose();
    _gPhoneController.dispose();
    _gAddrController.dispose();
    _gRelController.dispose();
    _gOccController.dispose();
    _baseSalaryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int type) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() {
        if (type == 0) _isUploadingPassport = true;
        else if (type == 1) _isUploadingGuarantor = true;
        else _isUploadingIdCard = true;
      });
      try {
        final url = await _staffService.uploadImage(image.path);
        if (url != null) {
          setState(() {
            if (type == 0) _passportPhoto = url;
            else if (type == 1) _gIdImage = url;
            else _idCardImage = url; // Type 2 = ID Card
          });
          ToastUtils.show(context, "Image Uploaded", type: ToastType.success);
        }
      } catch (e) {
        ToastUtils.show(context, "Upload Failed: $e", type: ToastType.error);
      } finally {
        setState(() {
          if (type == 0) _isUploadingPassport = false;
          else if (type == 1) _isUploadingGuarantor = false;
          else _isUploadingIdCard = false;
        });
      }
    }
  }

  Future<void> _showSignatureModal() async {
    final SignatureController sigController = SignatureController(
      penStrokeWidth: 4,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    final Uint8List? signature = await showDialog<Uint8List>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Column(
          children: [
            AppBar(
              title: const Text("Capture Signature", style: TextStyle(color: Colors.black)),
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (sigController.isEmpty) {
                      Navigator.pop(context);
                      return;
                    }
                    final data = await sigController.toPngBytes();
                    Navigator.pop(context, data);
                  },
                  child: const Text("DONE", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Text("Please sign horizontally in the box below", style: TextStyle(color: Colors.black38, fontSize: 14)),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: AspectRatio(
                    aspectRatio: 2.0, // Landscape box
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Signature(
                          controller: sigController,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: TextButton.icon(
                onPressed: () => sigController.clear(),
                icon: const Icon(Icons.refresh, color: Colors.blue),
                label: const Text("Clear and Restart", style: TextStyle(color: Colors.blue)),
              ),
            ),
          ],
        ),
      ),
    );

    if (signature != null) {
      setState(() {
        _signatureBase64 = "data:image/png;base64,${base64Encode(signature)}";
      });
      ToastUtils.show(context, "Signature Captured", type: ToastType.success);
    }
    sigController.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranch == null) {
      ToastUtils.show(context, "Please select a branch", type: ToastType.info);
      return;
    }

    setState(() => _isSaving = true);

    // Clean base salary (remove commas)
    final salaryStr = _baseSalaryController.text.replaceAll(',', '');
    final baseSalary = double.tryParse(salaryStr) ?? 0;

    print("Submitting Employment Date: ${_employmentDate.toIso8601String()}");

    if (_selectedBranch == null) {
      ToastUtils.show(context, "Please select a branch first", type: ToastType.warning);
      return;
    }

    final data = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'position': _posController.text,
      'branchId': _selectedBranch!.id,
      'employmentDate': _employmentDate.toIso8601String(),
      'passportPhoto': _passportPhoto,
      'idCardImage': _idCardImage,
      'signature': _signatureBase64,
      'bankDetails': {
        'bankName': _bankNameController.text,
        'accountNumber': _accNumController.text,
        'accountName': _accNameController.text,
      },
      'guarantor': {
        'name': _gNameController.text,
        'phone': _gPhoneController.text,
        'address': _gAddrController.text,
        'relationship': _gRelController.text,
        'occupation': _gOccController.text,
        'idImage': _gIdImage,
      },
      'salary': {
        'grade': _salaryGrade,
        'baseSalary': baseSalary,
        'cycle': _paymentCycle,
        'status': _salaryStatus,
      },
      'probation': {
        'durationMonths': _probationMonths,
        'status': 'On Probation',
      }
    };

    try {
      if (widget.staff == null) {
        await _staffService.createStaff(data);
        ToastUtils.show(context, "Staff created successfully", type: ToastType.success);
      } else {
        await _staffService.updateStaff(widget.staff!.id, data);
        ToastUtils.show(context, "Staff updated successfully", type: ToastType.success);
      }
      Navigator.pop(context, true);
    } catch (e) {
      String errorMsg = e.toString();
      if (e is DioException && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map && data.containsKey('msg')) {
          errorMsg = data['msg'];
        } else if (data is String) {
          errorMsg = data;
        }
      }
      setState(() => _isSaving = false);
      ToastUtils.show(context, "Error: $errorMsg", type: ToastType.error);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(widget.staff == null ? "New Staff Profile" : "Edit Profile", 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (_isSaving)
              const Center(child: Padding(padding: EdgeInsets.only(right: 20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
            else
              TextButton(
                onPressed: _submit,
                child: const Text("SAVE", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 10),
          ],
        ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 100, bottom: 50, left: 20, right: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Basic Information"),
                const SizedBox(height: 15),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(children: [const Text("Passport", style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 5), _buildPassportPicker()]),
                    const SizedBox(width: 20),
                    Column(children: [const Text("Staff ID Card", style: TextStyle(color: Colors.white54, fontSize: 12)), const SizedBox(height: 5), _buildIdCardPicker()]),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInput("Full Name", _nameController, Icons.person, required: true),
                _buildInput("Phone Number", _phoneController, Icons.phone, required: true, keyboard: TextInputType.phone),
                _buildInput("Email (Optional)", _emailController, Icons.email),
                _buildInput("Residential Address", _addressController, Icons.home, maxLines: 2),
                _buildDropdown("Position", _posController.text, [
                  'Manager', 'Supervisor', 'Secretary', 'POS Attendant', 'Laundry Worker', 'Dispatch'
                ], (val) => setState(() => _posController.text = val!)),
                _buildBranchPicker(),
                _buildDateListSelector("Employment Date", _employmentDate, (date) => setState(() => _employmentDate = date)),

                const SizedBox(height: 30),
                _buildSectionHeader("Account Details"),
                const SizedBox(height: 15),
                _buildInput("Bank Name", _bankNameController, Icons.account_balance),
                _buildInput("Account Number", _accNumController, Icons.numbers),
                _buildInput("Account Name", _accNameController, Icons.badge),

                const SizedBox(height: 30),
                _buildSectionHeader("Guarantor Details"),
                const SizedBox(height: 15),
                _buildInput("Guarantor Name", _gNameController, Icons.security),
                _buildInput("Guarantor Phone", _gPhoneController, Icons.phone_android),
                _buildInput("Relationship", _gRelController, Icons.people),
                _buildInput("Occupation", _gOccController, Icons.work),
                _buildInput("Address", _gAddrController, Icons.home, maxLines: 2),
                const SizedBox(height: 10),
                _buildGuarantorIDPicker(),

                const SizedBox(height: 30),
                _buildSectionHeader("Salary & Probation"),
                const SizedBox(height: 15),
                _buildDropdown("Salary Grade", _salaryGrade, ['Level 1', 'Level 2', 'Level 3', 'Level 4', 'Level 5'], (val) => setState(() => _salaryGrade = val!)),
                _buildSalaryInput(),
                _buildDropdown("Payment Cycle", _paymentCycle, ['Monthly', 'Weekly'], (val) => setState(() => _paymentCycle = val!)),
                _buildDropdown("Probation (Months)", "$_probationMonths", ['1', '3', '6', '12'], (val) => setState(() => _probationMonths = int.parse(val!))),

                const SizedBox(height: 30),
                _buildSectionHeader("Signature"),
                const SizedBox(height: 15),
                _buildSignatureCaptureBtn(),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {bool required = false, TextInputType keyboard = TextInputType.text, int maxLines = 1, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GlassContainer(
        opacity: 0.1,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: TextFormField(
          controller: ctrl,
          onChanged: onChanged,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            icon: Icon(icon, color: Colors.white38, size: 20),
            labelText: label,
            labelStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          validator: required ? (v) => (v == null || v.isEmpty) ? "Required" : null : null,
        ),
      ),
    );
  }

  Widget _buildSalaryInput() {
    return _buildInput(
      "Base Salary", 
      _baseSalaryController, 
      Icons.money, 
      keyboard: TextInputType.number,
      onChanged: (val) {
        if (val.isEmpty) return;
        final clean = val.replaceAll(',', '');
        final parsed = int.tryParse(clean);
        if (parsed != null) {
          final formatted = _currencyFormat.format(parsed);
          _baseSalaryController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      }
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GlassContainer(
        opacity: 0.1,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: onChanged,
          dropdownColor: const Color(0xFF1E1E2C),
          decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white54), border: InputBorder.none),
        ),
      ),
    );
  }

  Widget _buildBranchPicker() {
    return Consumer<BranchProvider>(
      builder: (context, bp, _) {
        final List<Branch> branches = bp.branches;
        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: GlassContainer(
            opacity: 0.1,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: DropdownButtonFormField<String>(
              value: branches.any((b) => b.id == _selectedBranch?.id) ? _selectedBranch?.id : (branches.isNotEmpty ? branches.first.id : null),
              items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (id) {
                setState(() => _selectedBranch = branches.firstWhere((b) => b.id == id));
              },
              dropdownColor: const Color(0xFF1E1E2C),
              decoration: const InputDecoration(labelText: "Branch", labelStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateListSelector(String label, DateTime currentDate, Function(DateTime) onChanged) {
    // Generate lists
    final days = List.generate(31, (index) => (index + 1).toString());
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final currentYear = DateTime.now().year;
    final years = List.generate(50, (index) => (currentYear - index).toString()); // Last 50 years

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            // Day
            Expanded(
              flex: 2,
              child: _buildSimpleDropdown(
                currentDate.day.toString(), 
                days, 
                (val) {
                  final newDay = int.parse(val!);
                  // Handle month length overflow (e.g. Feb 30)
                  final lastDayOfMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;
                  final validDay = newDay > lastDayOfMonth ? lastDayOfMonth : newDay;
                  onChanged(DateTime(currentDate.year, currentDate.month, validDay));
                }
              ),
            ),
            const SizedBox(width: 10),
            // Month
            Expanded(
              flex: 3,
              child: _buildSimpleDropdown(
                months[currentDate.month - 1], 
                months, 
                (val) {
                  final newMonth = months.indexOf(val!) + 1;
                  // Handle day overflow when switching months
                  final lastDayOfNewMonth = DateTime(currentDate.year, newMonth + 1, 0).day;
                  final validDay = currentDate.day > lastDayOfNewMonth ? lastDayOfNewMonth : currentDate.day;
                  onChanged(DateTime(currentDate.year, newMonth, validDay));
                }
              ),
            ),
            const SizedBox(width: 10),
            // Year
            Expanded(
              flex: 3,
              child: _buildSimpleDropdown(
                currentDate.year.toString(), 
                years, 
                (val) {
                  final newYear = int.parse(val!);
                  // Handle leap year overflow (Feb 29)
                  final lastDayOfNewMonth = DateTime(newYear, currentDate.month + 1, 0).day;
                  final validDay = currentDate.day > lastDayOfNewMonth ? lastDayOfNewMonth : currentDate.day;
                  onChanged(DateTime(newYear, currentDate.month, validDay));
                }
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildSimpleDropdown(String value, List<String> items, Function(String?) onChanged) {
    // Ensure value is in list, otherwise add it temporarily or specific handling
    final effectiveItems = items.contains(value) ? items : [value, ...items];
    
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        items: effectiveItems.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
        onChanged: onChanged,
        dropdownColor: const Color(0xFF1E1E2C),
        decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
        isExpanded: true,
      ),
    );
  }

  Widget _buildPassportPicker() {
    return Center(
      child: GestureDetector(
        onTap: () => _pickImage(0),
        child: Container(
          width: 100, height: 120,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
            image: _passportPhoto != null ? DecorationImage(image: NetworkImage(_passportPhoto!), fit: BoxFit.cover) : null
          ),
          child: _isUploadingPassport 
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : (_passportPhoto == null ? const Icon(Icons.add_a_photo, color: Colors.white38, size: 30) : null),
        ),
      ),
    );
  }

  Widget _buildIdCardPicker() {
    return Center(
      child: GestureDetector(
        onTap: () => _pickImage(2),
        child: Container(
          width: 100, height: 120,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
            image: _idCardImage != null ? DecorationImage(image: NetworkImage(_idCardImage!), fit: BoxFit.cover) : null
          ),
          child: _isUploadingIdCard 
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : (_idCardImage == null ? const Icon(Icons.badge, color: Colors.white38, size: 30) : null),
        ),
      ),
    );
  }

  Widget _buildGuarantorIDPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Guarantor ID Image", style: TextStyle(color: Colors.white70, fontSize: 13)),
          trailing: _isUploadingGuarantor 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_a_photo, color: AppTheme.primaryColor),
          onTap: () => _pickImage(1),
        ),
        if (_gIdImage != null)
           Container(height: 100, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), 
             image: DecorationImage(image: NetworkImage(_gIdImage!), fit: BoxFit.cover))),
      ],
    );
  }

  Widget _buildSignatureCaptureBtn() {
    return Column(
      children: [
        GestureDetector(
          onTap: _showSignatureModal,
          child: GlassContainer(
            height: 100,
            width: double.infinity,
            opacity: 0.1,
            child: _signatureBase64 != null 
              ? Image.memory(base64Decode(_signatureBase64!.split(',').last), fit: BoxFit.contain)
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note, color: Colors.white38, size: 30),
                      SizedBox(height: 5),
                      Text("Tap to Capture Signature", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
          ),
        ),
        if (_signatureBase64 != null)
           Padding(
             padding: const EdgeInsets.only(top: 10),
             child: TextButton(onPressed: _showSignatureModal, child: const Text("Resign", style: TextStyle(color: AppTheme.primaryColor))),
           ),
      ],
    );
  }
}
