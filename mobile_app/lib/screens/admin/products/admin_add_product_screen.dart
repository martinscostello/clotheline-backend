import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../services/store_service.dart';
import '../../../services/api_service.dart'; // For Base URL
import '../../../models/store_product.dart';
import '../../../utils/currency_formatter.dart'; // Added import

class AdminAddProductScreen extends StatefulWidget {
  final StoreProduct? product; // If provided, we are editing
  const AdminAddProductScreen({super.key, this.product});

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
  late TextEditingController _basePriceController; // Was _priceController
  late TextEditingController _discountController; // Was _originalPriceController
  late TextEditingController _stockController;
  String _selectedCategory = "Cleaning";
  bool _isFreeShipping = false;

  // Images
  List<File> _newImages = [];
  List<String> _existingImages = []; // URLs

  // Variants
  List<ProductVariant> _variants = [];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? "");
    _descController = TextEditingController(text: p?.description ?? "");
    // If editing, base price is originalPrice (if set and > price) or price (if discount is 0)
    // Actually, backend model has originalPrice. If discount > 0, originalPrice should be the base.
    double basePrice = (p?.originalPrice != null && p!.originalPrice > 0) ? p.originalPrice : (p?.price ?? 0);
    _basePriceController = TextEditingController(text: p != null ? basePrice.toString() : "");
    
    _discountController = TextEditingController(text: p?.discountPercentage.toString() ?? "0");
    _stockController = TextEditingController(text: p?.stockLevel.toString() ?? "10");
    _selectedCategory = p?.category ?? "Cleaning";
    _isFreeShipping = p?.isFreeShipping ?? false;
    _existingImages = p?.imageUrls ?? [];
    _variants = p?.variants ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _basePriceController.dispose();
    _discountController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _newImages.addAll(images.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _uploadImagesAndSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      List<String> finalImageUrls = List.from(_existingImages);

      // 1. Upload New Images
      if (_newImages.isNotEmpty) {
        final dio = Dio();
        final uploadUrl = '${ApiService.baseUrl}/upload'; 
        
        for (var file in _newImages) {
          String fileName = file.path.split('/').last;
          FormData formData = FormData.fromMap({
            "image": await MultipartFile.fromFile(file.path, filename: fileName),
          });
          
          final response = await dio.post(uploadUrl, data: formData);
          if (response.statusCode == 200) {
            String relativePath = response.data['filePath'];
            String fullUrl = "https://clotheline-api.onrender.com$relativePath"; 
            finalImageUrls.add(fullUrl);
          }
        }
      }

      // 2. Prepare Data & Calculate Prices
      double basePrice = double.tryParse(_basePriceController.text) ?? 0.0;
      double discountPct = double.tryParse(_discountController.text) ?? 0.0;
      
      // Calculate main product selling price
      double sellingPrice = basePrice * (1 - (discountPct / 100));

      final productData = {
        "name": _nameController.text,
        "description": _descController.text,
        "price": sellingPrice, // Calculated Selling Price
        "originalPrice": basePrice, // Base Price
        "discountPercentage": discountPct,
        "stock": int.tryParse(_stockController.text) ?? 0,
        "category": _selectedCategory,
        "isFreeShipping": _isFreeShipping,
        "imageUrls": finalImageUrls,
        "variations": _variants.map((v) {
          // Re-calculate variant prices based on the global discount
          double vBase = v.originalPrice > 0 ? v.originalPrice : v.price;
          double vSelling = vBase * (1 - (discountPct / 100));
          return {
            "name": v.name, 
            "price": vSelling, 
            "originalPrice": vBase 
          };
        }).toList()
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save product")));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red,
        ));
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
    return Scaffold(
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
                      // Existing Images
                      ..._existingImages.map((url) => Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                            ),
                          ),
                          Positioned(
                            top: 5, right: 15,
                            child: GestureDetector(
                              onTap: () => setState(() => _existingImages.remove(url)),
                              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                            ),
                          )
                        ],
                      )),
                      // New Images
                      ..._newImages.map((file) => Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              image: DecorationImage(image: FileImage(file), fit: BoxFit.cover)
                            ),
                          ),
                           Positioned(
                            top: 5, right: 15,
                            child: GestureDetector(
                              onTap: () => setState(() => _newImages.remove(file)),
                              child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                            ),
                          )
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Info Fields
                _buildGlassTextField(controller: _nameController, label: "Product Name"),
                const SizedBox(height: 15),
                _buildGlassTextField(controller: _descController, label: "Description", maxLines: 3),
                const SizedBox(height: 15),
                
                Row(
                  children: [
                    Expanded(child: _buildGlassTextField(controller: _basePriceController, label: "Base Price", isNumber: true)),
                    const SizedBox(width: 15),
                    Expanded(child: _buildGlassTextField(controller: _discountController, label: "Discount %", isNumber: true)),
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
                         child: DropdownButtonHideUnderline(
                           child: DropdownButton<String>(
                             value: _selectedCategory,
                             dropdownColor: const Color(0xFF2C2C2C),
                             style: const TextStyle(color: Colors.white),
                             isExpanded: true,
                             items: ["Cleaning", "Softeners", "Fragrances", "Tools", "Other"]
                               .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), 
                             onChanged: (val) => setState(() => _selectedCategory = val!),
                           ),
                         ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildGlassTextField(controller: _stockController, label: "Stock", isNumber: true)
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
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller, 
    required String label, 
    bool isNumber = false,
    int maxLines = 1,
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
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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
}
