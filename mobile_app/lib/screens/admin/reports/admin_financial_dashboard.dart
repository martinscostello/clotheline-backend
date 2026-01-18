import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../services/report_service.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/toast/top_toast.dart';

class AdminFinancialDashboard extends StatefulWidget {
  const AdminFinancialDashboard({super.key});

  @override
  State<AdminFinancialDashboard> createState() => _AdminFinancialDashboardState();
}

class _AdminFinancialDashboardState extends State<AdminFinancialDashboard> {
  final ReportService _reportService = ReportService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String _rangeLabel = "All Time";
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({DateTime? start, DateTime? end}) async {
    setState(() => _isLoading = true);
    try {
      final data = await _reportService.fetchFinancials(startDate: start, endDate: end);
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.show(context, "Error: $e", type: ToastType.error);
      }
    }
  }

  void _updateRange(String range) {
    DateTime now = DateTime.now();
    DateTime? start;
    DateTime? end = now;

    if (range == "Today") {
      start = DateTime(now.year, now.month, now.day);
    } else if (range == "This Week") {
      start = now.subtract(Duration(days: now.weekday - 1));
    } else if (range == "This Month") {
      start = DateTime(now.year, now.month, 1);
    } else {
       start = null;
       end = null;
    }

    setState(() => _rangeLabel = range);
    _fetchData(start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Financial Reports", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onSelected: _updateRange,
            itemBuilder: (context) => ["Today", "This Week", "This Month", "All Time"].map((c) => PopupMenuItem(value: c, child: Text(c))).toList(),
          )
        ],
      ),
      body: LiquidBackground(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Period: $_rangeLabel", style: const TextStyle(color: Colors.white54)),
                  const SizedBox(height: 20),
                  
                  // Summary Cards
                  _buildSummaryGrid(),
                 
                  const SizedBox(height: 30),
                  
                  // Provider Breakdown
                  const Text("Payment Methods", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildProviderBreakdown(),

                  const SizedBox(height: 30),
                  const Text("Breakdown", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildDetailedStats(),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildSummaryGrid() {
    if (_data == null) return const SizedBox.shrink();
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard("Total Revenue", _data!['revenue'], color: Colors.greenAccent),
        _buildMetricCard("Net Revenue", _data!['netRevenue'], color: Colors.blueAccent),
        _buildMetricCard("Refunds", _data!['refunds'], color: Colors.redAccent, isNegative: true),
        _buildMetricCard("Transactions", _data!['transactionVolume'], isCurrency: false),
      ],
    );
  }

  Widget _buildMetricCard(String title, dynamic value, {Color color = Colors.white, bool isCurrency = true, bool isNegative = false}) {
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            isCurrency ? CurrencyFormatter.format((value is num ? value : 0) / 100) : "$value", 
            style: TextStyle(
              color: color, 
              fontSize: 20, 
              fontWeight: FontWeight.bold
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProviderBreakdown() {
     List providers = _data?['byProvider'] ?? [];
     if (providers.isEmpty) return const Text("No data", style: TextStyle(color: Colors.white54));

     return Column(
       children: providers.map((p) {
         final name = p['_id'].toString().toUpperCase();
         final total = p['total']; // Kobo
         final count = p['count'];
         
         return Container(
           margin: const EdgeInsets.only(bottom: 10),
           child: GlassContainer(
             opacity: 0.05,
             padding: const EdgeInsets.all(16),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Row(
                   children: [
                     Icon(Icons.payment, color: name == 'PAYSTACK' ? Colors.blue : Colors.orange, size: 20),
                     const SizedBox(width: 10),
                     Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   ],
                 ),
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                     Text(CurrencyFormatter.format(total / 100), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     Text("$count txns", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                   ],
                 )
               ],
             ),
           ),
         );
       }).toList(),
     );
  }
  
  Widget _buildDetailedStats() {
    return GlassContainer(
      opacity: 0.05,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
           _buildRow("Total Refund Count", "${_data?['refundCount'] ?? 0}"),
           const Divider(color: Colors.white10),
           _buildRow("Pending Payments", "${_data?['pendingCount'] ?? 0}"),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
