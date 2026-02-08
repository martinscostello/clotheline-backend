import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../services/store_service.dart';
// Added Import
import '../../../services/api_service.dart'; // For Base URL
import '../../../models/store_product.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/toast_utils.dart';
import '../../../widgets/custom_cached_image.dart';
import '../../../widgets/products/SalesBanner.dart'; // [NEW] 
import 'package:flutter_colorpicker/flutter_colorpicker.dart'; // [NEW]

class AdminAddProductScreen extends StatefulWidget {
  final StoreProduct? product; // If provided, we are editing
  final String branchId; // [STRICT SCOPE] Required
  const AdminAddProductScreen({super.key, this.product, required this.branchId});

  @override
  State<AdminAddProductScreen> createState() => _AdminAddProductScreenState();
}

class _AdminAddProductScreenState extends State<AdminAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  bool _isLoading = false;

  // Form Fields
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _brandController; // Added
  late TextEditingController _basePriceController; // Was _priceController
  late TextEditingController _discountController; // Was _originalPriceController
  late TextEditingController _stockController;
  String _selectedCategory = "Cleaning";
  bool _isFreeShipping = false;
  bool _isOutOfStock = false; // [NEW]

  // Images
  List<UploadItem> _uploadItems = []; // Unified list

  // Variants
  List<ProductVariant> _variants = [];
  List<BranchProductInfo> _branchInfo = [];

  // Sales Banner [NEW]
  late SalesBannerConfig _bannerConfig;
  late SalesBannerConfig _detailBannerConfig; // [NEW]

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? "");
    _descController = TextEditingController(text: p?.description ?? "");
    _brandController = TextEditingController(text: p?.brand ?? "Generic");
    
    double basePrice = (p?.originalPrice != null && p!.originalPrice > 0) ? p.originalPrice : (p?.price ?? 0);
    _basePriceController = TextEditingController(text: p != null ? basePrice.toString() : "");
    
    _discountController = TextEditingController(text: p?.discountPercentage.toString() ?? "0");
    _stockController = TextEditingController(text: p?.stockLevel.toString() ?? "10");
    _selectedCategory = p?.category ?? "Cleaning";
    _isFreeShipping = p?.isFreeShipping ?? false;
    _isOutOfStock = p?.isOutOfStock ?? false; // [NEW]
    
    _bannerConfig = p?.salesBanner ?? SalesBannerConfig();
    _detailBannerConfig = p?.detailBanner ?? SalesBannerConfig.defaultDetail(); // [NEW]
    
    // Initialize existing images as 'completed' uploads
    if (p?.imageUrls != null) {
      _uploadItems = p!.imageUrls.map((url) => UploadItem(
        id: DateTime.now().millisecondsSinceEpoch.toString() + url.hashCode.toString(),
        status: UploadStatus.success,
        serverUrl: url,
      )).toList();
    }


  
    _variants = p?.variants ?? [];
    _branchInfo = List.from(p?.branchInfo ?? []);
    
    // Fetch latest categories
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StoreService>(context, listen: false).fetchCategories();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _brandController.dispose(); // Added
    _basePriceController.dispose();
    _discountController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      for (var xFile in images) {
        final file = File(xFile.path);
        final id = DateTime.now().microsecondsSinceEpoch.toString();
        final item = UploadItem(id: id, localFile: file, status: UploadStatus.uploading);
        
        setState(() => _uploadItems.add(item));
        _uploadFile(item);
      }
    }
  }

  Future<void> _uploadFile(UploadItem item) async {
    if (item.localFile == null) return;

    try {
      final dio = Dio();
      final uploadUrl = '${ApiService.baseUrl}/upload';
      String fileName = item.localFile!.path.split('/').last;
      
      FormData formData = FormData.fromMap({
        "image": await MultipartFile.fromFile(item.localFile!.path, filename: fileName),
      });

      await dio.post(
        uploadUrl, 
        data: formData,
        onSendProgress: (sent, total) {
          if (mounted) {
            setState(() {
              item.progress = sent / total;
            });
          }
        },
      ).then((response) {
        if (response.statusCode == 200) {
            String path = response.data['filePath'];
            String fullUrl;
            if (path.startsWith('http')) {
              fullUrl = path;
            } else {
              fullUrl = "https://clotheline-api.onrender.com$path";
            }
 
            if (mounted) {
              setState(() {
                item.serverUrl = fullUrl;
                item.status = UploadStatus.success;
                item.progress = 1.0;
              });
            }
        } else {
          throw Exception("Status ${response.statusCode}");
        }
      });
    } catch (e) {
      debugPrint("Upload Error: $e");
      if (mounted) {
        setState(() {
          item.status = UploadStatus.error;
          item.progress = 0.0;
        });
      }
    }
  }

  Future<void> _uploadImagesAndSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Check if any uploads are pending
    if (_uploadItems.any((i) => i.status == UploadStatus.uploading)) {
       ToastUtils.show(context, "Please wait for images to finish uploading", type: ToastType.info);
       return;
    }

    // Check if any failed
    if (_uploadItems.any((i) => i.status == UploadStatus.error)) {
       ToastUtils.show(context, "Some images failed to upload. Please remove or retry them.", type: ToastType.error);
       return;
    }

    setState(() => _isLoading = true);

    try {
      List<String> finalImageUrls = _uploadItems
          .where((i) => i.status == UploadStatus.success && i.serverUrl != null)
          .map((i) => i.serverUrl!)
          .toList();

      // 2. Prepare Data & Calculate Prices
      double basePrice = double.tryParse(_basePriceController.text) ?? 0.0;
      double discountPct = double.tryParse(_discountController.text) ?? 0.0;
      
      // Calculate main product selling price
      double sellingPrice = basePrice * (1 - (discountPct / 100));

      final productData = {
        "branchId": widget.branchId, // [STRICT SCOPE] Required
        "name": _nameController.text,
        "description": _descController.text,
        "brand": _brandController.text, 
        "price": sellingPrice,
        "originalPrice": basePrice,
        "discountPercentage": discountPct,
        "stock": int.tryParse(_stockController.text) ?? 0,
        "category": _selectedCategory,
        "isFreeShipping": _isFreeShipping,
        "isOutOfStock": _isOutOfStock, // [NEW]
        "imageUrls": finalImageUrls,
        "variations": _variants.map((v) {
          double vBase = v.originalPrice > 0 ? v.originalPrice : v.price;
          double vSelling = vBase * (1 - (discountPct / 100));
          return {
            "name": v.name, 
            "price": vSelling, 
            "originalPrice": vBase 
          };
        }).toList(),
        "salesBanner": _bannerConfig.toJson(), 
        "detailBanner": _detailBannerConfig.toJson(), // [NEW]
        // Removed Legacy "branchInfo" override
      };

      // 3. Send to Store Service
      debugPrint("Sending Product Data: $productData");
      
      bool success;
      if (widget.product != null) {
        success = await Provider.of<StoreService>(context, listen: false).updateProduct(widget.product!.id, productData);
      } else {
        success = await Provider.of<StoreService>(context, listen: false).addProduct(productData);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          Navigator.pop(context);
        } else {
          ToastUtils.show(context, "Failed to save product", type: ToastType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = "Error: $e";
        if (e is DioException) {
          if (e.response?.data != null) {
             errorMsg = "Server Error: ${e.response?.data}";
          } else {
             errorMsg = "Network Error: ${e.message}";
          }
        }
        ToastUtils.show(context, errorMsg, type: ToastType.error);
      }
    }
  }
  
  void _addVariant() {
    // Show Dialog to add variant
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: _basePriceController.text); // Default to base price
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF202020),
      title: const Text("Add Variant", style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name (e.g. Size L)", labelStyle: TextStyle(color: Colors.white70)), style: const TextStyle(color: Colors.white)),
          TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Base Price", labelStyle: TextStyle(color: Colors.white70)), style: const TextStyle(color: Colors.white)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(onPressed: () {
          if (nameCtrl.text.isNotEmpty) {
             setState(() {
               double vBasePrice = double.tryParse(priceCtrl.text) ?? 0;
               // We temporarily set price = basePrice (originalPrice)
               // The actual discounted price will be calculated on Save
               _variants.add(ProductVariant(
                 id: DateTime.now().toString(), 
                 name: nameCtrl.text, 
                 price: vBasePrice, 
                 originalPrice: vBasePrice
               ));
             });
             Navigator.pop(ctx);
          }
        }, child: const Text("Add", style: TextStyle(color: AppTheme.primaryColor))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.product == null ? "Add Product" : "Edit Product", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        actions: [
          if (widget.product != null)
             IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDelete)
        ],
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 30),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Image Section
                SizedBox(
                  height: 120,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Add Button
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white24)
                          ),
                          child: const Icon(Icons.add_a_photo, color: Colors.white54),
                        ),
                      ),
                      // Upload Items
                      ..._uploadItems.map((item) {
                         return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: item.status == UploadStatus.error 
                                      ? Colors.red 
                                      : item.status == UploadStatus.success 
                                          ? Colors.green.withOpacity(0.5) 
                                          : Colors.white12
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: item.localFile != null
                                  ? Image.file(item.localFile!, fit: BoxFit.cover)
                                  : CustomCachedImage(
                                      imageUrl: item.serverUrl!,
                                      fit: BoxFit.cover,
                                      borderRadius: 0,
                                    ),
                            ),
                            
                            // Uploading Overlay
                            if (item.status == UploadStatus.uploading)
                              Positioned.fill(
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: item.progress > 0 ? item.progress : null, 
                                      color: AppTheme.primaryColor,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              ),
                              
                            // Error Overlay
                            if (item.status == UploadStatus.error)
                               Positioned.fill(
                                child: GestureDetector(
                                  onTap: () => _uploadFile(item), // Retry
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.refresh, color: Colors.white),
                                        Text("Retry", style: TextStyle(color: Colors.white, fontSize: 10))
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Remove Button
                            Positioned(
                              top: 5, right: 15,
                              child: GestureDetector(
                                onTap: () => setState(() => _uploadItems.remove(item)),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            )
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Info Fields
                _buildGlassTextField(controller: _nameController, label: "Product Name", textInputAction: TextInputAction.next),
                const SizedBox(height: 15),
                _buildGlassTextField(controller: _descController, label: "Description", maxLines: 3, textInputAction: TextInputAction.next),
                const SizedBox(height: 15),
                _buildGlassTextField(controller: _brandController, label: "Brand (e.g. Rolex, Generic)", textInputAction: TextInputAction.next), // Added
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    Expanded(child: _buildGlassTextField(controller: _basePriceController, label: "Base Price", isNumber: true, textInputAction: TextInputAction.next)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildGlassTextField(controller: _discountController, label: "Discount %", isNumber: true, textInputAction: TextInputAction.next)),
                  ],
                ),
                const SizedBox(height: 15),

                // 3. Category & Stock
                 Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                         decoration: BoxDecoration(
                           color: Colors.white10,
                           borderRadius: BorderRadius.circular(15),
                           border: Border.all(color: Colors.white12)
                         ),
                         child: Consumer<StoreService>( // Use Consumer for better updates
                           builder: (context, store, child) {
                             final categories = store.categories.where((c) => c != "All").toList();
                             
                             // Ensure selected value exists in list (or set to null)
                             String? dropdownValue = _selectedCategory;
                             if (!categories.contains(dropdownValue)) {
                               dropdownValue = null;
                             }

                             return DropdownButtonHideUnderline(
                               child: DropdownButton<String>(
                                 value: dropdownValue,
                                 hint: const Text("Select Category", style: TextStyle(color: Colors.white54)),
                                 dropdownColor: const Color(0xFF2C2C2C),
                                 style: const TextStyle(color: Colors.white),
                                 isExpanded: true,
                                 items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), 
                                 onChanged: (val) {
                                   if (val != null) {
                                      setState(() => _selectedCategory = val);
                                   }
                                 },
                               ),
                             );
                           }
                         ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildGlassTextField(controller: _stockController, label: "Stock", isNumber: true, textInputAction: TextInputAction.done)
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 4. Switches
                SwitchListTile(
                  title: const Text("Free Shipping", style: TextStyle(color: Colors.white)),
                  value: _isFreeShipping,
                  activeTrackColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _isFreeShipping = val),
                ),
                SwitchListTile(
                  title: const Text("Out of Stock (Manual)", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Display as unavailable but keep visible", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  value: _isOutOfStock,
                  activeTrackColor: Colors.orangeAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _isOutOfStock = val),
                ),

                const SizedBox(height: 20),

                // 5. Variants
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Variants", style: TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor), onPressed: _addVariant)
                  ],
                ),
                if (_variants.isEmpty) const Text("No variants added", style: TextStyle(color: Colors.white30)),
                ..._variants.map((v) {
                   // Display calc:
                   double displayBase = v.originalPrice > 0 ? v.originalPrice : v.price;
                   return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(v.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text("Base: ${CurrencyFormatter.format(displayBase)}", style: const TextStyle(color: Colors.white38)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         // Show check or something for implied discount? 
                         // Just show 'base'
                         IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() => _variants.remove(v)))
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 30),

                // 6. Sales Banner Sections
                _buildSalesBannerSection(),
                const SizedBox(height: 20),
                _buildDetailBannerSection(),

                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    onPressed: _isLoading ? null : _uploadImagesAndSave,
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Product", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildGlassTextField({
    required TextEditingController controller, 
    required String label, 
    bool isNumber = false,
    int maxLines = 1,
    TextInputAction? textInputAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white12)
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        textInputAction: textInputAction,
        maxLines: maxLines,
        validator: (val) => val == null || val.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete Product?"),
      content: const Text("This action cannot be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        TextButton(
          child: const Text("Delete", style: TextStyle(color: Colors.red)),
          onPressed: () async {
            Navigator.pop(ctx);
            await Provider.of<StoreService>(context, listen: false).deleteProduct(widget.product!.id);
            if (mounted) Navigator.pop(context);
          },
        )
      ],
    ));
  }

  // --- SALES BANNER BUILDER ---
  Widget _buildSalesBannerSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Store Card Badge", style: TextStyle(color: AppTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold)),
              Switch(
                value: _bannerConfig.isEnabled,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => _bannerConfig = _bannerConfig.copyWith(isEnabled: val)),
              ),
            ],
          ),
          if (_bannerConfig.isEnabled) ...[
            const SizedBox(height: 15),
            const Text("Live Preview (Card Badge)", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 150, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 5, left: 5,
                      child: SalesBanner(config: _bannerConfig, mode: SalesBannerMode.badge),
                    ),
                    const Center(child: Text("Product Image", style: TextStyle(color: Colors.white24, fontSize: 10))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Banner Style", style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                itemBuilder: (context, index) {
                  final style = index + 1;
                  final isSelected = _bannerConfig.style == style;
                  return GestureDetector(
                    onTap: () => setState(() => _bannerConfig = _bannerConfig.copyWith(style: style)),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? Colors.white38 : Colors.white12),
                      ),
                      alignment: Alignment.center,
                      child: Text("Style $style", style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildBannerTextField(
              label: "Primary Text (Short)", 
              value: _bannerConfig.primaryText,
              onChanged: (val) => setState(() => _bannerConfig = _bannerConfig.copyWith(primaryText: val)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildBannerTextField(
                    label: "Secondary", 
                    value: _bannerConfig.secondaryText,
                    onChanged: (val) => setState(() => _bannerConfig = _bannerConfig.copyWith(secondaryText: val)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildBannerTextField(
                    label: "Discount", 
                    value: _bannerConfig.discountText,
                    onChanged: (val) => setState(() => _bannerConfig = _bannerConfig.copyWith(discountText: val)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildBannerColorPickers(_bannerConfig, (updated) => setState(() => _bannerConfig = updated)),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailBannerSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Product Detail Banner", style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
              Switch(
                value: _detailBannerConfig.isEnabled,
                activeColor: Colors.orange,
                onChanged: (val) => setState(() => _detailBannerConfig = _detailBannerConfig.copyWith(isEnabled: val)),
              ),
            ],
          ),
          if (_detailBannerConfig.isEnabled) ...[
            const SizedBox(height: 15),
            const Text("Live Preview (Adaptive Detail Mode)", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 10),
            SalesBanner(config: _detailBannerConfig, mode: SalesBannerMode.flat),
            const SizedBox(height: 20),
            _buildBannerTextField(
              label: "Primary Text", 
              value: _detailBannerConfig.primaryText,
              onChanged: (val) => setState(() => _detailBannerConfig = _detailBannerConfig.copyWith(primaryText: val)),
            ),
            const SizedBox(height: 10),
            _buildBannerTextField(
              label: "Secondary Text (Auto-Shrinks to Fit)", 
              value: _detailBannerConfig.secondaryText,
              onChanged: (val) => setState(() => _detailBannerConfig = _detailBannerConfig.copyWith(secondaryText: val)),
            ),
            const SizedBox(height: 20),
            _buildBannerColorPickers(_detailBannerConfig, (updated) => setState(() => _detailBannerConfig = updated)),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerColorPickers(SalesBannerConfig config, Function(SalesBannerConfig) onUpdate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildColorTile("Primary", config.primaryColor, (c) => onUpdate(config.copyWith(primaryColor: c))),
        _buildColorTile("Secondary", config.secondaryColor, (c) => onUpdate(config.copyWith(secondaryColor: c))),
        _buildColorTile("Accent/Text", config.accentColor, (c) => onUpdate(config.copyWith(accentColor: c))),
      ],
    );
  }

  Widget _buildBannerTextField({required String label, required String value, required Function(String) onChanged}) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildColorTile(String label, String hex, Function(String) onSet) {
    final color = _parseColor(hex);
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _pickColor(color, onSet),
          child: Container(
            width: 35, height: 35,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  void _pickColor(Color initialColor, Function(String) onSet) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Pick a Color", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: (color) {
              final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
              onSet(hex);
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = "FF$hex";
      return Color(int.parse(hex, radix: 16));
    } catch (e) {
      return Colors.red;
    }
  }

}

enum UploadStatus { uploading, success, error }

class UploadItem {
  final String id;
  final File? localFile; // Null if existing image
  String? serverUrl;     // Null until uploaded
  UploadStatus status;
  double progress;       // 0.0 to 1.0

  UploadItem({
    required this.id,
    this.localFile,
    this.serverUrl,
    this.status = UploadStatus.uploading,
    this.progress = 0.0,
  });
}
