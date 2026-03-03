import 'package:flutter/material.dart';
import 'package:clotheline_admin/widgets/glass/LiquidBackground.dart';
import 'package:clotheline_admin/widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _isSaving = false;

  // Recon
  final _openingCashCtrl = TextEditingController(text: "0.0");
  final _closingCashCtrl = TextEditingController(text: "0.0");
  double _reconVariance = 0.0;
  bool _showRecon = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bp = Provider.of<BranchProvider>(context, listen: false);
      if (bp.branches.isNotEmpty && bp.branches.first.isPosTerminalEnabled) {
         _selectedBranchId = bp.branches.first.id;
      }
      _fetchData();
    });
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
    if (_amountCtrl.text.isEmpty) {
      ToastUtils.show(context, "Amount is required", type: ToastType.warning);
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final api = ApiService();
      final response = await api.client.post('/pos-transactions', data: {
        'branchId': _selectedBranchId,
        'transactionType': _transactionType,
        'amount': double.tryParse(_amountCtrl.text) ?? 0,
        'charges': double.tryParse(_chargesCtrl.text) ?? 0,
        'notes': _notesCtrl.text,
      });

      if (response.statusCode == 200) {
        _amountCtrl.clear();
        _chargesCtrl.clear();
        _notesCtrl.clear();
        ToastUtils.show(context, "Transaction logged", type: ToastType.success);
        _fetchData();
      } else {
        throw Exception(response.data['msg'] ?? "Save failed");
      }
    } catch (e) {
      ToastUtils.show(context, e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteTransaction(String id) async {
    try {
      final api = ApiService();
      final res = await api.client.delete('/pos-transactions/$id');
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
      final openingCash = double.tryParse(_openingCashCtrl.text) ?? 0.0;
      final closingCash = double.tryParse(_closingCashCtrl.text) ?? 0.0;
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
                          const SizedBox(height: 24),
                          _buildQuickEntryCard(),
                          const SizedBox(height: 24),
                          _buildReconciliationButton(),
                          if (_showRecon) _buildReconciliationSection(),
                          const SizedBox(height: 24),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 12),
                          const Text("Recent Transactions", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
          title: "TRANSACTIONS", 
          valueStr: "${_metrics['totalTransactions'] ?? 0}", 
          colors: [const Color(0xFFF43F5E), const Color(0xFFFB923C)]
        )),
      ],
    );
  }

  Widget _buildQuickEntryCard() {
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
                          items: ['Withdrawal', 'Transfer', 'Deposit', 'Airtime', 'Electricity', 'Other'].map((t) => 
                            DropdownMenuItem(value: t, child: Text(t))
                          ).toList(),
                          onChanged: (val) => setState(() => _transactionType = val!),
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
                    const Text("AMOUNT", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "0.00", 
                        hintStyle: const TextStyle(color: Colors.white24),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        prefixText: "₦ ",
                        prefixStyle: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("FEE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _chargesCtrl,
                      keyboardType: TextInputType.number,
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
            ],
          ),
          const SizedBox(height: 20),
          const Text("NOTES / REFERENCE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "e.g. Paid to John Doe", 
              hintStyle: const TextStyle(color: Colors.white24),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: _isSaving ? null : _addTransaction,
              child: _isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : const Text("Save Transaction", style: TextStyle(fontWeight: FontWeight.bold)),
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
    if (_transactions.isEmpty) return const Center(child: Padding(
      padding: EdgeInsets.all(40.0),
      child: Text("No transactions yet.", style: TextStyle(color: Colors.white54)),
    ));
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _transactions.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final tx = _transactions[index];
            final bool isDeposit = tx['transactionType'] == 'Deposit';
            final bool isWithdrawal = tx['transactionType'] == 'Withdrawal';
            final amountColor = isDeposit ? Colors.greenAccent : (isWithdrawal ? Colors.orangeAccent : Colors.blueAccent);
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: amountColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(
                      isDeposit ? Icons.arrow_downward : (isWithdrawal ? Icons.arrow_upward : Icons.swap_horiz), 
                      color: amountColor, 
                      size: 18
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx['transactionType'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM dd, HH:mm').format(DateTime.parse(tx['createdAt']).toLocal()), 
                          style: const TextStyle(color: Colors.white38, fontSize: 11)
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format((tx['amount'] ?? 0).toDouble()), 
                          style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 14)
                        ),
                        if ((tx['charges'] ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              "+${CurrencyFormatter.format((tx['charges']).toDouble())} Fee", 
                              style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w600)
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete Action
                  Consumer<AuthService>(
                    builder: (context, auth, _) {
                      if (auth.currentUser?['isMasterAdmin'] == true) {
                        return IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white24, size: 20),
                          onPressed: () {
                           showDialog(context: context, builder: (ctx) => AlertDialog(
                             backgroundColor: const Color(0xFF1E293B),
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                             title: const Text("Delete Transaction?", style: TextStyle(color: Colors.white)),
                             content: const Text("This action cannot be undone and will affect branch metrics.", style: TextStyle(color: Colors.white70)),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                               ElevatedButton(
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                 onPressed: () {
                                   Navigator.pop(ctx);
                                   _deleteTransaction(tx['_id']);
                                 }, 
                                 child: const Text("Delete")
                               ),
                             ],
                           ));
                          }
                        );
                      }
                      return const SizedBox(width: 12);
                    }
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final double? amount;
  final String? valueStr;
  final List<Color> colors;

  const _MetricCard({required this.title, this.amount, this.valueStr, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount != null ? CurrencyFormatter.format(amount!) : valueStr ?? "0",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          )
        ],
      ),
    );
  }
}
