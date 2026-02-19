import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../providers/report_provider.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../utils/toast_utils.dart';

class ExpenseTracker extends StatelessWidget {
  const ExpenseTracker({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Expenses", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add, color: AppTheme.primaryColor),
              label: const Text("Add Expense", style: TextStyle(color: AppTheme.primaryColor)),
              onPressed: () => _showAddExpenseDialog(context),
            )
          ],
        ),
        const SizedBox(height: 10),
        Consumer<ReportProvider>(
          builder: (context, provider, _) {
             final expenses = provider.expenses;
             if (expenses.isEmpty) {
               return GlassContainer(
                 opacity: 0.05,
                 padding: const EdgeInsets.all(20),
                 child: const Center(child: Text("No expenses recorded for this period", style: TextStyle(color: Colors.white54))),
               );
             }

             return ListView.separated(
               shrinkWrap: true,
               physics: const NeverScrollableScrollPhysics(),
               itemCount: expenses.length,
               separatorBuilder: (_, __) => const SizedBox(height: 10),
               itemBuilder: (context, index) {
                 final e = expenses[index];
                 return GlassContainer(
                   opacity: 0.1,
                   padding: const EdgeInsets.all(15),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(e['title'] ?? 'Expense', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                           Text(e['category'] ?? 'Other', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                         ],
                       ),
                       Text(
                         "- ${CurrencyFormatter.format((e['amount'] ?? 0) / 100)}", 
                         style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
                       ),
                     ],
                   ),
                 );
               },
             );
          }
        )
      ],
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'Other';
    String? branchId = Provider.of<ReportProvider>(context, listen: false).selectedBranchId; // Default to selected filter

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2C),
            title: const Text("Log Expense", style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Branch Selector (if admin has access to multiple)
                  Consumer<BranchProvider>(
                    builder: (context, bp, _) {
                      return DropdownButton<String>(
                        dropdownColor: const Color(0xFF2C2C3E),
                        value: branchId,
                        hint: const Text("Select Branch", style: TextStyle(color: Colors.white54)),
                         isExpanded: true,
                        items: bp.branches.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, style: const TextStyle(color: Colors.white)),
                        )).toList(),
                        onChanged: (val) => setState(() => branchId = val),
                      );
                    }
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Description", labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  TextField(
                    controller: amountCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Amount (Naira)", labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                     dropdownColor: const Color(0xFF2C2C3E),
                     value: category,
                     isExpanded: true,
                     items: ['Salaries', 'Utilities', 'Rent', 'Maintenance', 'Supplies', 'Marketing', 'Logistics', 'Other']
                       .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                     onChanged: (val) => setState(() => category = val!),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                   if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty || branchId == null) {
                     ToastUtils.show(context, "Please fill all fields", type: ToastType.warning);
                     return;
                   }
                   
                   final amountKobo = (double.tryParse(amountCtrl.text) ?? 0) * 100;
                   
                   final success = await Provider.of<ReportProvider>(context, listen: false).addExpense({
                     'branchId': branchId,
                     'title': titleCtrl.text,
                     'amount': amountKobo,
                     'category': category
                   });
                   
                   if (success && context.mounted) {
                     Navigator.pop(ctx);
                     ToastUtils.show(context, "Expense Added", type: ToastType.success);
                   }
                },
                child: const Text("Save"),
              )
            ],
          );
        }
      )
    );
  }
}
