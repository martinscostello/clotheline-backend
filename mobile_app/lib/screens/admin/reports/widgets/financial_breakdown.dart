import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../providers/report_provider.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../utils/currency_formatter.dart';

class FinancialBreakdown extends StatelessWidget {
  const FinancialBreakdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
         final analytics = provider.analytics;
         if (analytics == null) return const SizedBox.shrink();

         return Column(
           children: [
             _buildSection("Sales Breakdown", analytics['categories'] ?? []),
             const SizedBox(height: 20),
             _buildSection("Payment Methods", analytics['paymentMethods'] ?? []),
           ],
         );
      }
    );
  }

  Widget _buildSection(String title, List<dynamic> items) {
     if (items.isEmpty) return const SizedBox.shrink();

     return GlassContainer(
       opacity: 0.05,
       padding: const EdgeInsets.all(20),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ...items.map((item) {
               final label = item['_id'] ?? 'Unknown';
               final total = item['total'] ?? 0;
               final count = item['count']; // Optional
               
               return Padding(
                 padding: const EdgeInsets.only(bottom: 12.0),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Row(
                       children: [
                         Container(
                           width: 10, height: 10, 
                           decoration: BoxDecoration(
                             color: _getColorFor(label), 
                             shape: BoxShape.circle
                           )
                         ),
                         const SizedBox(width: 10),
                         Text(label.toString().toUpperCase(), style: const TextStyle(color: Colors.white70)),
                       ],
                     ),
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.end,
                       children: [
                          Text(CurrencyFormatter.format(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          if (count != null)
                             Text("$count txns", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                       ],
                     )
                   ],
                 ),
               );
            }).toList()
         ],
       ),
     );
  }

  Color _getColorFor(String label) {
     switch (label.toLowerCase()) {
       case 'service': return AppTheme.primaryColor;
       case 'product': return Colors.pinkAccent;
       case 'paystack': return Colors.blue;
       case 'cash': return Colors.green;
       case 'pos': return Colors.orange;
       case 'transfer': return Colors.purple;
       default: return Colors.grey;
     }
  }
}
