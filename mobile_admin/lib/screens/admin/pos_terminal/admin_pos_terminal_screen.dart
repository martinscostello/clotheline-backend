import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:clotheline_admin/widgets/glass/LiquidBackground.dart';
import 'package:clotheline_admin/widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:clotheline_core/utils/money_formatter.dart';

class AdminPosTerminalScreen extends StatefulWidget {
  const AdminPosTerminalScreen({super.key});

  @override
  State<AdminPosTerminalScreen> createState() => _AdminPosTerminalScreenState();
}

class _AdminPosTerminalScreenState extends State<AdminPosTerminalScreen> {
  bool _isLoading = true;
  String? _error;
  
  String? _selectedBranchId;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  Map<String, dynamic> _metrics = {
    'totalTransactions': 0,
    'totalVolume': 0,
    'totalCharges': 0,
    'totalDeposits': 0,
    'totalWithdrawals': 0,
  };
  List<dynamic> _transactions = [];

  // Add Transaction Form
  final _amountCtrl = TextEditingController();
  final _chargesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _transactionType = 'Withdrawal';
  String _chargeMode = 'Included In Transaction'; // [NEW]
  bool _isUnresolved = false; // [NEW]
  bool _isSaving = false;

  // Recon
  final _openingCashCtrl = TextEditingController(text: "0.0");
  final _closingCashCtrl = TextEditingController(text: "0.0");
  double _reconVariance = 0.0;
  bool _showRecon = false;

  double _previewOpayFee = 0;
  double _previewNetProfit = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = Provider.of<BranchProvider>(context, listen: false);
      if (bp.branches.isNotEmpty) {
         final firstActive = bp.branches.firstWhere((b) => b.isPosTerminalEnabled, orElse: () => bp.branches.first);
         setState(() {
           _selectedBranchId = firstActive.id;
           _openingCashCtrl.text = (firstActive.posConfig?.defaultOpeningCash ?? 0).toStringAsFixed(0);
         });
      }
      _fetchData();
    });
  }

  void _onAmountChanged(String val) {
    if (_selectedBranchId == null) return;
    final branch = Provider.of<BranchProvider>(context, listen: false).branches.firstWhere((b) => b.id == _selectedBranchId);
    // Auto-calculate OPay fee and refresh preview
    final withdrawalAmount = MoneyTextInputFormatter.getNumericValue(_amountCtrl.text);
    final customerCharge = MoneyTextInputFormatter.getNumericValue(_chargesCtrl.text);
    
    // Check if current type allows provider fee
    final config = branch.posConfig;
    final currentType = config?.transactionTypes.firstWhere(
      (t) => t.name == _transactionType, 
      orElse: () => PosTransactionType(name: _transactionType, hasProviderFee: true, hasCustomerCharge: true)
    );

    double terminalAmount = withdrawalAmount;
    if (_chargeMode.toLowerCase().contains('included')) {
      terminalAmount = withdrawalAmount + customerCharge;
    }

    double opayFee = 0;
    if (currentType?.hasProviderFee ?? true) {
      opayFee = OPayFeeCalculator.calculateFee(terminalAmount, config?.charges.opayTier ?? 'Regular');
    }
    
    setState(() {
      _previewOpayFee = opayFee;
      _previewNetProfit = (currentType?.hasCustomerCharge ?? true) ? (customerCharge - opayFee) : -opayFee;
    });

    _calculateVariance();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      final branchQ = _selectedBranchId != null ? "branchId=$_selectedBranchId&" : "";
      final startQ = "startDate=${_startDate.toIso8601String()}&";
      final endQ = "endDate=${_endDate.toIso8601String()}";
      
      final metricsRes = await api.client.get('/pos-transactions/metrics?$branchQ$startQ$endQ');
      final txRes = await api.client.get('/pos-transactions?$branchQ$startQ$endQ');

      if (metricsRes.statusCode == 200 && txRes.statusCode == 200) {
        setState(() {
          _metrics = metricsRes.data;
          _transactions = txRes.data;
          _isLoading = false;
        });
        _calculateVariance();
      } else {
        throw Exception("Failed to load POS data");
      }
    } catch (e) {
      if (mounted) {
        String errMsg = "Failed to load data.";
        if (e.toString().contains("400")) {
          errMsg = "Terminal is not available for this branch.";
        }
        setState(() {
          _error = errMsg;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addTransaction() async {
    if (_selectedBranchId == null) {
      ToastUtils.show(context, "Select a branch first", type: ToastType.warning);
      return;
    }
    
    final branch = Provider.of<BranchProvider>(context, listen: false).branches.firstWhere((b) => b.id == _selectedBranchId);
    if (branch.posConfig?.security.requireReconciliation == true && !_showRecon) {
       ToastUtils.show(context, "Daily reconciliation required before logging", type: ToastType.warning);
       setState(() => _showRecon = true);
       return;
    }

    if (_amountCtrl.text.isEmpty) {
      ToastUtils.show(context, "Amount is required", type: ToastType.warning);
      return;
    }
    final withdrawalAmount = MoneyTextInputFormatter.getNumericValue(_amountCtrl.text);
    final customerCharge = MoneyTextInputFormatter.getNumericValue(_chargesCtrl.text);
    
    double terminalAmount = withdrawalAmount;
    if (_chargeMode.toLowerCase().contains('included')) {
      terminalAmount = withdrawalAmount + customerCharge;
    }
    
    final opayFee = OPayFeeCalculator.calculateFee(terminalAmount, branch.posConfig?.charges.opayTier ?? 'Regular');

    setState(() => _isSaving = true);
    
    try {
      final api = ApiService();
      final response = await api.client.post('/pos-transactions', data: {
        'branchId': _selectedBranchId,
        'transactionType': _transactionType,
        'amount': terminalAmount, // Legacy compatibility
        'withdrawalAmount': withdrawalAmount,
        'customerCharge': customerCharge,
        'chargeMode': _chargeMode.toLowerCase().contains('included') ? 'Included' : 'Cash',
        'terminalAmount': terminalAmount,
        'providerFee': opayFee,
        'status': _isUnresolved ? 'unresolved' : 'resolved',
        'notes': _notesCtrl.text.trim(),
      });

      if (response.statusCode == 200) {
        _amountCtrl.clear();
        _chargesCtrl.clear();
        _notesCtrl.clear();
        setState(() {
          _previewOpayFee = 0;
          _previewNetProfit = 0;
        });
        ToastUtils.show(context, "Transaction logged", type: ToastType.success);
        _fetchData();
      } else {
        throw Exception(response.data['msg'] ?? "Save failed");
      }
    } catch (e) {
      String msg = e.toString();
      if (e is DioException && e.response?.data != null) {
        msg = e.response?.data['msg'] ?? e.response?.data['message'] ?? msg;
      }
      ToastUtils.show(context, msg, type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTransaction(dynamic tx) async {
    final branch = Provider.of<BranchProvider>(context, listen: false).branches.firstWhere((b) => b.id == _selectedBranchId);
    final config = branch.posConfig;
    
    if (config?.security.lockAfter24h == true) {
      final txDate = DateTime.parse(tx['createdAt']);
      if (DateTime.now().difference(txDate).inHours > 24) {
        ToastUtils.show(context, "Transaction locked (over 24h old)", type: ToastType.error);
        return;
      }
    }

    try {
      final api = ApiService();
      final res = await api.client.delete('/pos-transactions/${tx['_id']}');
      if (res.statusCode == 200) {
        ToastUtils.show(context, "Deleted safely", type: ToastType.success);
        _fetchData();
      } else {
        throw Exception(res.data['msg'] ?? "Delete failed");
      }
    } catch (e) {
      ToastUtils.show(context, e.toString(), type: ToastType.error);
    }
  }
  
  void _calculateVariance() {
    final openingCash = MoneyTextInputFormatter.getNumericValue(_openingCashCtrl.text);
    final closingCash = MoneyTextInputFormatter.getNumericValue(_closingCashCtrl.text);
    final expectedCash = openingCash + (_metrics['totalDeposits'] ?? 0) - (_metrics['totalWithdrawals'] ?? 0);
    setState(() {
      _reconVariance = closingCash - expectedCash;
    });
  }

  Future<void> _exportData() async {
    if (_transactions.isEmpty) return;
    try {
      List<List<dynamic>> rows = [];
      rows.add(["Date", "Type", "Amount", "Charges", "Staff", "Notes"]);
      for(var tx in _transactions) {
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(tx['createdAt']).toLocal()),
          tx['transactionType'],
          tx['amount'],
          tx['charges'] ?? 0,
          tx['enteredBy'] != null ? tx['enteredBy']['name'] : 'System',
          tx['notes'] ?? '',
        ]);
      }
      String csvStr = rows.map((row) => row.join(',')).join('\n');
      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/POS_Ledger_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvStr);
      await Share.shareXFiles([XFile(path)], text: 'POS Ledger Report');
    } catch (e) {
      ToastUtils.show(context, "Export error", type: ToastType.error);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _chargesCtrl.dispose();
    _notesCtrl.dispose();
    _openingCashCtrl.dispose();
    _closingCashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text("POS Terminal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.greenAccent),
            tooltip: "Export Ledger",
            onPressed: () => _exportData(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.secondaryColor),
            onPressed: _fetchData,
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: LiquidBackground(
        child: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor))
                : _error != null 
                  ? _buildError()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryMetrics(),
                          _buildDailyProfitProgress(),
                          const SizedBox(height: 24),
                          _buildQuickEntryCard(),
                          const SizedBox(height: 24),
                          _buildReconciliationButton(),
                          if (_showRecon) _buildReconciliationSection(),
                          const SizedBox(height: 24),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                                const Icon(Icons.account_balance_rounded, color: AppTheme.secondaryColor, size: 28),
                                const SizedBox(width: 15),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("POS TERMINAL", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    _buildOpayIndicator(),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          _buildLedgerTable(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    )
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Consumer<BranchProvider>(
      builder: (context, bp, _) {
        final selectedBranchName = bp.branches.any((b) => b.id == _selectedBranchId)
          ? bp.branches.firstWhere((b) => b.id == _selectedBranchId).name
          : "Select Branch";

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF1E293B),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (ctx) => Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Select Branch", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            ...bp.branches.where((b) => b.isPosTerminalEnabled).map((b) => ListTile(
                              title: Text(b.name, style: const TextStyle(color: Colors.white)),
                              onTap: () {
                                setState(() => _selectedBranchId = b.id);
                                _fetchData();
                                Navigator.pop(ctx);
                              },
                              trailing: _selectedBranchId == b.id ? const Icon(Icons.check_circle, color: AppTheme.secondaryColor) : null,
                            )).toList(),
                            if (bp.branches.where((b) => b.isPosTerminalEnabled).isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text("No branches have POS Terminal enabled.", style: TextStyle(color: Colors.white54)),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedBranchName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                    builder: (context, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(primary: AppTheme.secondaryColor, onPrimary: Colors.black, surface: Color(0xFF1E293B), onSurface: Colors.white),
                        dialogBackgroundColor: const Color(0xFF1E293B),
                      ),
                      child: child!,
                    ),
                  );
                  if (range != null) {
                    setState(() {
                      _startDate = range.start;
                      _endDate = range.end.add(const Duration(hours: 23, minutes: 59));
                    });
                    _fetchData();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                  child: const Icon(Icons.calendar_month_outlined, color: AppTheme.secondaryColor, size: 22),
                ),
              )
            ],
          ),
        );
      }
    );
  }
  
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
            const SizedBox(height: 20),
            Text(
              _error!, 
              textAlign: TextAlign.center, 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            const Text(
              "Access to this terminal must be enabled in the branch configuration settings.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
              onPressed: _fetchData, 
              child: const Text("Retry", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    return Row(
      children: [
        Expanded(child: _MetricCard(
          title: "VOLUME", 
          amount: (_metrics['totalVolume'] ?? 0).toDouble(), 
          colors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
        )),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
          title: "CHARGES", 
          amount: (_metrics['totalCharges'] ?? 0).toDouble(), 
          colors: [const Color(0xFF10B981), const Color(0xFF3B82F6)]
        )),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(
          title: "OPay FEES", 
          amount: (_metrics['totalProviderFees'] ?? 0).toDouble(), 
          colors: [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
        )),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)
              ],
            ),
            child: _MetricCard(
              title: "NET PROFIT", 
              amount: (_metrics['netProfit'] ?? 0).toDouble(), 
              subtitle: "After OPay Fees",
              colors: [AppTheme.secondaryColor, const Color(0xFF0EA5E9)]
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyProfitProgress() {
    if (_selectedBranchId == null) return const SizedBox.shrink();
    final branch = Provider.of<BranchProvider>(context, listen: false).branches.firstWhere((b) => b.id == _selectedBranchId);
    final config = branch.posConfig;
    if (config == null || !config.profitTarget.enabled || config.profitTarget.amount <= 0) return const SizedBox.shrink();

    final target = config.profitTarget.amount;
    final current = (_metrics['totalVolume'] ?? 0).toDouble();
    final progress = (current / target).clamp(0.0, 1.0);
    final percentage = (progress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("DAILY PROFIT TARGET", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            Text("$percentage%", style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(3))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 6,
              width: MediaQuery.of(context).size.width * 0.8 * progress,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), AppTheme.secondaryColor]),
                borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.3), blurRadius: 4)]
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          "${CurrencyFormatter.format(current)} of ${CurrencyFormatter.format(target)}",
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildQuickEntryCard() {
    if (_selectedBranchId == null) return const SizedBox.shrink();
    final branch = Provider.of<BranchProvider>(context, listen: false).branches.firstWhere((b) => b.id == _selectedBranchId);

    return GlassContainer(
      opacity: 0.1,
      border: Border.all(color: Colors.white10),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor, size: 20),
              const SizedBox(width: 8),
              const Text("Log New Transaction", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("CHARGE MODE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          value: _chargeMode,
                          style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                          items: ['Included In Transaction', 'Collected as Cash'].map((t) => 
                            DropdownMenuItem(value: t, child: Text(t))
                          ).toList(),
                          onChanged: (val) {
                            setState(() => _chargeMode = val!);
                            _onAmountChanged("");
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("TYPE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          value: _transactionType,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          items: (branch.posConfig?.transactionTypes.isNotEmpty ?? false)
                            ? branch.posConfig!.transactionTypes.map((t) => 
                                DropdownMenuItem(value: t.name, child: Text(t.name))
                              ).toList()
                            : ['Withdrawal', 'Transfer', 'Deposit', 'Airtime', 'Electricity', 'Other'].map((t) => 
                                DropdownMenuItem(value: t, child: Text(t))
                              ).toList(),
                          onChanged: (val) {
                            setState(() {
                              _transactionType = val!;
                              final typeConfig = branch.posConfig?.transactionTypes.firstWhere((t) => t.name == val, orElse: () => PosTransactionType(name: val, hasCustomerCharge: true));
                              if (!(typeConfig?.hasCustomerCharge ?? true)) {
                                _chargesCtrl.text = "0";
                              }
                            });
                            _onAmountChanged("");
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("WITHDRAWAL AMOUNT", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoneyTextInputFormatter()],
                      onChanged: _onAmountChanged,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "0", 
                        hintStyle: const TextStyle(color: Colors.white24),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Builder(
                builder: (context) {
                  final typeConfig = branch.posConfig?.transactionTypes.firstWhere(
                    (t) => t.name == _transactionType, 
                    orElse: () => PosTransactionType(name: _transactionType, hasCustomerCharge: true)
                  );
                  final isChargeEnabled = typeConfig?.hasCustomerCharge ?? true;

                  return Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CHARGE", 
                          style: TextStyle(
                            color: isChargeEnabled ? Colors.white54 : Colors.white12, 
                            fontSize: 10, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _chargesCtrl,
                          enabled: isChargeEnabled,
                          keyboardType: TextInputType.number,
                          inputFormatters: [MoneyTextInputFormatter()],
                          onChanged: _onAmountChanged,
                          style: TextStyle(
                            color: isChargeEnabled ? Colors.white : Colors.white24, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 14
                          ),
                          decoration: InputDecoration(
                            hintText: "0", 
                            hintStyle: const TextStyle(color: Colors.white24),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            filled: true,
                            fillColor: isChargeEnabled ? Colors.white.withOpacity(0.05) : Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _notesCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Transaction notes (optional)...", 
                    hintStyle: const TextStyle(color: Colors.white24),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("STATUS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() => _isUnresolved = !_isUnresolved),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isUnresolved ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _isUnresolved ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(
                            _isUnresolved ? "UNRESOLVED" : "RESOLVED",
                            style: TextStyle(
                              color: _isUnresolved ? Colors.orange : Colors.green,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPreviewItem("OPay Fee", _previewOpayFee, Colors.orangeAccent),
                _buildPreviewItem("Net Profit", _previewNetProfit, AppTheme.secondaryColor),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isUnresolved ? Colors.orange : AppTheme.secondaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: _isSaving ? null : _addTransaction,
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : Text(
                  _isUnresolved ? "Log Unresolved" : "Save Log", 
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
                ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildReconciliationButton() {
    return GestureDetector(
      onTap: () => setState(() => _showRecon = !_showRecon),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.secondaryColor, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text("Daily Cash Reconciliation", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Icon(
              _showRecon ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, 
              color: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReconciliationSection() {
    final openingCash = double.tryParse(_openingCashCtrl.text) ?? 0.0;
    final expectedCash = openingCash + (_metrics['totalDeposits'] ?? 0) - (_metrics['totalWithdrawals'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Column(
        children: [
          Row(
            children: [
               const Expanded(child: Text("Opening Cash", style: TextStyle(color: Colors.white54))),
              SizedBox(
                width: 100,
                height: 30,
                child: TextField(
                  controller: _openingCashCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyTextInputFormatter()],
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.zero, isDense: true),
                  onChanged: (_) => _calculateVariance(),
                ),
              )
            ],
          ),
          const Divider(color: Colors.white10),
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text("System Implied Cash", style: TextStyle(color: Colors.white70)),
               Text(CurrencyFormatter.format(expectedCash), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
             ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(child: Text("Actual Counted Cash", style: TextStyle(color: Colors.white))),
              SizedBox(
                width: 100,
                height: 30,
                child: TextField(
                  controller: _closingCashCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyTextInputFormatter()],
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(contentPadding: EdgeInsets.zero, isDense: true),
                  onChanged: (_) => _calculateVariance(),
                ),
              )
            ],
          ),
          const Divider(color: Colors.white10),
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text("Variance", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               Text(
                 CurrencyFormatter.format(_reconVariance), 
                 style: TextStyle(color: _reconVariance == 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)
               ),
             ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTable() {
    if (_transactions.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(40.0),
        child: Text("No transactions yet.", style: TextStyle(color: Colors.white54)),
      ));
    }
    
    return Column(
      children: [
        _buildLedgerHeader(),
        const SizedBox(height: 8),
        ..._transactions.map((tx) => _buildLedgerRow(tx)).toList(),
      ],
    );
  }

  Widget _buildLedgerHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Expanded(flex: 2, child: Text("DATE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
          const Expanded(flex: 2, child: Text("TYPE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold))),
          const Expanded(flex: 2, child: Text("WITHDRAWAL", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          const Expanded(flex: 2, child: Text("CHARGE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          const Expanded(flex: 1, child: Text("MODE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          const Expanded(flex: 2, child: Text("FEES", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          const Expanded(flex: 2, child: Text("PROFIT", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildLedgerRow(Map<String, dynamic> tx) {
    final date = DateTime.parse(tx['createdAt']).toLocal();
    final isUnresolved = tx['status'] == 'unresolved';
    final branch = Provider.of<BranchProvider>(context, listen: false).branches.firstWhere((b) => b.id == _selectedBranchId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUnresolved ? Colors.orange.withOpacity(0.05) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnresolved ? Colors.orange.withOpacity(0.2) : Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}", 
              style: const TextStyle(color: Colors.white38, fontSize: 10)
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tx['transactionType'], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                if (tx['enteredBy'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    "By: ${tx['enteredBy']['name']}", 
                    style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ],
                if (tx['notes'] != null && tx['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      tx['notes'], 
                      style: const TextStyle(color: Colors.white70, fontSize: 9),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormatter.format((tx['withdrawalAmount'] ?? tx['amount'] ?? 0).toDouble()), 
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormatter.format((tx['customerCharge'] ?? tx['charges'] ?? 0).toDouble()), 
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Tooltip(
                message: tx['chargeMode'] ?? 'Included',
                child: Icon(
                  tx['chargeMode'] == 'Cash' ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                  color: Colors.white38,
                  size: 14,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormatter.format((tx['providerFee'] ?? 0).toDouble()), 
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              CurrencyFormatter.format((tx['netProfit'] ?? 0).toDouble()), 
              style: TextStyle(
                color: isUnresolved ? Colors.white24 : AppTheme.secondaryColor, 
                fontSize: 11, 
                fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isUnresolved ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isUnresolved ? "PENDING" : "RESOLVED",
                  style: TextStyle(color: isUnresolved ? Colors.orange : Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: isUnresolved 
              ? IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.orange, size: 20),
                  onPressed: () => _resolveTransaction(tx, branch),
                  tooltip: "Resolve",
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                  onPressed: () => _confirmDelete(tx),
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveTransaction(Map<String, dynamic> tx, Branch branch) async {
    setState(() => _isSaving = true);
    try {
      final api = ApiService();
      final amount = (tx['terminalAmount'] ?? tx['amount'] ?? 0).toDouble();
      final charges = (tx['customerCharge'] ?? tx['charges'] ?? 0).toDouble();
      final opayFee = OPayFeeCalculator.calculateFee(amount, branch.posConfig?.charges.opayTier ?? 'Regular');

      final response = await api.client.put('/pos-transactions/${tx['_id']}', data: {
        'status': 'resolved',
        'providerFee': opayFee,
        'netProfit': charges - opayFee,
      });

      if (response.statusCode == 200) {
        ToastUtils.show(context, "Transaction Resolved", type: ToastType.success);
        _fetchData();
      }
    } catch (e) {
      ToastUtils.show(context, "Resolution failed: $e", type: ToastType.error);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _confirmDelete(Map<String, dynamic> tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Transaction?", style: TextStyle(color: Colors.white)),
        content: const Text("This will permanently remove this log and affect branch metrics.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteTransaction(tx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.format(value),
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildOpayIndicator() {
    if (_selectedBranchId == null) return const SizedBox.shrink();
    final branch = Provider.of<BranchProvider>(context, listen: false).branches.firstWhere((b) => b.id == _selectedBranchId, orElse: () => Provider.of<BranchProvider>(context, listen: false).branches.first);
    final tier = branch.posConfig?.charges.opayTier ?? 'Regular';
    
    return Row(
      children: [
        const Text("Provider: ", style: TextStyle(color: Colors.white38, fontSize: 10)),
        const Text("OPay", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        const Text("Tier: ", style: TextStyle(color: Colors.white38, fontSize: 10)),
        Text(tier, style: TextStyle(color: tier == 'Platinum' ? Colors.amberAccent : (tier == 'Gold' ? Colors.orangeAccent : Colors.blueAccent), fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double? amount;
  final String? valueStr;
  final List<Color> colors;

  const _MetricCard({required this.title, this.subtitle, this.amount, this.valueStr, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          if (subtitle != null) ...[
             const SizedBox(height: 2),
             Text(subtitle!, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 7, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount != null ? CurrencyFormatter.format(amount!) : valueStr ?? "0",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          )
        ],
      ),
    );
  }
}
