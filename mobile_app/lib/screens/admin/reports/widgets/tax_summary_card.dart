import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../providers/report_provider.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../utils/currency_formatter.dart';

class TaxSummaryCard extends StatelessWidget {
  const TaxSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
          final financials = provider.financials ?? {};
          final analytics = provider.analytics ?? {};
          
          final totalTax = financials['taxesCollected'] ?? 0;
          final List<dynamic> breakdown = analytics['taxBreakdown'] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Text("Tax Summary", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               GlassContainer(
                 opacity: 0.1,
                 padding: const EdgeInsets.all(20),
                 child: Column(
                   children: [
                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Total VAT Collected", style: TextStyle(color: Colors.white70, fontSize: 14)),
                              SizedBox(height: 5),
                              Text("(Liability)", style: TextStyle(color: Colors.white24, fontSize: 10)),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.format(totalTax),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      
                      if (breakdown.isNotEmpty) ...[
                        const Divider(color: Colors.white24, height: 30),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Monthly Breakdown", style: TextStyle(color: Colors.white54, fontSize: 12))
                        ),
                        const SizedBox(height: 10),
                        ...breakdown.map((item) {
                           return Padding(
                             padding: const EdgeInsets.symmetric(vertical: 4),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Text(item['_id'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                                 Text(
                                   CurrencyFormatter.format((item['taxCollected'] ?? 0)),
                                   style: const TextStyle(color: Colors.white70),
                                 )
                               ],
                             ),
                           );
                        })
                      ]
                   ],
                 ),
               ),
            ],
          );
      }
    );
  }
}
