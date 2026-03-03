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
        setState(() {
          _error = "Failed to load data. Ensure POS Terminal is enabled for this branch.";
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("POS Terminal Ledger", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.greenAccent),
            tooltip: "Export Ledger",
            onPressed: () => _exportData(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor),
            onPressed: _fetchData,
          ),
        ],
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildFilters(),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null 
                    ? _buildError()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryMetrics(),
                            const SizedBox(height: 20),
                            _buildQuickEntryCard(),
                            const SizedBox(height: 20),
                            _buildReconciliationButton(),
                            if (_showRecon) _buildReconciliationSection(),
                            const SizedBox(height: 20),
                            const Text("Recent Transactions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            _buildLedgerTable(),
                          ],
                        ),
                      )
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Consumer<BranchProvider>(
      builder: (context, bp, _) {
        return GlassContainer(
          opacity: 0.1,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    value: _selectedBranchId,
                    hint: const Text("Select Branch", style: TextStyle(color: Colors.white54)),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    items: bp.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (val) {
                      setState(() => _selectedBranchId = val);
                      _fetchData();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.date_range, color: AppTheme.secondaryColor, size: 20),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 50),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildSummaryMetrics() {
    return Row(
      children: [
        Expanded(child: _MetricCard(title: "Total Vol", amount: (_metrics['totalVolume'] ?? 0).toDouble(), color: Colors.blueAccent)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(title: "Charges", amount: (_metrics['totalCharges'] ?? 0).toDouble(), color: Colors.greenAccent)),
        const SizedBox(width: 10),
        Expanded(child: _MetricCard(title: "Txns", valueStr: "${_metrics['totalTransactions'] ?? 0}", color: Colors.purpleAccent)),
      ],
    );
  }

  Widget _buildQuickEntryCard() {
    return GlassContainer(
      opacity: 0.15,
      border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Log Transaction", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    value: _transactionType,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: ['Withdrawal', 'Transfer', 'Deposit', 'Airtime', 'Other'].map((t) => 
                      DropdownMenuItem(value: t, child: Text(t))
                    ).toList(),
                    onChanged: (val) => setState(() => _transactionType = val!),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: "Amount", hintStyle: TextStyle(color: Colors.white38), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), filled: true, fillColor: Colors.white10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _chargesCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(hintText: "Fee", hintStyle: TextStyle(color: Colors.white38), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), filled: true, fillColor: Colors.white10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _notesCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(hintText: "Ref/Notes", hintStyle: TextStyle(color: Colors.white38), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5), filled: true, fillColor: Colors.white10),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, minimumSize: const Size(60, 40)),
                onPressed: _isSaving ? null : _addTransaction,
                child: _isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.black)) : const Text("Save", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildReconciliationButton() {
    return GestureDetector(
      onTap: () => setState(() => _showRecon = !_showRecon),
      child: GlassContainer(
        opacity: _showRecon ? 0.2 : 0.05,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance, color: _showRecon ? AppTheme.secondaryColor : Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text("Daily Cash Reconciliation", style: TextStyle(color: _showRecon ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
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
    if (_transactions.isEmpty) return const Text("No transactions yet.", style: TextStyle(color: Colors.white54));
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final bool isDeposit = tx['transactionType'] == 'Deposit';
        final amountColor = isDeposit ? Colors.greenAccent : Colors.orangeAccent;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: amountColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward, color: amountColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx['transactionType'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(DateFormat('MMM dd, HH:mm').format(DateTime.parse(tx['createdAt']).toLocal()), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyFormatter.format((tx['amount'] ?? 0).toDouble()), style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    if ((tx['charges'] ?? 0) > 0)
                      Text("Fee: ${CurrencyFormatter.format((tx['charges']).toDouble())}", style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                  ],
                ),
              ),
              // Delete Action
              Consumer<AuthService>(
                builder: (context, auth, _) {
                  if (auth.currentUser?['isMasterAdmin'] == true) {
                    return IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 18),
                      onPressed: () {
                        // Confirm deletion
                       showDialog(context: context, builder: (ctx) => AlertDialog(
                         title: const Text("Delete Ledger Entry?"),
                         content: const Text("This action cannot be undone."),
                         actions: [
                           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                           TextButton(onPressed: () {
                             Navigator.pop(ctx);
                             _deleteTransaction(tx['_id']);
                           }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
                         ],
                       ));
                      }
                    );
                  }
                  return const SizedBox(width: 48); // placeholder mapping
                }
              )
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final double? amount;
  final String? valueStr;
  final Color color;

  const _MetricCard({required this.title, this.amount, this.valueStr, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 5),
          Text(
            amount != null ? CurrencyFormatter.format(amount!) : valueStr ?? "0",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }
}
