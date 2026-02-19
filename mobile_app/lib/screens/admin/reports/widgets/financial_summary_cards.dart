import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../providers/report_provider.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../utils/currency_formatter.dart';

class FinancialSummaryCards extends StatelessWidget {
  const FinancialSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
          final data = provider.financials ?? {};
          final revenue = data['revenue'] ?? 0;
          final net = data['netProfit'] ?? 0;
          final expenses = data['expenses'] ?? 0;
          final refunds = data['refunds'] ?? 0; // Negative usually
          
          return GridView.count(
             shrinkWrap: true,
             physics: const NeverScrollableScrollPhysics(),
             crossAxisCount: 2,
             crossAxisSpacing: 15,
             mainAxisSpacing: 15,
             childAspectRatio: 1.5,
             children: [
                _buildCard("Total Revenue", revenue, Colors.greenAccent),
                _buildCard("Net Profit", net, net >= 0 ? Colors.blueAccent : Colors.redAccent),
                _buildCard("Expenses", expenses, Colors.orangeAccent, isNegative: true),
                _buildCard("Refunds", refunds, Colors.red, isNegative: true),
             ],
          );
      }
    );
  }

  Widget _buildCard(String title, dynamic value, Color color, {bool isNegative = false}) {
      return GlassContainer(
        opacity: 0.1,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
             const Spacer(),
             Text(
               CurrencyFormatter.format((value is num ? value : 0) / 100), // Kobo to Naira
               style: TextStyle(
                 color: color,
                 fontSize: 20,
                 fontWeight: FontWeight.bold
               ),
             ),
          ],
        ),
      );
  }
}
