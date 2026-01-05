import 'package:flutter/material.dart';
import '../../../../models/service_model.dart';
import '../../../../services/api_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminEditServiceScreen extends StatefulWidget {
  final ServiceModel service;
  const AdminEditServiceScreen({super.key, required this.service});

  @override
  State<AdminEditServiceScreen> createState() => _AdminEditServiceScreenState();
}

class _AdminEditServiceScreenState extends State<AdminEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bannerController;
  late TextEditingController _discountController;
  
  bool _isLocked = false;
  List<ServiceItem> _items = [];
  List<ServiceVariant> _variants = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.service.name);
    _bannerController = TextEditingController(text: widget.service.lockedLabel);
    _discountController = TextEditingController(text: widget.service.discountPercentage.toString());
    _isLocked = widget.service.isLocked;
    _items = List.from(widget.service.items);
    _variants = List.from(widget.service.serviceTypes);
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final Map<String, dynamic> body = {
      "name": _nameController.text,
      "isLocked": _isLocked,
      "lockedLabel": _bannerController.text,
      "discountPercentage": double.tryParse(_discountController.text) ?? 0,
      "items": _items.map((e) => e.toJson()).toList(),
      "serviceTypes": _variants.map((e) => e.toJson()).toList(),
    };

    try {
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}/services/${widget.service.id}'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        if(mounted) Navigator.pop(context);
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save changes")));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  void _addItem() {
    _showItemDialog();
  }

  void _showItemDialog([int? index]) {
    final nameCtrl = TextEditingController(text: index != null ? _items[index].name : "");
    final priceCtrl = TextEditingController(text: index != null ? _items[index].price.toString() : "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: Text(index == null ? "Add Cloth Type" : "Edit Item", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name", labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))), style: const TextStyle(color: Colors.white)),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price (₦)", labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))), style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                setState(() {
                  final newItem = ServiceItem(name: nameCtrl.text, price: double.tryParse(priceCtrl.text) ?? 0);
                  if (index != null) {
                    _items[index] = newItem;
                  } else {
                    _items.add(newItem);
                  }
                });
                Navigator.pop(ctx);
              }
            },
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Edit ${widget.service.name}", style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, color: AppTheme.primaryColor),
            onPressed: _isSaving ? null : _saveService,
          )
        ],
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. General Settings
                GlassContainer(
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("General Settings", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Service Name",
                            labelStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))
                          ),
                        ),
                        const SizedBox(height: 15),
                         Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _discountController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: "Discount %",
                                  labelStyle: TextStyle(color: Colors.white54),
                                  border: OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 2. Access Control (Locking)
                GlassContainer(
                   opacity: 0.1,
                   child: Padding(
                     padding: const EdgeInsets.all(15),
                     child: Column(
                       children: [
                         SwitchListTile(
                           contentPadding: EdgeInsets.zero,
                           title: const Text("Lock Service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                           subtitle: const Text("Prevent users from booking this service", style: TextStyle(color: Colors.white54, fontSize: 12)),
                           value: _isLocked,
                           activeColor: Colors.redAccent,
                           onChanged: (val) => setState(() => _isLocked = val),
                         ),
                         if (_isLocked)
                           TextFormField(
                              controller: _bannerController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: "Banner Text (e.g. Coming Soon)",
                                labelStyle: TextStyle(color: Colors.white54),
                                border: OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24))
                              ),
                            ),
                       ],
                     ),
                   ),
                ),

                const SizedBox(height: 20),

                // 3. Manage Items (Cloth Types)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Cloth Types & Prices", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor), onPressed: _addItem)
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                     return Card(
                       color: Colors.white10,
                       margin: const EdgeInsets.only(bottom: 8),
                       child: ListTile(
                         title: Text(item.name, style: const TextStyle(color: Colors.white)),
                         trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Text("₦${item.price.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.secondaryColor)),
                             const SizedBox(width: 10),
                             IconButton(
                               icon: const Icon(Icons.delete, color: Colors.white30, size: 20),
                               onPressed: () => setState(() => _items.removeAt(i)),
                             )
                           ],
                         ),
                         onTap: () => _showItemDialog(i),
                       ),
                     );
                  },
                ),
                
                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}
