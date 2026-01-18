import 'package:flutter/material.dart';
import '../../../../models/service_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/content_service.dart';
import '../../../../services/laundry_service.dart';
import 'package:provider/provider.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../models/branch_model.dart'; // [NEW]
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/toast/top_toast.dart';

class AdminEditServiceScreen extends StatefulWidget {
  final ServiceModel? service; // [CHANGED] Nullable for Creation Mode
  final Branch? scopeBranch;
  const AdminEditServiceScreen({super.key, this.service, this.scopeBranch});

  @override
  State<AdminEditServiceScreen> createState() => _AdminEditServiceScreenState();
}

class _AdminEditServiceScreenState extends State<AdminEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final ContentService _contentService = ContentService();

  late TextEditingController _nameController;
  late TextEditingController _bannerController;
  late TextEditingController _discountController;
  late TextEditingController _discountLabelController;
  
  bool _isLocked = false;
  List<ServiceItem> _items = [];
  List<ServiceVariant> _variants = [];
  String _imageUrl = "assets/images/service_laundry.png"; // Default
  String _color = "0xFF2196F3"; // Default Blue
  String _icon = "local_laundry_service"; // Default
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameController = TextEditingController(text: s?.name ?? "");
    _bannerController = TextEditingController(text: s?.lockedLabel ?? "Coming Soon");
    _discountController = TextEditingController(text: s?.discountPercentage.toString() ?? "0");
    _discountLabelController = TextEditingController(text: s?.discountLabel ?? "");
    
    _isLocked = s?.isLocked ?? false;
    _items = s != null ? List.from(s.items) : [];
    _variants = s != null ? List.from(s.serviceTypes) : [];
    if (s != null) {
        _imageUrl = s.image;
        _color = s.color;
        _icon = s.icon;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
       CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Service Image',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio4x3,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Service Image',
          ),
        ],
      );

      if (croppedFile != null) {
         setState(() => _isSaving = true);
         String? url = await _contentService.uploadImage(croppedFile.path);
         setState(() => _isSaving = false);
         if (url != null) {
           setState(() => _imageUrl = url);
         }
      }
    }
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final Map<String, dynamic> body = {
      "name": _nameController.text,
      "image": _imageUrl,
      "icon": _icon, // Ensure these are sent
      "color": _color,
      "isLocked": _isLocked,
      "lockedLabel": _bannerController.text,
      "discountPercentage": double.tryParse(_discountController.text) ?? 0,
      "discountLabel": _discountLabelController.text,
      "items": _items.map((e) => e.toJson()).toList(),
      "serviceTypes": _variants.map((e) => e.toJson()).toList(),
    };
    
    if (widget.scopeBranch != null) {
       body['branchId'] = widget.scopeBranch!.id;
    }

    try {
      final isNew = widget.service == null;
      final url = isNew 
         ? Uri.parse('${ApiService.baseUrl}/services/') // [FIXED] Correct Route
         : Uri.parse('${ApiService.baseUrl}/services/${widget.service!.id}');
         
      final response = isNew 
         ? await http.post(url, headers: {"Content-Type": "application/json"}, body: json.encode(body))
         : await http.put(url, headers: {"Content-Type": "application/json"}, body: json.encode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh 
        if (widget.scopeBranch != null) {
           LaundryService().fetchServices(branchId: widget.scopeBranch!.id);
        } else {
           LaundryService().fetchServices();
        }
        
        if(mounted) Navigator.pop(context);
      } else {
        if(mounted) ToastUtils.show(context, "Failed to save: ${response.statusCode}", type: ToastType.error);
      }
    } catch (e) {
      if(mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  void _addItem() {
    _showItemDialog();
  }
  
  void _showVariantDialog([int? index]) {
    final nameCtrl = TextEditingController(text: index != null ? _variants[index].name : "");
    final multCtrl = TextEditingController(text: index != null ? _variants[index].priceMultiplier.toString() : "1.0");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: Text(index == null ? "Add Service Type" : "Edit Service Type", style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextField(
               controller: nameCtrl, 
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(labelText: "Type Name (e.g. Wash & Fold)", labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))
             ),
             const SizedBox(height: 10),
             TextField(
               controller: multCtrl, 
               keyboardType: const TextInputType.numberWithOptions(decimal: true),
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(labelText: "Price Multiplier (e.g. 1.5)", labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))
             ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: (){
             if(nameCtrl.text.isNotEmpty && multCtrl.text.isNotEmpty) {
               final newVariant = ServiceVariant(
                 name: nameCtrl.text, 
                 priceMultiplier: double.tryParse(multCtrl.text) ?? 1.0
               );
               
               setState(() {
                 if (index != null) {
                   _variants[index] = newVariant;
                 } else {
                   _variants.add(newVariant);
                 }
               });
               Navigator.pop(ctx);
             }
          }, child: const Text("Save"))
        ],
      )
    );
  }

  void _showItemDialog([int? index]) {
    final nameCtrl = TextEditingController(text: index != null ? _items[index].name : "");
    final priceCtrl = TextEditingController(text: index != null ? _items[index].price.toString() : "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF202020),
        title: Text(
          widget.scopeBranch != null 
             ? "Edit Price for ${widget.scopeBranch!.name}" 
             : (index == null ? "Add Cloth Type" : "Edit Item"), 
          style: const TextStyle(color: Colors.white)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl, 
              // [Stict Branch Independence] Name editing is allowed everywhere
              enabled: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Name", labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))
            ),
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
                  // [FIX] Preserve ID if editing existing item
                  final newItem = ServiceItem(
                    id: index != null ? _items[index].id : null,
                    name: nameCtrl.text, 
                    price: double.tryParse(priceCtrl.text) ?? 0
                  );
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
        title: Text(widget.service == null ? "Create Service" : "Edit ${widget.service!.name}", style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                // 0. Image Section
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.black26,
                            image: _imageUrl.isNotEmpty ? DecorationImage(
                              image: NetworkImage(_imageUrl),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.3), BlendMode.darken)
                            ) : null
                          ),
                          child: _imageUrl.isEmpty ? const Icon(Icons.add_a_photo, color: Colors.white24, size: 50) : null,
                        ),
                        const Positioned(
                          right: 10,
                          bottom: 10,
                          child: Icon(Icons.edit, color: Colors.white70),
                        ),
                        // Dimension Helper Badge
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: const Text("Recommended: 800x600", style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

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
                            const SizedBox(width: 15),
                             Expanded(
                              child: TextFormField(
                                controller: _discountLabelController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: "Label (e.g. 15% OFF)",
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
                
                // 2. Service Types (Variants) - NEW
                 GlassContainer(
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.scopeBranch != null ? "Service Types (${widget.scopeBranch!.name})" : "Service Types", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            IconButton(icon: const Icon(Icons.add, color: AppTheme.primaryColor), onPressed: () => _showVariantDialog())
                          ],
                        ),
                        if (_variants.isEmpty)
                         const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text("No service types defined", style: TextStyle(color: Colors.white38, fontSize: 12))),
                         
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _variants.asMap().entries.map((entry) {
                            final index = entry.key;
                            final v = entry.value;
                            return GestureDetector(
                              onTap: () => _showVariantDialog(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("${v.name} (${v.priceMultiplier}x)", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => setState(() => _variants.removeAt(index)),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  ),
                 ),

                const SizedBox(height: 20),

                // 3. Access Control (Locking)
                GlassContainer(
                   opacity: 0.1,
                   child: Padding(
                     padding: const EdgeInsets.all(15),
                     child: Column(
                       children: [
                         SwitchListTile(
                           contentPadding: EdgeInsets.zero,
                           title: Text(widget.scopeBranch != null ? "Lock Service (${widget.scopeBranch!.name})" : "Global Lock", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

                const SizedBox(height: 20),

                // 4. Manage Items (Cloth Types)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.scopeBranch != null ? "Edit Prices (${widget.scopeBranch!.name})" : "Cloth Types & Prices", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    
                    // [Branch Independence] ALWAYS Allow Adding Items.
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor), 
                      onPressed: _addItem
                    )
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
