import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../providers/report_provider.dart';
import '../../../../providers/branch_provider.dart';
import 'widgets/financial_filter_bar.dart';
import 'widgets/financial_summary_cards.dart';
import 'widgets/revenue_chart.dart';
import 'widgets/expense_tracker.dart';
import 'widgets/goal_tracker.dart';
import 'widgets/financial_breakdown.dart';

class AdminFinancialReportsScreen extends StatefulWidget {
  const AdminFinancialReportsScreen({super.key});

  @override
  State<AdminFinancialReportsScreen> createState() => _AdminFinancialReportsScreenState();
}

class _AdminFinancialReportsScreenState extends State<AdminFinancialReportsScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // Init data
       Provider.of<ReportProvider>(context, listen: false).refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Financial Intelligence", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => Provider.of<ReportProvider>(context, listen: false).refreshAll(),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share, color: Colors.white),
              onPressed: () {
                 // Open Export Dialog
                 // TODO: Implement Export Dialog
              }, 
            )
          ],
        ),
        body: LiquidBackground(
          child: Column(
            children: [
               // Fixed Filter Bar at top (below safe area)
               SafeArea(
                 bottom: false,
                 child: const FinancialFilterBar(),
               ),
               
               // Scrollable Content
               Expanded(
                 child: Consumer<ReportProvider>(
                   builder: (context, provider, _) {
                     if (provider.isLoading) {
                       return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
                     }
                     
                     return SingleChildScrollView(
                       padding: const EdgeInsets.all(20),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            // 1. Goals & Projections
                            const GoalTracker(),
                            const SizedBox(height: 20),

                            // 2. High Level Metrics
                            const FinancialSummaryCards(),
                            const SizedBox(height: 30),

                            // 3. Charts
                            const Text("Revenue Trend", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            const RevenueChart(),
                            const SizedBox(height: 30),

                            // 4. Breakdown (Payment Methods, Split)
                            const FinancialBreakdown(),
                            const SizedBox(height: 30),

                            // 5. Expenses
                            const ExpenseTracker(),
                            const SizedBox(height: 50), // Bottom padding
                         ],
                       ),
                     );
                   }
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }
}
