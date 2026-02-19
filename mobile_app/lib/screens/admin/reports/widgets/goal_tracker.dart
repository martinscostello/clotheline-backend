import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../providers/report_provider.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/toast_utils.dart';

class GoalTracker extends StatelessWidget {
  const GoalTracker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
          final data = provider.financials;
          final goal = data?['goal']; // { target: 1000000, progress: 45.5 }
          
          if (goal == null) {
             return GestureDetector(
               onTap: () => _showSetGoalDialog(context),
               child: GlassContainer(
                 opacity: 0.1,
                 padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                 child: const Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Icon(Icons.flag, color: AppTheme.secondaryColor),
                     SizedBox(width: 10),
                     Text("Set Monthly Revenue Goal", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                   ],
                 ),
               ),
             );
          }
          
          final double progress = (goal['progress'] as num?)?.toDouble() ?? 0.0;
          final double target = (goal['target'] as num?)?.toDouble() ?? 1.0;
          final double cappedProgress = progress > 100 ? 100 : progress;

          return GlassContainer(
            opacity: 0.1,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Monthly Goal", style: TextStyle(color: Colors.white70)),
                    GestureDetector(
                      onTap: () => _showSetGoalDialog(context),
                      child: const Icon(Icons.edit, color: Colors.white24, size: 16),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${progress.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text("Target: ${CurrencyFormatter.compact(target / 100)}", style: const TextStyle(color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: cappedProgress / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 100 ? Colors.greenAccent : AppTheme.secondaryColor
                    ),
                  ),
                ),
                if (data?['projectedRevenue'] != null) ...[
                   const SizedBox(height: 10),
                   Text(
                     "Projected: ${CurrencyFormatter.format((data?['projectedRevenue'] ?? 0) / 100)}", 
                     style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontStyle: FontStyle.italic)
                   )
                ]
              ],
            ),
          );
      }
    );
  }
  
  void _showSetGoalDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Set Monthly Goal", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: amountCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Target (Naira)", labelStyle: TextStyle(color: Colors.white54)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(amountCtrl.text);
              if (val == null) return;
              
              final branchId = Provider.of<ReportProvider>(context, listen: false).selectedBranchId;
              
              // Determine Dates for "This Month" goal
              final now = DateTime.now();
              final start = DateTime(now.year, now.month, 1);
              final end = DateTime(now.year, now.month + 1, 0); // Last day
              
              final success = await Provider.of<ReportProvider>(context, listen: false).addGoal({
                'targetAmount': val * 100, // Kobo
                'period': 'Monthly',
                'branchId': branchId, // Can be null (Global)
                'startDate': start.toIso8601String(),
                'endDate': end.toIso8601String()
              });
              
              if (success && context.mounted) {
                 Navigator.pop(ctx);
                 ToastUtils.show(context, "Goal Updated", type: ToastType.success);
              }
            },
            child: const Text("Set Goal"),
          )
        ],
      )
    );
  }
}
