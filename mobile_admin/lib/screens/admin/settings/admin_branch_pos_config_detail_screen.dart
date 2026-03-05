import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clotheline_admin/widgets/glass/LiquidBackground.dart';
import 'package:clotheline_admin/widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/utils/money_formatter.dart';

class AdminBranchPosConfigDetailScreen extends StatefulWidget {
  final Branch branch;
  const AdminBranchPosConfigDetailScreen({super.key, required this.branch});

  @override
  State<AdminBranchPosConfigDetailScreen> createState() => _AdminBranchPosConfigDetailScreenState();
}

class _AdminBranchPosConfigDetailScreenState extends State<AdminBranchPosConfigDetailScreen> {
  bool _isLoading = false;

  // Controllers
  late TextEditingController _displayNameCtrl;
  late TextEditingController _withdrawalCtrl;
  late TextEditingController _transferCtrl;
  late TextEditingController _depositCtrl;
  late TextEditingController _profitTargetCtrl;
  late TextEditingController _openingCashCtrl;

  // Toggles
  late bool _smartTiersEnabled;
  late bool _profitTargetEnabled;
  late bool _lockAfter24h;
  late bool _masterAdminOnly;
  late bool _requireReconciliation;
  late bool _requireDeleteConfirmation;

  // Smart Tiers
  List<SmartTier> _smartTiers = [];
  late String _opayTier;

  @override
  void initState() {
    super.initState();
    final config = widget.branch.posConfig;
    
    _displayNameCtrl = TextEditingController(text: config?.terminalDisplayName ?? "");
    _withdrawalCtrl = TextEditingController(text: (config?.charges.withdrawal ?? 0).toStringAsFixed(0));
    _transferCtrl = TextEditingController(text: (config?.charges.transfer ?? 0).toStringAsFixed(0));
    _depositCtrl = TextEditingController(text: (config?.charges.deposit ?? 0).toStringAsFixed(0));
    _profitTargetCtrl = TextEditingController(text: (config?.profitTarget.amount ?? 0).toStringAsFixed(0));
    _openingCashCtrl = TextEditingController(text: (config?.defaultOpeningCash ?? 0).toStringAsFixed(0));

    _smartTiersEnabled = config?.charges.smartTiersEnabled ?? false;
    _profitTargetEnabled = config?.profitTarget.enabled ?? false;
    _lockAfter24h = config?.security.lockAfter24h ?? false;
    _masterAdminOnly = config?.security.masterAdminOnly ?? false;
    _requireReconciliation = config?.security.requireReconciliation ?? false;
    _requireDeleteConfirmation = config?.security.requireDeleteConfirmation ?? true;

    _smartTiers = List.from(config?.charges.smartTiers ?? []);
    _opayTier = config?.charges.opayTier ?? 'Regular';
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _withdrawalCtrl.dispose();
    _transferCtrl.dispose();
    _depositCtrl.dispose();
    _profitTargetCtrl.dispose();
    _openingCashCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final api = ApiService();
      final data = {
        'posConfig': {
          'terminalDisplayName': _displayNameCtrl.text,
          'charges': {
            'withdrawal': MoneyTextInputFormatter.getNumericValue(_withdrawalCtrl.text),
            'transfer': MoneyTextInputFormatter.getNumericValue(_transferCtrl.text),
            'deliveryDeposit': MoneyTextInputFormatter.getNumericValue(_depositCtrl.text),
            'opayTier': _opayTier,
            'smartTiersEnabled': _smartTiersEnabled,
            'smartTiers': _smartTiers.map((t) => {'min': t.min, 'max': t.max, 'charge': t.charge}).toList(),
          },
          'profitTarget': {
            'enabled': _profitTargetEnabled,
            'amount': MoneyTextInputFormatter.getNumericValue(_profitTargetCtrl.text),
          },
          'security': {
            'lockAfter24h': _lockAfter24h,
            'masterAdminOnly': _masterAdminOnly,
            'requireReconciliation': _requireReconciliation,
            'requireDeleteConfirmation': _requireDeleteConfirmation,
          },
          'defaultOpeningCash': MoneyTextInputFormatter.getNumericValue(_openingCashCtrl.text),
        }
      };

      final response = await api.client.put('/branches/${widget.branch.id}', data: data);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ToastUtils.show(context, "Configuration Saved", type: ToastType.success);
        Provider.of<BranchProvider>(context, listen: false).fetchBranches();
        Navigator.pop(context);
      } else {
        throw Exception("Failed to save configuration");
      }
    } catch (e) {
      if (!mounted) return;
      ToastUtils.show(context, "Error saving: $e", type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("${widget.branch.name} Configuration", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check, color: AppTheme.secondaryColor),
              onPressed: _saveConfig,
            ),
          const SizedBox(width: 10),
        ],
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildSectionHeader("Terminal Metadata"),
                    _buildTerminalMetadataCard(),
                    const SizedBox(height: 20),

                    _buildSectionHeader("Charge Configuration"),
                    _buildChargeConfigCard(),
                    const SizedBox(height: 20),

                    _buildSectionHeader("Daily Profit Target"),
                    _buildProfitTargetCard(),
                    const SizedBox(height: 20),

                    _buildSectionHeader("Security & Controls"),
                    _buildSecurityCard(),
                    const SizedBox(height: 20),

                    _buildSectionHeader("Default Opening Cash"),
                    _buildOpeningCashCard(),
                    const SizedBox(height: 20),

                    _buildSectionHeader("OPay Fee Reference"),
                    _buildOPayFeeTable(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildTerminalMetadataCard() {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(15),
      child: _buildTextField(_displayNameCtrl, "Terminal Display Name", Icons.devices),
    );
  }

  Widget _buildChargeConfigCard() {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          _buildMoneyField(_withdrawalCtrl, "Withdrawal Charge", Icons.arrow_upward),
          const SizedBox(height: 10),
          _buildMoneyField(_transferCtrl, "Transfer Charge", Icons.swap_horiz),
          const SizedBox(height: 10),
          _buildMoneyField(_depositCtrl, "Deposit Charge", Icons.arrow_downward),
          const Divider(color: Colors.white10, height: 30),
          _buildDropdownRow("OPay Fee Tier", _opayTier, ['Platinum', 'Gold', 'Regular'], (val) => setState(() => _opayTier = val!)),
          const Divider(color: Colors.white10, height: 30),
          _buildToggleRow("Enable Smart Charge Tiers", _smartTiersEnabled, (val) => setState(() => _smartTiersEnabled = val)),
          if (_smartTiersEnabled) ...[
            const SizedBox(height: 15),
            ..._smartTiers.asMap().entries.map((entry) => _buildTierRow(entry.key, entry.value)),
            const SizedBox(height: 10),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Add Tier Row", style: TextStyle(fontSize: 12)),
              onPressed: () => setState(() => _smartTiers.add(SmartTier(min: 0, max: 0, charge: 0))),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String title, String value, List<String> options, Function(String?) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 13, fontWeight: FontWeight.bold),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOPayFeeTable() {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          _buildFeeTableHeader(),
          const Divider(color: Colors.white10),
          _buildFeeTableRow("1 - 3,000", "0.43%", "0.45%", "0.5%"),
          _buildFeeTableRow("3,001 - 4,000", "₦17.00", "₦18.00", "₦20.00"),
          _buildFeeTableRow("4,001 - 5,000", "₦21.25", "₦22.50", "₦25.00"),
          _buildFeeTableRow("5,001 - 6,000", "₦25.55", "₦27.00", "₦30.00"),
          _buildFeeTableRow("6,001 - 7,000", "₦29.75", "₦31.50", "₦35.00"),
          _buildFeeTableRow("7,001 - 8,000", "₦34.00", "₦36.00", "₦40.00"),
          _buildFeeTableRow("8,001 - 9,000", "₦38.25", "₦40.50", "₦45.00"),
          _buildFeeTableRow("9,001 - 10,000", "₦42.25", "₦45.00", "₦50.00"),
          _buildFeeTableRow("10,001 - 11,000", "₦46.75", "₦49.50", "₦55.00"),
          _buildFeeTableRow("11,001 - 12,000", "₦51.00", "₦54.00", "₦60.00"),
          _buildFeeTableRow("12,001 - 13,000", "₦55.25", "₦58.50", "₦65.00"),
          _buildFeeTableRow("13,001 - 14,000", "₦59.50", "₦63.00", "₦70.00"),
          _buildFeeTableRow("14,001 - 15,000", "₦63.75", "₦67.50", "₦75.00"),
          _buildFeeTableRow("15,001 - 16,000", "₦68.00", "₦72.00", "₦80.00"),
          _buildFeeTableRow("16,001 - 17,000", "₦72.25", "₦76.50", "₦85.00"),
          _buildFeeTableRow("17,001 - 18,000", "₦76.50", "₦81.00", "₦90.00"),
          _buildFeeTableRow("18,001 - 19,000", "₦80.75", "₦85.50", "₦95.00"),
          _buildFeeTableRow("19,001 - 20,000", "₦85.00", "₦90.00", "₦100.00"),
          _buildFeeTableRow("20,000+", "₦85.00", "₦90.00", "₦100.00"),
          const SizedBox(height: 10),
          const Text(
            "* System automatically applies these rates based on the selected tier.",
            style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
          )
        ],
      ),
    );
  }

  Widget _buildFeeTableHeader() {
    return const Row(
      children: [
        Expanded(flex: 2, child: Text("Range", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
        Expanded(child: Text("Plat", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        Expanded(child: Text("Gold", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        Expanded(child: Text("Reg", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
      ],
    );
  }

  Widget _buildFeeTableRow(String range, String plat, String gold, String reg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(range, style: const TextStyle(color: Colors.white70, fontSize: 11))),
          Expanded(child: Text(plat, style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center)),
          Expanded(child: Text(gold, style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center)),
          Expanded(child: Text(reg, style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTierRow(int index, SmartTier tier) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: _buildSmallMoneyField("Min", (val) => _updateTier(index, min: val), initialValue: tier.min)),
          const SizedBox(width: 5),
          Expanded(child: _buildSmallMoneyField("Max", (val) => _updateTier(index, max: val), initialValue: tier.max)),
          const SizedBox(width: 5),
          Expanded(child: _buildSmallMoneyField("Charge", (val) => _updateTier(index, charge: val), initialValue: tier.charge)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
            onPressed: () => setState(() => _smartTiers.removeAt(index)),
          )
        ],
      ),
    );
  }

  void _updateTier(int index, {double? min, double? max, double? charge}) {
    setState(() {
      final old = _smartTiers[index];
      _smartTiers[index] = SmartTier(
        min: min ?? old.min,
        max: max ?? old.max,
        charge: charge ?? old.charge,
      );
    });
  }

  Widget _buildProfitTargetCard() {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          _buildToggleRow("Enable Daily Target", _profitTargetEnabled, (val) => setState(() => _profitTargetEnabled = val)),
          if (_profitTargetEnabled) ...[
            const SizedBox(height: 15),
            _buildMoneyField(_profitTargetCtrl, "Target Amount", Icons.track_changes),
          ]
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(15),
      child: Column(
        children: [
          _buildToggleRow("Lock transactions after 24h", _lockAfter24h, (val) => setState(() => _lockAfter24h = val)),
          _buildToggleRow("Restrict edit/delete to Master Admin", _masterAdminOnly, (val) => setState(() => _masterAdminOnly = val)),
          _buildToggleRow("Require daily reconciliation", _requireReconciliation, (val) => setState(() => _requireReconciliation = val)),
          _buildToggleRow("Require delete confirmation", _requireDeleteConfirmation, (val) => setState(() => _requireDeleteConfirmation = val)),
        ],
      ),
    );
  }

  Widget _buildOpeningCashCard() {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(15),
      child: _buildMoneyField(_openingCashCtrl, "Default Opening Cash", Icons.account_balance_wallet_outlined),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      ),
    );
  }

  Widget _buildMoneyField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [MoneyTextInputFormatter()],
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      ),
    );
  }

  Widget _buildSmallMoneyField(String hint, Function(double) onChanged, {double initialValue = 0}) {
    return TextField(
      keyboardType: TextInputType.number,
      inputFormatters: [MoneyTextInputFormatter()],
      controller: TextEditingController(text: initialValue > 0 ? initialValue.toStringAsFixed(0) : "")..selection = TextSelection.collapsed(offset: initialValue > 0 ? initialValue.toStringAsFixed(0).length : 0),
      onChanged: (val) => onChanged(MoneyTextInputFormatter.getNumericValue(val)),
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
    );
  }

  Widget _buildToggleRow(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Switch(
            value: value,
            activeColor: AppTheme.secondaryColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
