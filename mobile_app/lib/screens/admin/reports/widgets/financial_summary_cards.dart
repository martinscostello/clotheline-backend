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
          final aov = data['averageOrderValue'] ?? 0;
          final outstanding = data['outstandingPayments'] ?? 0;
          final taxes = data['taxesCollected'] ?? 0;
          final txCount = data['txCount'] ?? 0;
          final pendingCount = data['pendingOrdersCount'] ?? 0;
          
          return Column(
            children: [
              GridView.count(
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
              ),
              const SizedBox(height: 15),
              // Secondary Metrics
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3, // Smaller cards
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.2,
                children: [
                    _buildMiniCard("AOV", aov, Colors.purpleAccent),
                    _buildMiniCard("Outstanding", outstanding, Colors.amberAccent),
                    _buildMiniCard("Taxes", taxes, Colors.cyanAccent),
                    _buildMiniCard("Total Orders", txCount, Colors.white, isCurrency: false),
                    _buildMiniCard("Pending Orders", pendingCount, Colors.orange, isCurrency: false),
                ],
              ),
            ],
          );
      }
    );
  }

  Widget _buildMiniCard(String title, dynamic value, Color color, {bool isCurrency = true}) {
      return GlassContainer(
        opacity: 0.1,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10), overflow: TextOverflow.ellipsis),
             const Spacer(),
             Text(
               isCurrency ? CurrencyFormatter.format((value is num ? value : 0)) : "$value",
               style: TextStyle(
                 color: color,
                 fontSize: 14,
                 fontWeight: FontWeight.bold
               ),
             ),
          ],
        ),
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
               CurrencyFormatter.format((value is num ? value : 0)), // Kobo to Naira
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
