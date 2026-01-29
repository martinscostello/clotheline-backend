import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../theme/app_theme.dart';
import '../../../services/promotion_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/toast_utils.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PromotionService>(context, listen: false).fetchPromotions();
    });
  }

  void _showCreateDialog() {
    showDialog(context: context, builder: (_) => const _CreatePromotionDialog());
  }

  Future<void> _delete(String id) async {
    final success = await Provider.of<PromotionService>(context, listen: false).deletePromotion(id);
    if (success && mounted) {
      ToastUtils.show(context, "Promotion Deleted", type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Promotions", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
        ),
        floatingActionButton: Consumer<AuthService>(
          builder: (context, auth, _) {
            final user = auth.currentUser;
            final isMaster = user?['isMasterAdmin'] == true;
            final canManage = isMaster || (user?['permissions']?['managePromos'] == true);
            
            if (!canManage) return const SizedBox.shrink();

            return FloatingActionButton(
              onPressed: _showCreateDialog,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.black),
            );
          }
        ),
        body: LiquidBackground(
          child: Consumer<PromotionService>(
            builder: (context, promoService, _) {
              // Permission Check
              final auth = Provider.of<AuthService>(context, listen: false);
              final user = auth.currentUser;
              final isMaster = user?['isMasterAdmin'] == true;
              final canManage = isMaster || (user?['permissions']?['managePromos'] == true);

              if (promoService.isLoading && promoService.promotions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (promoService.promotions.isEmpty) {
                return const Center(child: Text("No active promotions", style: TextStyle(color: Colors.white54)));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 80),
                itemCount: promoService.promotions.length,
                itemBuilder: (context, index) {
                  final promo = promoService.promotions[index];
                  final isPercent = promo['type'] == 'percentage';
                  final valueDisplay = isPercent ? "${promo['value']}% OFF" : "₦${promo['value']} OFF";
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: GlassContainer(
                      opacity: 0.1,
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(promo['code'], style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
                              const SizedBox(height: 5),
                              Text(valueDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text("Min Spend: ₦${promo['minOrderAmount']}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              if (promo['usageLimit'] != null)
                                Text("Limit: ${promo['usedCount']}/${promo['usageLimit']}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                          if (canManage)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _delete(promo['_id']),
                            )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CreatePromotionDialog extends StatefulWidget {
  const _CreatePromotionDialog();

  @override
  State<_CreatePromotionDialog> createState() => _CreatePromotionDialogState();
}

class _CreatePromotionDialogState extends State<_CreatePromotionDialog> {
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _minSpendCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  String _type = 'percentage';
  DateTime? _validTo;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF202020),
      title: const Text("Create Promotion", style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Code (e.g. SUMMER20)", labelStyle: TextStyle(color: Colors.white54)),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF303030),
              value: _type,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Type", labelStyle: TextStyle(color: Colors.white54)),
              items: const [
                DropdownMenuItem(value: 'percentage', child: Text("Percentage (%)")),
                DropdownMenuItem(value: 'fixed', child: Text("Fixed Amount (₦)")),
              ],
              onChanged: (val) => setState(() => _type = val!),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _valueCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Value", labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _minSpendCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Min Spend (Optional)", labelStyle: TextStyle(color: Colors.white54)),
            ),
             const SizedBox(height: 10),
            TextField(
              controller: _limitCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Usage Limit (Optional)", labelStyle: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context, 
                  initialDate: DateTime.now().add(const Duration(days: 30)), 
                  firstDate: DateTime.now(), 
                  lastDate: DateTime(2030)
                );
                if (date != null) setState(() => _validTo = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_validTo == null ? "Expiry Date (Optional)" : DateFormat('yyyy-MM-dd').format(_validTo!), style: const TextStyle(color: Colors.white70)),
                    const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
      actions: [
        TextButton(child: const Text("CANCEL"), onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text("CREATE"),
        )
      ],
    );
  }

  Future<void> _save() async {
     if (_codeCtrl.text.isEmpty || _valueCtrl.text.isEmpty) {
        ToastUtils.show(context, "Code and Value required", type: ToastType.warning);
        return;
     }

     setState(() => _isSaving = true);
     
     final data = {
       'code': _codeCtrl.text.trim().toUpperCase(),
       'type': _type,
       'value': double.tryParse(_valueCtrl.text) ?? 0,
       'minOrderAmount': double.tryParse(_minSpendCtrl.text) ?? 0,
       'usageLimit': int.tryParse(_limitCtrl.text),
       'validTo': _validTo?.toIso8601String()
     };

     final success = await Provider.of<PromotionService>(context, listen: false).createPromotion(data);
     
     if (success && mounted) {
       Navigator.pop(context);
       ToastUtils.show(context, "Promotion Created", type: ToastType.success);
     } else {
       if (mounted) {
          setState(() => _isSaving = false);
          ToastUtils.show(context, "Failed to create", type: ToastType.error);
       }
     }
  }
}
