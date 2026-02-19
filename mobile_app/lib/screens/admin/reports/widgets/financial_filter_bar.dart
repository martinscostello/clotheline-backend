import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../providers/report_provider.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../widgets/glass/GlassContainer.dart';

class FinancialFilterBar extends StatelessWidget {
  const FinancialFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              // Branch Selector
              Expanded(
                child: Consumer<BranchProvider>(
                  builder: (context, branchProvider, _) {
                    return Consumer<ReportProvider>(
                      builder: (context, reportProvider, _) {
                         return GlassContainer(
                           height: 50,
                           opacity: 0.1,
                           padding: const EdgeInsets.symmetric(horizontal: 15),
                           child: DropdownButtonHideUnderline(
                             child: DropdownButton<String?>(
                               dropdownColor: const Color(0xFF1E1E2C),
                               value: reportProvider.selectedBranchId,
                               hint: const Text("All Branches", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                               icon: const Icon(Icons.store, color: AppTheme.secondaryColor),
                               onChanged: (val) => reportProvider.setBranch(val),
                               items: [
                                  const DropdownMenuItem<String?>(
                                    value: null, 
                                    child: Text("All Branches", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                  ),
                                  ...branchProvider.branches.map((b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(b.name, style: const TextStyle(color: Colors.white70))
                                  ))
                               ],
                             ),
                           ),
                         );
                      }
                    );
                  }
                ),
              ),
              const SizedBox(width: 10),
              
              // Date Range Selector
              Expanded(
                child: Consumer<ReportProvider>(
                  builder: (context, reportProvider, _) {
                    return GlassContainer(
                      height: 50,
                      opacity: 0.1,
                       padding: const EdgeInsets.symmetric(horizontal: 15),
                       child: DropdownButtonHideUnderline(
                         child: DropdownButton<String>(
                           dropdownColor: const Color(0xFF1E1E2C),
                           value: reportProvider.rangeLabel == "Custom" ? null : reportProvider.rangeLabel,
                           hint: Text(reportProvider.rangeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                           icon: const Icon(Icons.calendar_today, color: AppTheme.secondaryColor),
                           onChanged: (val) {
                             if (val == "Custom") {
                               _showCustomDateRangePicker(context);
                             } else if (val != null) {
                               reportProvider.setDateRange(val);
                             }
                           },
                           items: ["Today", "This Week", "This Month", "This Year", "All Time", "Custom"]
                             .map((e) => DropdownMenuItem(
                               value: e,
                               child: Text(e, style: const TextStyle(color: Colors.white70))
                             )).toList(),
                         ),
                       ),
                    );
                  }
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomDateRangePicker(BuildContext context) async {
      final DateTimeRange? result = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2023),
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: AppTheme.darkTheme.copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppTheme.primaryColor,
                onPrimary: Colors.black,
                surface: Color(0xFF1E1E2C),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        }
      );

      if (result != null) {
         Provider.of<ReportProvider>(context, listen: false).setCustomRange(result.start, result.end);
      }
  }
}
