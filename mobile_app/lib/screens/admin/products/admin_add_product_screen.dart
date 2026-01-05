import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // Added
import 'package:laundry_app/models/app_content_model.dart';
import 'package:laundry_app/models/store_product.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/services/store_service.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/utils/thousands_separator_input_formatter.dart'; // Added
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';

class AdminAddProductScreen extends StatefulWidget {
  final StoreProduct? productToEdit;
  const AdminAddProductScreen({super.key, this.productToEdit});

  @override
  State<AdminAddProductScreen> createState() => _AdminAddProductScreenState();
}

class _AdminAddProductScreenState extends State<AdminAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final StoreService _storeService = StoreService();
  final ContentService _contentService = ContentService();
  
  // Controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();

  String? _selectedCategory;
  List<ProductVariant> _variations = [];
  List<String> _imageUrls = [];
  
  bool _isFreeShipping = false;
  bool _applyDiscount = false;
  bool _isLoading = false;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.productToEdit != null) {
      _initEditMode(widget.productToEdit!);
    }
  }

  void _initEditMode(StoreProduct p) {
    _nameCtrl.text = p.name;
    // Format existing values with commas
    _priceCtrl.text = ThousandsSeparatorInputFormatter.formatString(p.price.toStringAsFixed(0));
    _qtyCtrl.text = ThousandsSeparatorInputFormatter.formatString(p.stockLevel.toString());
    _descCtrl.text = p.description;
    _selectedCategory = p.category;
    _variations = List.from(p.variants);
    _imageUrls = List.from(p.imageUrls);
    _isFreeShipping = p.isFreeShipping;
    if (p.discountPercent > 0) {
      _applyDiscount = true;
      _discountCtrl.text = p.discountPercent.toString();
    }
  }

  Future<void> _fetchCategories() async {
    final content = await _contentService.getAppContent();
    if (content != null && mounted) {
      setState(() {
        _categories = content.productCategories;
        if (_selectedCategory == null && _categories.isNotEmpty) {
           _selectedCategory = _categories.first;
        }
      });
    }
  }

  Future<void> _pickImage() async {
    if (_imageUrls.length >= 5) return;
    
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
       // Crop Image - Aspect Ratio closely matching Product Card (roughly 1:1 or 4:5)
       CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Product Image',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.original,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Product Image',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.original,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
         setState(() => _isLoading = true);
         // Upload
         String? url = await _contentService.uploadImage(croppedFile.path);
         setState(() => _isLoading = false);
         if (url != null) {
           setState(() {
             _imageUrls.add(url);
           });
         }
      }
    }
  }

  void _addVariation() {
    TextEditingController vName = TextEditingController();
    TextEditingController vPrice = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Add Variation"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: vName, decoration: const InputDecoration(labelText: "Variation (e.g. Red, XL)")),
          TextField(
            controller: vPrice, 
            keyboardType: TextInputType.number, 
            decoration: const InputDecoration(labelText: "Price (₦)"),
            inputFormatters: [ThousandsSeparatorInputFormatter()],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(onPressed: (){
            if (vName.text.isNotEmpty && vPrice.text.isNotEmpty) {
              double origPrice = double.tryParse(vPrice.text.replaceAll(',', '')) ?? 0;
              setState(() {
                _variations.add(ProductVariant(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: vName.text,
                  originalPrice: origPrice,
                  price: origPrice // Discount applied on Save
                ));
              });
              Navigator.pop(ctx);
            }
        }, child: const Text("Add"))
      ],
    ));
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a category")));
      return;
    }

    setState(() => _isLoading = true);

    // Clean inputs (remove commas)
    double price = double.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0;
    double discount = _applyDiscount ? (double.tryParse(_discountCtrl.text) ?? 0) : 0;
    int stock = int.tryParse(_qtyCtrl.text.replaceAll(',', '')) ?? 0;

    double finalPrice = price;
    double originalPrice = price;
    
    // Apply discount to Main Price
    if (discount > 0) {
      finalPrice = price * (1 - (discount / 100));
    }
    
    // Apply discount to Variations
    List<ProductVariant> processedVariations = _variations.map((v) {
      double vFinalPrice = v.originalPrice;
      if (discount > 0) {
        vFinalPrice = v.originalPrice * (1 - (discount / 100));
      }
      return ProductVariant(
        id: v.id,
        name: v.name,
        originalPrice: v.originalPrice,
        price: vFinalPrice
      );
    }).toList();

    final data = {
      "name": _nameCtrl.text,
      "price": finalPrice,
      "originalPrice": originalPrice, // Original Base Price
      "stock": stock,
      "category": _selectedCategory,
      "description": _descCtrl.text,
      "imageUrls": _imageUrls,
      "variations": processedVariations.map((v) => v.toJson()).toList(),
      "isFreeShipping": _isFreeShipping,
      "discountPercentage": discount
    };

    bool success;
    if (widget.productToEdit != null) {
      success = await _storeService.updateProduct(widget.productToEdit!.id, data);
    } else {
      success = await _storeService.addProduct(data);
    }

    setState(() => _isLoading = false);
    
    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save")));
    }
  }

  Future<void> _deleteProduct() async {
    if (widget.productToEdit == null) return;
    final success = await _storeService.deleteProduct(widget.productToEdit!.id);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.productToEdit == null ? "Add Product" : "Edit Product", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.productToEdit != null)
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteProduct)
        ],
      ),
      body: LiquidBackground(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 50),
                children: [
                  GlassContainer(
                    opacity: 0.1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextField("Product Name", _nameCtrl),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: _buildTextField("Price (₦)", _priceCtrl, isNumber: true, isCurrency: true)),
                              const SizedBox(width: 15),
                              Expanded(child: _buildTextField("Qty", _qtyCtrl, isNumber: true, isCurrency: true)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          const Text("Category", style: TextStyle(color: Colors.white70)),
                          DropdownButton<String>(
                            value: _selectedCategory,
                            dropdownColor: Colors.grey[900],
                            style: const TextStyle(color: Colors.white),
                            isExpanded: true,
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val),
                          ),
                          const SizedBox(height: 20),
                           _buildTextField("Description", _descCtrl, maxLines: 3),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // Variations (More Compact)
                  GlassContainer(
                    opacity: 0.1,
                    child: Padding(
                      padding: const EdgeInsets.all(15), // Reduced padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               const Text("Variations", style: TextStyle(color: Colors.white, fontSize: 16)),
                               SizedBox(
                                 height: 30,
                                 child: TextButton.icon(
                                   onPressed: _addVariation, 
                                   icon: const Icon(Icons.add, size: 16, color: AppTheme.secondaryColor), 
                                   label: const Text("Add", style: TextStyle(color: AppTheme.secondaryColor, fontSize: 13)),
                                   style: TextButton.styleFrom(padding: EdgeInsets.zero)
                                 ),
                               )
                             ],
                           ),
                           if (_variations.isEmpty)
                             const Padding(padding: EdgeInsets.all(8), child: Text("No variations added", style: TextStyle(color: Colors.white38, fontSize: 12))),

                           ..._variations.map((v) => Container(
                             margin: const EdgeInsets.only(bottom: 8),
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                             decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Text(v.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 Row(
                                   children: [
                                     Text("₦${ThousandsSeparatorInputFormatter.formatString(v.originalPrice.toStringAsFixed(0))}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                     if (v.price < v.originalPrice) ...[
                                       const SizedBox(width: 5),
                                       Text("₦${ThousandsSeparatorInputFormatter.formatString(v.price.toStringAsFixed(0))}", style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                                     ],
                                     const SizedBox(width: 10),
                                     GestureDetector(
                                       onTap: () => setState(() => _variations.remove(v)),
                                       child: const Icon(Icons.close, color: Colors.red, size: 18), 
                                     )
                                   ],
                                 )
                               ],
                             ),
                           ))
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Images
                  GlassContainer(
                    opacity: 0.1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Images (Max 5)", style: TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                               ..._imageUrls.map((url) => Stack(
                                  children: [
                                    Container(
                                      width: 80, height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                                      ),
                                    ),
                                    Positioned(right:0, top:0, child: GestureDetector(
                                      onTap: () => setState(() => _imageUrls.remove(url)),
                                      child: Container(
                                        decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.white, size: 16)
                                      ),
                                    ))
                                  ],
                               )),
                               if (_imageUrls.length < 5)
                                 GestureDetector(
                                   onTap: _pickImage,
                                   child: Container(
                                     width: 80, height: 80,
                                     decoration: BoxDecoration(
                                       color: Colors.white10,
                                       borderRadius: BorderRadius.circular(8),
                                       border: Border.all(color: Colors.white30)
                                     ),
                                     child: const Icon(Icons.add_a_photo, color: Colors.white54),
                                   ),
                                 )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // Options
                   GlassContainer(
                    opacity: 0.1,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                           SwitchListTile(
                             title: const Text("Free Shipping", style: TextStyle(color: Colors.white)),
                             value: _isFreeShipping, 
                             onChanged: (v) => setState(() => _isFreeShipping = v),
                             activeColor: AppTheme.secondaryColor,
                           ),
                           Divider(color: Colors.white24),
                           SwitchListTile(
                             title: const Text("Apply Discount", style: TextStyle(color: Colors.white)),
                             value: _applyDiscount, 
                             onChanged: (v) => setState(() => _applyDiscount = v),
                             activeColor: AppTheme.secondaryColor,
                           ),
                           if (_applyDiscount)
                             Padding(
                               padding: const EdgeInsets.only(top: 10),
                               child: _buildTextField("Discount (%)", _discountCtrl, isNumber: true),
                             )
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _saveProduct,
                    child: const Text("Save Product", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumber = false, bool isCurrency = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isCurrency ? [ThousandsSeparatorInputFormatter()] : [],
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      validator: (val) => val!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
      ),
    );
  }
}
