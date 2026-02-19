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

import 'widgets/staff_performance_table.dart';
import 'widgets/tax_summary_card.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../utils/currency_formatter.dart';

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
          title: Consumer<ReportProvider>(
            builder: (context, provider, _) => Text(
              provider.isInvestorMode ? "Investor Overview" : "Financial Intelligence", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          actions: [
            // Investor Mode Toggle
            Consumer<ReportProvider>(
              builder: (context, provider, _) => IconButton(
                icon: Icon(
                  provider.isInvestorMode ? Icons.pie_chart : Icons.bar_chart, 
                  color: provider.isInvestorMode ? Colors.amberAccent : Colors.white
                ),
                tooltip: "Investor Mode",
                onPressed: () => provider.toggleInvestorMode(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => Provider.of<ReportProvider>(context, listen: false).refreshAll(),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share, color: Colors.white),
               onPressed: () {
                 showModalBottomSheet(
                   context: context,
                   backgroundColor: const Color(0xFF1E1E2C),
                   shape: const RoundedRectangleBorder(
                     borderRadius: BorderRadius.vertical(top: Radius.circular(20))
                   ),
                   builder: (context) => Container(
                     padding: const EdgeInsets.all(20),
                     height: 250,
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const Text("Export Report", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 10),
                         const Text("Generates a PDF report based on currently applied filters.", style: TextStyle(color: Colors.white54, fontSize: 13)),
                         const SizedBox(height: 30),
                         
                         const Text("Format:", style: TextStyle(color: Colors.white70)),
                         const SizedBox(height: 10),
                         Row(
                           children: [
                             _buildExportChip("PDF", true),
                             const SizedBox(width: 10),
                             _buildExportChip("Excel (Coming Soon)", false),
                           ],
                         ),
                         const Spacer(),
                         SizedBox(
                           width: double.infinity,
                           child: ElevatedButton(
                             style: ElevatedButton.styleFrom(
                               backgroundColor: AppTheme.primaryColor,
                               padding: const EdgeInsets.symmetric(vertical: 15)
                             ),
                             onPressed: () {
                               Navigator.pop(context);
                               _generatePdf(context);
                             },
                             child: const Text("Download PDF", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                           ),
                         )
                       ],
                     ),
                   ),
                 );
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
                     
                     if (provider.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 10),
                              Text("Error loading data", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(provider.error!, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
                              TextButton(
                                onPressed: () => provider.refreshAll(),
                                child: const Text("Retry", style: TextStyle(color: AppTheme.primaryColor)),
                              )
                            ],
                          ),
                        );
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

                            // INVESTOR MODE: Simplified View
                            if (provider.isInvestorMode) ...[
                               const Text("Key Performance Indicators", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                               const SizedBox(height: 10),
                               const RevenueChart(), // Trend is key for investors
                               const SizedBox(height: 20),
                               // Financial Breakdown for Net Margin visibility
                               const FinancialBreakdown(),
                               const SizedBox(height: 20),
                               const Text("Analysis: Growth is stable. Net margin logic applied.", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                            ] else ...[
                                // OPERATIONAL MODE: Detailed View
                                const SizedBox(height: 10),
                                const Text("Revenue Trend", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                const RevenueChart(),
                                const SizedBox(height: 30),

                                // 4. Breakdown & Tax
                                const FinancialBreakdown(),
                                const SizedBox(height: 30),
                                
                                const TaxSummaryCard(), // [NEW]
                                const SizedBox(height: 30),

                                // 5. Staff Performance
                                const StaffPerformanceTable(), // [NEW]
                                const SizedBox(height: 30),

                                // 6. Expenses
                                const ExpenseTracker(),
                                const SizedBox(height: 50),
                            ],
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

  Future<void> _generatePdf(BuildContext context) async {
    final provider = Provider.of<ReportProvider>(context, listen: false);
    final pdf = pw.Document();
    
    final data = provider.financials ?? {};
    final summary = provider.analytics ?? {};
    final revenue = data['revenue'] ?? 0;
    final net = data['netProfit'] ?? 0;
    final expenses = data['expenses'] ?? 0;
    
    // Helper to format currency
    String fmt(dynamic val) => CurrencyFormatter.format((val is num ? val : 0) / 100);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Financial Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Clotheline", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Date Range: ${provider.rangeLabel}"),
                  pw.Text("Branch: ${provider.selectedBranchId ?? 'All Branches'}"),
                ]
              ),
              pw.SizedBox(height: 10),
              pw.Text("Business Type: ${provider.businessType}"),
              pw.SizedBox(height: 10),
              pw.Text("Generated on: ${DateTime.now().toString().split('.')[0]}"),
              pw.Divider(),
              pw.SizedBox(height: 20),
              
              // Summary Table
              pw.Text("Summary", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Metric', 'Value'],
                  <String>['Total Revenue', fmt(revenue)],
                  <String>['Net Profit', fmt(net)],
                  <String>['Expenses', fmt(expenses)],
                  <String>['Taxes Collected', fmt(data['taxesCollected'])],
                  <String>['Outstanding', fmt(data['outstandingPayments'])],
                ],
              ),
              
              pw.SizedBox(height: 30),
              
              // Staff Performance
              if (summary['staffPerformance'] != null && (summary['staffPerformance'] as List).isNotEmpty) ...[
                pw.Text("Staff Performance", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                 pw.Table.fromTextArray(
                  context: context,
                  headers: ['Staff Name', 'Orders', 'Revenue'],
                  data: (summary['staffPerformance'] as List).map((s) => [
                    s['_id'] ?? 'Unknown',
                    "${s['count']}",
                    fmt(s['revenue'])
                  ]).toList(),
                ),
              ]
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Widget _buildExportChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent)
      ),
      child: Text(label, style: TextStyle(color: isSelected ? AppTheme.primaryColor : Colors.white54)),
    );
  }
}
