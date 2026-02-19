import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../providers/report_provider.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../utils/currency_formatter.dart';

class StaffPerformanceTable extends StatelessWidget {
  const StaffPerformanceTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
          final List<dynamic> performance = provider.analytics?['staffPerformance'] ?? [];

          if (performance.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Text("Staff Performance", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
               GlassContainer(
                 opacity: 0.1,
                 padding: const EdgeInsets.all(16),
                 child: Column(
                   children: [
                     // Header
                     const Row(
                       children: [
                         Expanded(flex: 3, child: Text("Staff", style: TextStyle(color: Colors.white54, fontSize: 12))),
                         Expanded(flex: 2, child: Text("Orders", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12))),
                         Expanded(flex: 3, child: Text("Revenue", textAlign: TextAlign.right, style: TextStyle(color: Colors.white54, fontSize: 12))),
                       ],
                     ),
                     const Divider(color: Colors.white24),
                     
                     // Rows
                     ...performance.map((staff) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                               Expanded(
                                 flex: 3, 
                                 child: Text(
                                   staff['_id'] ?? 'Unknown', 
                                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
                                 )
                               ),
                               Expanded(
                                 flex: 2, 
                                 child: Text(
                                   "${staff['count']}", 
                                   textAlign: TextAlign.center,
                                   style: const TextStyle(color: Colors.white70)
                                 )
                               ),
                               Expanded(
                                 flex: 3, 
                                 child: Text(
                                   CurrencyFormatter.format((staff['revenue'] ?? 0)), 
                                   textAlign: TextAlign.right,
                                   style: const TextStyle(color: AppTheme.primaryColor)
                                 )
                               ),
                            ],
                          ),
                        );
                     }).toList(),
                   ],
                 ),
               ),
            ],
          );
      }
    );
  }
}
