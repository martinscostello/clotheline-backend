import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_pos_provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/custom_cached_image.dart'; // [NEW]
import 'package:clotheline_core/clotheline_core.dart'; // [NEW]

class AdminPOSScreen extends StatefulWidget {
  final String? fulfillmentMode; // [NEW] logistics | deployment | bulky
  const AdminPOSScreen({super.key, this.fulfillmentMode});

  @override
  State<AdminPOSScreen> createState() => _AdminPOSScreenState();
}

class _AdminPOSScreenState extends State<AdminPOSScreen> {
  int _currentStep = 0;
  String _orderType = 'Laundry'; // Laundry, Store, or Deployment
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController(); // [NEW]
  final _notesController = TextEditingController(); // [NEW]
  String _searchQuery = ""; // [NEW]

  String? _branchError;
  String? _nameError;
  String? _phoneError;
  String? _checkoutError;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = Provider.of<AdminPOSProvider>(context, listen: false);
      if (pos.selectedBranch != null) {
        Provider.of<LaundryService>(context, listen: false).fetchServices(branchId: pos.selectedBranch!.id);
        Provider.of<StoreService>(context, listen: false).fetchProducts(branchId: pos.selectedBranch!.id, isAdmin: true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _searchController.dispose();
    _notesController.dispose(); // [NEW]
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(_currentStep == 0 ? "Walk-in POS" : "New Order: ${_nameController.text}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.pop(context); // State preserved, do not reset here
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: "Clear Order",
              onPressed: () {
                 Provider.of<AdminPOSProvider>(context, listen: false).reset();
                 setState(() => _currentStep = 0);
                 _nameController.clear();
                 _phoneController.clear();
                 _emailController.clear();
                 _addressController.clear();
                 _searchController.clear();
                 _searchQuery = "";
              },
            ),
            if (_currentStep >= 2) ...[
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Consumer<AdminPOSProvider>(
                  builder: (context, pos, _) {
                    int total = pos.laundryItems.length + pos.storeItems.length;
                    return Badge(
                      label: Text("$total", style: const TextStyle(fontSize: 10)),
                      isLabelVisible: total > 0,
                      child: IconButton(
                        icon: const Icon(Icons.shopping_basket_outlined, color: AppTheme.secondaryColor),
                        onPressed: () => _showCartBottomSheet(pos),
                      ),
                    );
                  }
                ),
              ),
            ],
          ],
        ),
        body: LiquidBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: _buildCurrentStep(),
                ),
                _buildBottomNavigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(5, (index) {
          bool active = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: active ? AppTheme.secondaryColor : Colors.white10,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildGuestInfoStep();
      case 1: return _buildOrderTypeStep();
      case 2: return _buildItemSelectionStep();
      case 3: return _buildLogisticsStep();
      case 4: return _buildPaymentStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildGuestInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Step 1: Client & Branch", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Identify the client and select their location.", style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 25),
          
          Row(
            children: [
              const Text("Select Branch", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              if (_branchError != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                const SizedBox(width: 4),
                Text(_branchError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
              ]
            ],
          ),
          const SizedBox(height: 12),
          Consumer<BranchProvider>(
            builder: (context, branchProvider, _) {
              if (branchProvider.isLoading) return const Center(child: CircularProgressIndicator());
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: branchProvider.branches.map((b) {
                  final pos = Provider.of<AdminPOSProvider>(context);
                  bool selected = pos.selectedBranch?.id == b.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _branchError = null);
                      pos.setBranch(b);
                      _fetchData();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.secondaryColor : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: selected ? AppTheme.secondaryColor : Colors.white10),
                      ),
                      child: Text(
                        b.name,
                        style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 35),
          _buildTextField("Client Name", _nameController, Icons.person_outline, errorText: _nameError),
          const SizedBox(height: 15),
          _buildTextField("Phone Number", _phoneController, Icons.phone_android_outlined, keyboardType: TextInputType.phone, errorText: _phoneError),
          const SizedBox(height: 15),
          _buildTextField("Email (For digital receipt)", _emailController, Icons.mail_outline, keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, String? errorText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassContainer(
          opacity: 0.1,
          border: errorText != null ? Border.all(color: Colors.redAccent) : Border.all(color: Colors.white10),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) {
               if (errorText != null) {
                  setState(() {
                    if (controller == _nameController) _nameError = null;
                    if (controller == _phoneController) _phoneError = null;
                  });
               }
            },
            decoration: InputDecoration(
              icon: Icon(icon, color: errorText != null ? Colors.redAccent : AppTheme.secondaryColor, size: 20),
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white54),
              border: InputBorder.none,
            ),
          ),
        ),
        if (errorText != null)
           Padding(
             padding: const EdgeInsets.only(top: 5, left: 10),
             child: Text(errorText, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
           ),
      ],
    );
  }

  Widget _buildOrderTypeStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Step 2: Order Category", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Is this for Laundry or Store Shopping?", style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 30),
          
          _buildTypeCard("Laundry Services", Icons.local_laundry_service_outlined, "Wash, fold, iron, and dry cleaning.", 'Laundry'),
          const SizedBox(height: 20),
          _buildTypeCard("Store Products", Icons.shopping_bag_outlined, "Detergents, additives, and retail items.", 'Store'),
          const SizedBox(height: 20),
          _buildTypeCard("Home Cleaning", Icons.cleaning_services_outlined, "On-site deep cleaning and inspections.", 'deployment'),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String title, IconData icon, String subtitle, String type) {
    final pos = Provider.of<AdminPOSProvider>(context, listen: false);
    bool selected = _orderType == type;
    return GestureDetector(
      onTap: () {
        if (_orderType != type) {
          setState(() => _orderType = type);
          // [FIX] Clear cart when switching categories to prevent leakage
          pos.clearAllItems();
        }
      },
      child: GlassContainer(
        opacity: selected ? 0.2 : 0.05,
        border: Border.all(color: selected ? AppTheme.secondaryColor : Colors.white10),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: selected ? AppTheme.secondaryColor : Colors.white10, shape: BoxShape.circle),
              child: Icon(icon, color: selected ? Colors.black : Colors.white, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle, color: AppTheme.secondaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildItemSelectionStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${_orderType} Selection", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (_orderType != 'deployment') // Hide switch for deployment to keep it isolated
                TextButton.icon(
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  onPressed: () => setState(() => _orderType = _orderType == 'Laundry' ? 'Store' : 'Laundry'),
                  label: Text("Switch to ${_orderType == 'Laundry' ? 'Store' : 'Laundry'}", style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
        Expanded(
          child: _orderType == 'Store' ? _buildStoreSelection() : _buildLaundrySelection(),
        ),
      ],
    );
  }

  Widget _buildLaundrySelection() {
    return Consumer<LaundryService>(
      builder: (context, laundrySvc, _) {
        if (laundrySvc.services.isEmpty) return const Center(child: CircularProgressIndicator());
        
        List<ServiceModel> filteredServices = laundrySvc.services;
        
        // POS Internal Isolation
        if (_orderType == 'deployment') {
           filteredServices = filteredServices.where((s) => s.fulfillmentMode == 'deployment').toList();
        } else if (_orderType == 'Laundry') {
           filteredServices = filteredServices.where((s) => s.fulfillmentMode == 'logistics' || s.fulfillmentMode == 'bulky').toList();
        }

        if (widget.fulfillmentMode != null) {
          if (widget.fulfillmentMode == 'logistics') {
            filteredServices = filteredServices.where((s) => s.fulfillmentMode == 'logistics' || s.fulfillmentMode == 'bulky').toList();
          } else {
            filteredServices = filteredServices.where((s) => s.fulfillmentMode == widget.fulfillmentMode).toList();
          }
        }

        if (filteredServices.isEmpty) {
          return const Center(child: Text("No services found for this mode", style: TextStyle(color: Colors.white38)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredServices.length,
          itemBuilder: (context, index) {
            final service = filteredServices[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: GlassContainer(
                opacity: 0.1,
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  collapsedIconColor: Colors.white54,
                  iconColor: AppTheme.secondaryColor,
                  title: Text(service.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  children: service.items.map((item) {
                    return ListTile(
                      dense: true,
                      leading: CustomCachedImage(imageUrl: service.image, width: 24, height: 24, borderRadius: 4),
                      title: Text(item.name, style: const TextStyle(color: Colors.white70)),
                      subtitle: Text("Base: ${CurrencyFormatter.format(item.price)}", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor, size: 20),
                        onPressed: () => _showLaundryTypePicker(context, service, item),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStoreSelection() {
    return Consumer<StoreService>(
      builder: (context, storeSvc, _) {
        if (storeSvc.products.isEmpty) return const Center(child: CircularProgressIndicator());
        
        // Filter products based on search query
        final filteredProducts = storeSvc.products.where((p) => 
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.brand.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search products...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            
            Expanded(
              child: filteredProducts.isEmpty 
                ? const Center(child: Text("No products found", style: TextStyle(color: Colors.white24)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final hasDiscount = product.originalPrice > product.price;

                      return GlassContainer(
                        opacity: 0.1,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05), 
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                child: CustomCachedImage(
                                  imageUrl: product.imagePath,
                                  fit: BoxFit.cover,
                                  borderRadius: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(product.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  CurrencyFormatter.format(product.price), 
                                  style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)
                                ),
                                if (hasDiscount) ...[
                                  const SizedBox(width: 5),
                                  Text(
                                    CurrencyFormatter.format(product.originalPrice),
                                    style: const TextStyle(
                                      color: Colors.white24, 
                                      fontSize: 10, 
                                      decoration: TextDecoration.lineThrough
                                    ),
                                  ),
                                ]
                              ],
                            ),
                            if (hasDiscount) 
                               Text(
                                 "${product.discountPercent}% OFF", 
                                 style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)
                               ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 32,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                onPressed: () => _addStoreProductDialog(product),
                                child: const Text("Add to Bucket", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        );
      },
    );
  }

  void _addLaundryItemDialog(ServiceModel service, ServiceItem item, ServiceOption option) {
    int qty = 1;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Add ${item.name}", style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(option.name, style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54), onPressed: () => setDialogState(() => qty > 1 ? qty-- : null)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text("$qty", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor), onPressed: () => setDialogState(() => qty++)),
                ],
              ),
              const SizedBox(height: 10),
              Text("Total: ${CurrencyFormatter.format(option.price * qty)}", style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
              onPressed: () {
                final pos = Provider.of<AdminPOSProvider>(context, listen: false);
                pos.addLaundryItem(CartItem(
                  item: ClothingItem(id: item.id ?? '', name: item.name, basePrice: option.price),
                  serviceType: ServiceType(id: option.name, name: option.name, priceMultiplier: 1.0),
                  quantity: qty,
                  fulfillmentMode: service.fulfillmentMode,
                  quoteRequired: service.quoteRequired,
                  inspectionFee: service.inspectionFee,
                  serviceId: service.id,
                  serviceName: service.name,
                ));
                Navigator.pop(ctx);
              },
              child: const Text("Add", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLaundryTypePicker(BuildContext context, ServiceModel service, ServiceItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        opacity: 0.9,
        padding: const EdgeInsets.all(20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Select Type for ${item.name}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (item.services.isEmpty)
                   const Padding(
                     padding: EdgeInsets.symmetric(vertical: 20),
                     child: Center(child: Text("No specific services defined for this cloth", style: TextStyle(color: Colors.white38))),
                   ),
                ...item.services.map((option) => ListTile(
                  title: Text(option.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(CurrencyFormatter.format(option.price), style: const TextStyle(color: Colors.white54)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.secondaryColor),
                  onTap: () {
                    Navigator.pop(context);
                    _addLaundryItemDialog(service, item, option);
                  },
                )),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addStoreProductDialog(StoreProduct product) {
    // Similar dialog for store products
    int qty = 1;
     showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Add ${product.name}", style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.variants.isNotEmpty) ...[
                 const Text("Select Variant", style: TextStyle(color: Colors.white54)),
                 // Variant selection logic here...
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white54), onPressed: () => setDialogState(() => qty > 1 ? qty-- : null)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text("$qty", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor), onPressed: () => setDialogState(() => qty++)),
                ],
              ),
              const SizedBox(height: 10),
              Text("Total: ${CurrencyFormatter.format(product.price * qty)}", style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
              onPressed: () {
                final pos = Provider.of<AdminPOSProvider>(context, listen: false);
                pos.addStoreItem(StoreCartItem(
                  product: product,
                  quantity: qty,
                ));
                Navigator.pop(ctx);
              },
              child: const Text("Add", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogisticsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Consumer<AdminPOSProvider>(
        builder: (context, pos, _) {
          final isDeployment = widget.fulfillmentMode == 'deployment' || 
                             _orderType == 'deployment' ||
                             (pos.laundryItems.isNotEmpty && pos.laundryItems.any((i) => i.fulfillmentMode == 'deployment'));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Step 4: ${isDeployment ? 'Service Location' : 'Logistics'}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(isDeployment ? "Where will this service take place?" : "How will the client get their items?", style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 30),
              
              if (isDeployment) ...[
                _buildTextField("Service Address", _addressController, Icons.location_on_outlined),
                const SizedBox(height: 20),
              ] else ...[
                _buildOptionCard("Store Pickup", Icons.store_mall_directory_outlined, "Client will collect from branch.", pos.deliveryOption == 'Pickup', () => setState(() {
                  pos.deliveryOption = 'Pickup';
                  pos.deliveryFee = 0;
                })),
                const SizedBox(height: 20),
                _buildOptionCard("Home Delivery", Icons.delivery_dining_outlined, "We deliver to client's address.", pos.deliveryOption == 'Deliver', () => setState(() => pos.deliveryOption = 'Deliver')),
              ],
              
              if (pos.deliveryOption == 'Deliver' || isDeployment) ...[
                if (!isDeployment) const SizedBox(height: 30),
                if (!isDeployment) _buildTextField("Delivery Address", _addressController, Icons.location_on_outlined),
                const SizedBox(height: 20),
                const Text("Select Service/Delivery Zone", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ...pos.selectedBranch!.deliveryZones.map((zone) {
                      bool selected = pos.deliveryFee == zone.baseFee;
                      return GestureDetector(
                        onTap: () => setState(() => pos.deliveryFee = zone.baseFee),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.secondaryColor : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? AppTheme.secondaryColor : Colors.white10),
                          ),
                          child: Column(
                            children: [
                              Text(zone.name, style: TextStyle(color: selected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(CurrencyFormatter.format(zone.baseFee), style: TextStyle(color: selected ? Colors.black54 : Colors.white54, fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Custom Delivery Fee Setup
                    Builder(
                      builder: (context) {
                        bool isCustom = pos.deliveryFee > 0 && !pos.selectedBranch!.deliveryZones.any((z) => z.baseFee == pos.deliveryFee);
                        return GestureDetector(
                          onTap: () => _showCustomDeliveryFeeDialog(pos),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                              color: isCustom ? AppTheme.secondaryColor : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isCustom ? AppTheme.secondaryColor : Colors.white10),
                            ),
                            child: Column(
                              children: [
                                Text("Custom", style: TextStyle(color: isCustom ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(isCustom ? CurrencyFormatter.format(pos.deliveryFee) : "Custom Fee", style: TextStyle(color: isCustom ? Colors.black54 : Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 30),
              const Text("Special Care / Notes", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              // [NEW] Dynamic Care Suggestions
              Consumer<AdminPOSProvider>(
                builder: (context, pos, _) {
                  List<String> chips = [];
                  String hint = "Add special instructions...";
                  
                  if (_orderType == 'deployment') {
                    chips = ["Focus on Kitchen", "Deep clean bathroom", "Dusting only", "Vacuum bedroom", "Mop floors", "Clean windows"];
                    hint = "e.g. Deep clean the master bathroom...";
                  } else if (_orderType == 'Laundry') {
                    chips = ["Gentle Wash", "No Bleach", "Cold Wash Only", "Separate Whites", "Hand Wash", "Use Softener"];
                    hint = "e.g. Hand wash the silk gown...";
                  } else if (_orderType == 'Store') {
                    chips = ["Fragile Item", "Handle with Care", "Keep Upright", "Gift Wrap", "Express Delivery"];
                    hint = "e.g. Handle the glass bottles with care...";
                  }

                  if (chips.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chips.map((chip) => ActionChip(
                        label: Text(chip, style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        labelStyle: const TextStyle(color: AppTheme.secondaryColor),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          if (_notesController.text.length + chip.length + 2 > 300) return;
                          setState(() {
                            if (_notesController.text.isEmpty) {
                              _notesController.text = chip;
                            } else if (_notesController.text.endsWith(". ") || _notesController.text.endsWith(" ")) {
                              _notesController.text += chip;
                            } else {
                              _notesController.text += ". $chip";
                            }
                            pos.laundryNotes = _notesController.text;
                          });
                        },
                      )).toList(),
                    ),
                  );
                }
              ),

              GlassContainer(
                opacity: 0.1,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: TextField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => pos.laundryNotes = val,
                  decoration: InputDecoration(
                    icon: const Icon(Icons.note_add_outlined, color: AppTheme.secondaryColor, size: 20),
                    hintText: _orderType == 'deployment' ? "e.g. Deep clean the master bathroom..." : 
                              (_orderType == 'Laundry' ? "e.g. Hand wash the silk gown..." : "Add special instructions..."),
                    hintStyle: const TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  "No Starch", "Heavy Starch", "Hand wash Only", "Fold Only", "Heavy Stains", "Express"
                ].map((note) => ActionChip(
                  label: Text(note, style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  side: const BorderSide(color: Colors.white10),
                  onPressed: () {
                    final currentText = _notesController.text;
                    final newText = currentText.isEmpty ? note : "$currentText, $note";
                    _notesController.text = newText;
                    pos.laundryNotes = newText;
                  },
                )).toList(),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildOptionCard(String title, IconData icon, String subtitle, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        opacity: selected ? 0.2 : 0.05,
        border: Border.all(color: selected ? AppTheme.secondaryColor : Colors.white10),
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.secondaryColor : Colors.white54),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.radio_button_checked, color: AppTheme.secondaryColor)
            else const Icon(Icons.radio_button_off, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Consumer<AdminPOSProvider>(
        builder: (context, pos, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Step 5: Payment & Finish", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Select payment method and confirm order.", style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 30),
              
              GlassContainer(
                opacity: 0.1,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildSummaryRow("Subtotal", CurrencyFormatter.format(pos.subtotal)),
                    const SizedBox(height: 10),
                    _buildSummaryRow("Delivery Fee", CurrencyFormatter.format(pos.deliveryFee)),
                    const Divider(color: Colors.white10),
                    _buildSummaryRow("Total Amount", CurrencyFormatter.format(pos.totalAmount), isBold: true),
                  ],
                ),
              ),
              
              const SizedBox(height: 25),
              if (widget.fulfillmentMode == 'deployment' || _orderType == 'deployment') ...[
                 _buildDeploymentSummary(pos),
                 const SizedBox(height: 25),
              ],
              const Text("Payment Method", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildPaymentGrid(pos),
              
              if (_checkoutError != null) ...[
                const SizedBox(height: 20),
                GlassContainer(
                  opacity: 0.2,
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_checkoutError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                    ],
                  ),
                ),
              ],
            ],
          );
        }
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isBold ? Colors.white : Colors.white70, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(color: isBold ? AppTheme.secondaryColor : Colors.white, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14)),
      ],
    );
  }

  Widget _buildDeploymentSummary(AdminPOSProvider pos) {
    final estimateGross = pos.laundryItems.fold(0.0, (sum, i) => sum + i.baseTotal);
    return GlassContainer(
      opacity: 0.15,
      border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.3)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "SERVICE ESTIMATE", 
              style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)
            ),
          ),
          const SizedBox(height: 15),
          ...pos.laundryItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.item.name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(CurrencyFormatter.format(item.baseTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )),
          const Divider(color: Colors.white10, height: 20),
          _buildSummaryRow("Total Estimate", CurrencyFormatter.format(estimateGross), isBold: true),
          const SizedBox(height: 10),
          const Text(
            "* Initial payment covers inspection and logistics only. Final balance depends on onsite assessment.",
            style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentGrid(AdminPOSProvider pos) {
    final methods = [
      {'id': 'cash', 'label': 'Cash', 'icon': Icons.money},
      {'id': 'pos', 'label': 'Card/POS', 'icon': Icons.credit_card},
      {'id': 'transfer', 'label': 'Transfer', 'icon': Icons.account_balance},
      {'id': 'pay_on_delivery', 'label': 'Pay on Delivery', 'icon': Icons.handshake_outlined},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemCount: methods.length,
      itemBuilder: (context, index) {
        final m = methods[index];
        bool selected = pos.paymentMethod == m['id'];
        return GestureDetector(
          onTap: () => setState(() => pos.paymentMethod = m['id'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? AppTheme.secondaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? AppTheme.secondaryColor : Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(m['icon'] as IconData, color: selected ? AppTheme.secondaryColor : Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(m['label'] as String, style: TextStyle(color: selected ? AppTheme.secondaryColor : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text("Back", style: TextStyle(color: Colors.white54)),
            )
          else
            const SizedBox.shrink(),
          
          ElevatedButton(
            onPressed: _onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _currentStep == 4 ? "Finish" : "Next",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _onNext() {
    final pos = Provider.of<AdminPOSProvider>(context, listen: false);
    
    if (_currentStep == 0) {
      bool hasError = false;
      setState(() {
        _branchError = null;
        _nameError = null;
        _phoneError = null;
        
        if (pos.selectedBranch == null) {
          _branchError = "Please select a branch";
          hasError = true;
        }
        if (_nameController.text.isEmpty) {
          _nameError = "Client name is required";
          hasError = true;
        }
        if (_phoneController.text.length != 11) {
          _phoneError = "Phone number must be exactly 11 digits";
          hasError = true;
        }
      });
      
      if (hasError) return;

      pos.setGuestInfo(name: _nameController.text, phone: _phoneController.text, email: _emailController.text);
    }
    
    if (_currentStep < 4) {
      if (_currentStep == 3) {
         pos.deliveryAddress = _addressController.text;
      }
      setState(() => _currentStep++);
    } else {
      _finishOrder();
    }
  }

  void _finishOrder() async {
    final pos = Provider.of<AdminPOSProvider>(context, listen: false);
    
    // Show confirmation loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
    );

    setState(() => _checkoutError = null);
    final result = await pos.createOrder();
    
    Navigator.pop(context); // Close loading

    if (result['success']) {
       if (!mounted) return;
       _showSuccessDialog(result['order']);
    } else {
       setState(() => _checkoutError = result['message']);
    }
  }

  void _showSuccessDialog(dynamic order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 50),
            SizedBox(height: 10),
            Text("Order Created!", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text("The walk-in order has been recorded successfully.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        actions: [
          Column(
            children: [
               _buildActionButton("Print Receipt", Icons.print, () {
                  final pos = Provider.of<AdminPOSProvider>(context, listen: false);
                  ReceiptService.printReceipt(
                    orderNumber: order['_id'] ?? 'N/A',
                    customerName: pos.guestName ?? 'Guest',
                    branchName: pos.selectedBranch?.name ?? 'Clotheline',
                    laundryItems: pos.laundryItems,
                    storeItems: pos.storeItems,
                    subtotal: pos.subtotal,
                    deliveryFee: pos.deliveryFee,
                    total: pos.totalAmount,
                    paymentMethod: pos.paymentMethod,
                  );
               }),
               const SizedBox(height: 10),
                _buildActionButton("Send Receipt (WhatsApp)", Icons.picture_as_pdf, () {
                   final pos = Provider.of<AdminPOSProvider>(context, listen: false);
                   ReceiptService.shareReceipt(
                     orderNumber: order['_id'] ?? 'N/A',
                     customerName: pos.guestName ?? 'Guest',
                     branchName: pos.selectedBranch?.name ?? 'Clotheline',
                     laundryItems: pos.laundryItems,
                     storeItems: pos.storeItems,
                     subtotal: pos.subtotal,
                     deliveryFee: pos.deliveryFee,
                     total: pos.totalAmount,
                     paymentMethod: pos.paymentMethod,
                   );
                }, color: Colors.green),
                const SizedBox(height: 10),
                _buildActionButton("Send Update (WhatsApp)", Icons.chat, () {
                   final pos = Provider.of<AdminPOSProvider>(context, listen: false);
                   WhatsAppService.sendOrderUpdate(
                     phone: pos.guestPhone ?? '',
                     orderNumber: order['_id'] ?? 'N/A',
                     amount: pos.totalAmount,
                     status: order['status'] ?? 'New',
                     guestName: pos.guestName,
                     branchName: pos.selectedBranch?.name,
                   );
                }, color: Colors.green),
               const SizedBox(height: 10),
               TextButton(
                 onPressed: () {
                   final pos = Provider.of<AdminPOSProvider>(context, listen: false);
                   pos.reset();
                   Navigator.pop(context); // Close dialog
                   Navigator.pop(context); // Back to Dashboard
                 },
                 child: const Text("Back to Dashboard", style: TextStyle(color: AppTheme.secondaryColor)),
               ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color?.withOpacity(0.15) ?? Colors.white.withOpacity(0.05),
          foregroundColor: color ?? Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(color: color?.withOpacity(0.5) ?? Colors.white10),
        ),
        onPressed: onTap,
        icon: Icon(icon, color: color ?? AppTheme.secondaryColor),
        label: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showCartBottomSheet(AdminPOSProvider pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          opacity: 0.9,
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     const Text("Current Bucket", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                     IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView(
                    children: [
                      if (pos.laundryItems.isNotEmpty)
                         const Padding(
                           padding: EdgeInsets.symmetric(vertical: 8.0),
                           child: Text("Laundry", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                         ),
                      ...pos.laundryItems.map((item) {
                         return ListTile(
                           dense: true,
                           contentPadding: EdgeInsets.zero,
                            title: Text("${item.quantity}x ${item.item.name} (${item.serviceType?.name ?? 'Generic'})", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                            subtitle: Text(CurrencyFormatter.format(item.totalPrice), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
                           trailing: IconButton(
                             icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                             onPressed: () {
                               setState(() => pos.removeLaundryItem(item));
                               Navigator.pop(context);
                               if (pos.laundryItems.isNotEmpty || pos.storeItems.isNotEmpty) _showCartBottomSheet(pos);
                             },
                           ),
                         );
                      }),
                      
                      if (pos.storeItems.isNotEmpty)
                         const Padding(
                           padding: EdgeInsets.symmetric(vertical: 8.0),
                           child: Text("Store", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                         ),
                      ...pos.storeItems.map((item) {
                         return ListTile(
                           dense: true,
                           contentPadding: EdgeInsets.zero,
                           title: Text("${item.quantity}x ${item.product.name}", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                           subtitle: Text(CurrencyFormatter.format(item.totalPrice), style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54)),
                           trailing: IconButton(
                             icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                             onPressed: () {
                               setState(() => pos.removeStoreItem(item));
                               Navigator.pop(context);
                               if (pos.laundryItems.isNotEmpty || pos.storeItems.isNotEmpty) _showCartBottomSheet(pos);
                             },
                           ),
                         );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomDeliveryFeeDialog(AdminPOSProvider pos) {
    final customFeeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Custom Delivery Fee", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: customFeeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter amount",
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.attach_money, color: AppTheme.secondaryColor),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
            onPressed: () {
              final fee = double.tryParse(customFeeController.text);
              if (fee != null) {
                setState(() => pos.deliveryFee = fee);
              }
              Navigator.pop(ctx);
            },
            child: const Text("APPLY", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
