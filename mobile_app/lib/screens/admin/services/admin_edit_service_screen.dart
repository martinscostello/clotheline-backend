import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../../models/service_model.dart';
import '../../../../services/api_service.dart';
import '../../../../services/content_service.dart';
import '../../../../services/laundry_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../../models/branch_model.dart'; // [NEW]
import '../../../../utils/toast_utils.dart';

class AdminEditServiceScreen extends StatefulWidget {
  final ServiceModel? service; 
  final Branch? scopeBranch;
  const AdminEditServiceScreen({super.key, this.service, this.scopeBranch});

  @override
  State<AdminEditServiceScreen> createState() => _AdminEditServiceScreenState();
}

class _AdminEditServiceScreenState extends State<AdminEditServiceScreen> {
  final ValueNotifier<VoidCallback?> _saveTrigger = ValueNotifier(null);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(widget.service == null ? "Create Service" : "Edit ${widget.service!.name}", style: const TextStyle(color: Colors.white, fontSize: 16)),
          backgroundColor: Colors.transparent,
          leading: const BackButton(color: Colors.white),
          actions: [
            ValueListenableBuilder<VoidCallback?>(
              valueListenable: _saveTrigger,
              builder: (context, onSave, _) {
                if (onSave == null) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.check, color: AppTheme.primaryColor),
                  onPressed: onSave,
                );
              },
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: LiquidBackground(
          child: AdminEditServiceBody(
            service: widget.service,
            scopeBranch: widget.scopeBranch,
            saveTrigger: _saveTrigger,
          ),
        ),
      ),
    );
  }
}

class AdminEditServiceBody extends StatefulWidget {
  final bool isEmbedded;
  final ServiceModel? service;
  final Branch? scopeBranch;
  final ValueNotifier<VoidCallback?>? saveTrigger;

  const AdminEditServiceBody({
    super.key, 
    this.isEmbedded = false, 
    this.service, 
    this.scopeBranch,
    this.saveTrigger,
  });

  @override
  State<AdminEditServiceBody> createState() => _AdminEditServiceBodyState();
}

class _AdminEditServiceBodyState extends State<AdminEditServiceBody> {
  final _formKey = GlobalKey<FormState>();
  final ContentService _contentService = ContentService();

  late TextEditingController _nameController;
  late TextEditingController _bannerController;
  late TextEditingController _discountController;
  late TextEditingController _discountLabelController;
  late TextEditingController _inspectionFeeController;
  late TextEditingController _typeLabelController;
  late TextEditingController _subTypeLabelController;
  
  bool _isLocked = false;
  bool _quoteRequired = false;
  double _inspectionFee = 0.0;
  LatLng? _deploymentLocation;
  List<InspectionZone> _inspectionZones = [];
  
  List<ServiceItem> _items = [];
  List<ServiceVariant> _variants = [];
  String _imageUrl = "assets/images/service_laundry.png"; 
  String _color = "0xFF2196F3"; 
  String _icon = "local_laundry_service"; 
  String _fulfillmentMode = "logistics"; 
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameController = TextEditingController(text: s?.name ?? "");
    _bannerController = TextEditingController(text: s?.lockedLabel ?? "Coming Soon");
    _discountController = TextEditingController(text: s?.discountPercentage.toString() ?? "0");
    _discountLabelController = TextEditingController(text: s?.discountLabel ?? "");
    _inspectionFeeController = TextEditingController(text: s?.inspectionFee.toString() ?? "0");
    _typeLabelController = TextEditingController(text: s?.typeLabel ?? "Select Type");
    _subTypeLabelController = TextEditingController(text: s?.subTypeLabel ?? "Service Type");
    
    _isLocked = s?.isLocked ?? false;
    _quoteRequired = s?.quoteRequired ?? false;
    _inspectionFee = s?.inspectionFee ?? 0.0;
    _deploymentLocation = s?.deploymentLocation;
    _inspectionZones = s != null ? List.from(s.inspectionFeeZones) : [];
    
    _items = s != null ? List.from(s.items) : [];
    _variants = s != null ? List.from(s.serviceTypes) : [];
    if (s != null) {
        _imageUrl = s.image;
        _color = s.color;
        _icon = s.icon;
        _fulfillmentMode = s.fulfillmentMode;
    }

    if (widget.saveTrigger != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.saveTrigger!.value = _saveService;
      });
    }
  }

  @override
  void dispose() {
    if (widget.isEmbedded && widget.saveTrigger != null && widget.saveTrigger!.value == _saveService) {
      widget.saveTrigger!.value = null;
    }
    _nameController.dispose();
    _bannerController.dispose();
    _discountController.dispose();
    _discountLabelController.dispose();
    _inspectionFeeController.dispose();
    _typeLabelController.dispose();
    _subTypeLabelController.dispose();
    super.dispose();
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
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
             barrierColor: Colors.black.withOpacity(0.5),
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
      "icon": _icon, 
      "color": _color,
      "isLocked": _isLocked,
      "lockedLabel": _bannerController.text,
      "discountPercentage": double.tryParse(_discountController.text) ?? 0,
      "discountLabel": _discountLabelController.text,
      "typeLabel": _typeLabelController.text,
      "subTypeLabel": _subTypeLabelController.text,
      "fulfillmentMode": _fulfillmentMode,
      "items": _items.map((e) => e.toJson()).toList(),
      "serviceTypes": _variants.map((e) => e.toJson()).toList(),
      "quoteRequired": _quoteRequired,
      "inspectionFee": double.tryParse(_inspectionFeeController.text) ?? 0,
      "deploymentLocation": _deploymentLocation != null ? {"lat": _deploymentLocation!.latitude, "lng": _deploymentLocation!.longitude} : null,
      "inspectionFeeZones": _inspectionZones.map((z) => z.toJson()).toList(),
    };
    
    if (widget.scopeBranch != null) {
       body['branchId'] = widget.scopeBranch!.id;
    }

    try {
      final isNew = widget.service == null;
      final url = isNew 
         ? Uri.parse('${ApiService.baseUrl}/services/') 
         : Uri.parse('${ApiService.baseUrl}/services/${widget.service!.id}');
         
      final response = isNew 
         ? await http.post(url, headers: {"Content-Type": "application/json"}, body: json.encode(body))
         : await http.put(url, headers: {"Content-Type": "application/json"}, body: json.encode(body));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (widget.scopeBranch != null) {
           LaundryService().fetchServices(branchId: widget.scopeBranch!.id);
        } else {
           LaundryService().fetchServices();
        }
        
        if(mounted) {
           if (!widget.isEmbedded) Navigator.pop(context);
           ToastUtils.show(context, "Service saved successfully!", type: ToastType.success);
        }
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
  
  void _showItemDialog([int? index]) {
    final nameCtrl = TextEditingController(text: index != null ? _items[index].name : "");
    List<ServiceOption> nestedServices = index != null ? List.from(_items[index].services) : [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF202020),
          title: Text(
            index == null ? "Add Item Type" : "Edit Item", 
            style: const TextStyle(color: Colors.white)
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl, 
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Item Name (e.g. Shirt, Rug, Room)", 
                      labelStyle: TextStyle(color: Colors.white54), 
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24))
                    )
                  ),
                  const SizedBox(height: 20),
                  const Text("Service Types & Prices", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  ...nestedServices.asMap().entries.map((entry) {
                    final i = entry.key;
                    final s = entry.value;
                    
                    final sNameCtrl = TextEditingController(text: s.name);
                    final sPriceCtrl = TextEditingController(text: s.price.toStringAsFixed(0));
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: sNameCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              onChanged: (val) => s.name = val,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: sPriceCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 13),
                              decoration: const InputDecoration(prefixText: "₦", isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                              onChanged: (val) => s.price = double.tryParse(val) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.white30, size: 20),
                            onPressed: () => setDialogState(() => nestedServices.removeAt(i)),
                          )
                        ],
                      ),
                    );
                  }),
                  const Divider(color: Colors.white12),
                  _buildAddServiceRow((name, price) {
                    setDialogState(() {
                      nestedServices.add(ServiceOption(name: name, price: price));
                    });
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    final newItem = ServiceItem(
                      id: index != null ? _items[index].id : null,
                      name: nameCtrl.text, 
                      price: nestedServices.isNotEmpty ? nestedServices.first.price : 0, 
                      services: nestedServices,
                    );
                    if (index != null) {
                      _items[index] = newItem;
                    } else {
                      _items.add(newItem);
                    }
                  });
                  Navigator.pop(ctx);
                } else {
                  ToastUtils.show(context, "Please enter a name", type: ToastType.error);
                }
              },
            )
          ],
        ),
      )
    );
  }

  Widget _buildAddServiceRow(Function(String, double) onAdd) {
    final sNameCtrl = TextEditingController();
    final sPriceCtrl = TextEditingController();

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: sNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(hintText: "Service (e.g. Wash Only)", hintStyle: TextStyle(color: Colors.white24)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 1,
          child: TextField(
            controller: sPriceCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: const InputDecoration(hintText: "Price", hintStyle: TextStyle(color: Colors.white24)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
          onPressed: () {
            if (sNameCtrl.text.isNotEmpty && sPriceCtrl.text.isNotEmpty) {
              onAdd(sNameCtrl.text, double.tryParse(sPriceCtrl.text) ?? 0);
              sNameCtrl.clear();
              sPriceCtrl.clear();
            }
          },
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color labelColor = isDark ? Colors.white54 : Colors.black54;
    Color subLabelColor = isDark ? Colors.white30 : Colors.black38;
    Color borderLineColor = isDark ? Colors.white24 : Colors.black12;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, widget.isEmbedded ? 20 : 100, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken)
                            ) : null
                          ),
                          child: _imageUrl.isEmpty ? const Icon(Icons.add_a_photo, color: Colors.white24, size: 50) : null,
                        ),
                        const Positioned(
                          right: 10,
                          bottom: 10,
                          child: Icon(Icons.edit, color: Colors.white70),
                        ),
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
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: "Service Name",
                            labelStyle: TextStyle(color: labelColor),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderLineColor))
                          ),
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _fulfillmentMode,
                          dropdownColor: const Color(0xFF2A2A2A),
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: "Fulfillment Mode",
                            labelStyle: TextStyle(color: labelColor),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderLineColor))
                          ),
                          items: const [
                            DropdownMenuItem(value: "logistics", child: Text("Logistics (Pickup & Delivery)")),
                            DropdownMenuItem(value: "deployment", child: Text("Deployment (On-site Inspection)")),
                            DropdownMenuItem(value: "bulky", child: Text("Bulky (Large Item Treatment)")),
                          ],
                          onChanged: (val) => setState(() => _fulfillmentMode = val!),
                        ),
                        const SizedBox(height: 15),
                         Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _discountController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: "Discount %",
                                  labelStyle: TextStyle(color: labelColor),
                                  border: const OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderLineColor))
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                             Expanded(
                              child: TextFormField(
                                controller: _discountLabelController,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: "Label (e.g. 15% OFF)",
                                  labelStyle: TextStyle(color: labelColor),
                                  border: const OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderLineColor))
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                GlassContainer(
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Custom Field Labels", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text("Change how these appear in the booking sheet", style: TextStyle(color: subLabelColor, fontSize: 11)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _typeLabelController,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: "Type Label (e.g. Select Type)",
                                  labelStyle: TextStyle(color: labelColor),
                                  border: const OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderLineColor))
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: TextFormField(
                                controller: _subTypeLabelController,
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  labelText: "Sub-Type Label (e.g. Service Type)",
                                  labelStyle: TextStyle(color: labelColor),
                                  border: const OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderLineColor))
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                GlassContainer(
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Deployment & Inspection", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("Quote Required", style: TextStyle(color: textColor, fontSize: 14)),
                          subtitle: Text("Users pay an inspection fee first", style: TextStyle(color: labelColor, fontSize: 12)),
                          value: _quoteRequired,
                          onChanged: (val) => setState(() => _quoteRequired = val),
                        ),
                        if (_quoteRequired) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _inspectionFeeController,
                            keyboardType: TextInputType.number,
                             style: TextStyle(color: textColor),
                             decoration: InputDecoration(
                               labelText: "Base Inspection Fee (₦)",
                               labelStyle: TextStyle(color: labelColor),
                               border: const OutlineInputBorder(),
                               enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borderLineColor))
                             ),
                          ),
                          const SizedBox(height: 20),
                          const Text("Deployment Origin (Origin Coordinates)", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: _deploymentLocation?.latitude.toString() ?? "0.0",
                                  keyboardType: TextInputType.number,
                                   style: TextStyle(color: textColor, fontSize: 13),
                                   decoration: InputDecoration(labelText: "Latitude", isDense: true, labelStyle: TextStyle(color: labelColor)),
                                   onChanged: (val) => _deploymentLocation = LatLng(double.tryParse(val) ?? 0.0, _deploymentLocation?.longitude ?? 0.0),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  initialValue: _deploymentLocation?.longitude.toString() ?? "0.0",
                                  keyboardType: TextInputType.number,
                                   style: TextStyle(color: textColor, fontSize: 13),
                                   decoration: InputDecoration(labelText: "Longitude", isDense: true, labelStyle: TextStyle(color: labelColor)),
                                   onChanged: (val) => _deploymentLocation = LatLng(_deploymentLocation?.latitude ?? 0.0, double.tryParse(val) ?? 0.0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text("Distance-Based Inspection Zones", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ..._inspectionZones.asMap().entries.map((entry) {
                            final i = entry.key;
                            final zone = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: zone.radiusKm.toString(),
                                       keyboardType: TextInputType.number,
                                       style: TextStyle(color: textColor, fontSize: 13),
                                       decoration: InputDecoration(labelText: "Radius (km)", isDense: true, labelStyle: TextStyle(color: labelColor)),
                                      onChanged: (val) {
                                         setState(() {
                                            _inspectionZones[i] = InspectionZone(radiusKm: double.tryParse(val) ?? 0.0, fee: zone.fee);
                                         });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: zone.fee.toString(),
                                       keyboardType: TextInputType.number,
                                       style: TextStyle(color: textColor, fontSize: 13),
                                       decoration: InputDecoration(labelText: "Fee (₦)", isDense: true, labelStyle: TextStyle(color: labelColor)),
                                      onChanged: (val) {
                                         setState(() {
                                            _inspectionZones[i] = InspectionZone(radiusKm: zone.radiusKm, fee: double.tryParse(val) ?? 0.0);
                                         });
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.white24, size: 20),
                                    onPressed: () => setState(() => _inspectionZones.removeAt(i)),
                                  )
                                ],
                              ),
                            );
                          }),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add Zone"),
                            onPressed: () => setState(() => _inspectionZones.add(InspectionZone(radiusKm: 0, fee: 0))),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                if (_variants.isNotEmpty) 
                  GlassContainer(
                    opacity: 0.1,
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Global Service Multipliers (Legacy)", style: TextStyle(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _variants.map((v) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
                              child: Text("${v.name} (${v.priceMultiplier}x)", style: const TextStyle(color: Colors.white30, fontSize: 11)),
                            )).toList(),
                          )
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                GlassContainer(
                   opacity: 0.1,
                   child: Padding(
                     padding: const EdgeInsets.all(15),
                     child: Column(
                       children: [
                         SwitchListTile(
                           contentPadding: EdgeInsets.zero,
                           title: Text(widget.scopeBranch != null ? "Lock Service (${widget.scopeBranch!.name})" : "Global Lock", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                           subtitle: Text("Prevent users from booking this service", style: TextStyle(color: labelColor, fontSize: 12)),
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

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(widget.scopeBranch != null ? "Edit Prices (${widget.scopeBranch!.name})" : "Types & Prices", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                             Text("${item.services.length} services", style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 12)),
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
                
                const SizedBox(height: 100), 
              ],
            ),
          ),
        ),
        
        if (!widget.isEmbedded)
           Positioned(
             top: 10,
             right: 20,
             child: IconButton(
               icon: _isSaving 
                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                 : const Icon(Icons.check, color: AppTheme.primaryColor),
               onPressed: _isSaving ? null : _saveService,
             ),
           ),
      ],
    );
  }
}
