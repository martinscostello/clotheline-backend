import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_pos_provider.dart';
import '../../../providers/branch_provider.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../theme/app_theme.dart';
import '../../../services/laundry_service.dart';
import '../../../services/store_service.dart';
import '../../../models/service_model.dart';
import '../../../models/store_product.dart';
import '../../../models/booking_models.dart';
import '../../../services/whatsapp_service.dart';
import '../../../services/receipt_service.dart';
import '../../../widgets/custom_cached_image.dart'; // [NEW]
import '../../../utils/currency_formatter.dart'; // [NEW]

class AdminPOSScreen extends StatefulWidget {
  const AdminPOSScreen({super.key});

  @override
  State<AdminPOSScreen> createState() => _AdminPOSScreenState();
}

class _AdminPOSScreenState extends State<AdminPOSScreen> {
  int _currentStep = 0;
  String _orderType = 'Laundry'; // Laundry or Store
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _searchController = TextEditingController(); // [NEW]
  String _searchQuery = ""; // [NEW]

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
        Provider.of<StoreService>(context, listen: false).fetchProducts(branchId: pos.selectedBranch!.id);
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
              Provider.of<AdminPOSProvider>(context, listen: false).reset();
              Navigator.pop(context);
            },
          ),
          actions: [
            if (_currentStep >= 2)
              Padding(
                padding: const EdgeInsets.only(right: 15.0),
                child: Consumer<AdminPOSProvider>(
                  builder: (context, pos, _) {
                    int total = pos.laundryItems.length + pos.storeItems.length;
                    return Badge(
                      label: Text("$total", style: const TextStyle(fontSize: 10)),
                      isLabelVisible: total > 0,
                      child: const Icon(Icons.shopping_basket_outlined, color: AppTheme.secondaryColor),
                    );
                  }
                ),
              ),
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
          
          const Text("Select Branch", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
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
                      pos.setBranch(b);
                      _fetchData();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.secondaryColor : Colors.white.withOpacity(0.05),
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
          _buildTextField("Client Name", _nameController, Icons.person_outline),
          const SizedBox(height: 15),
          _buildTextField("Phone Number", _phoneController, Icons.phone_android_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 15),
          _buildTextField("Email (For digital receipt)", _emailController, Icons.mail_outline, keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType}) {
    return GlassContainer(
      opacity: 0.1,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          icon: Icon(icon, color: AppTheme.secondaryColor, size: 20),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
        ),
      ),
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
        ],
      ),
    );
  }

  Widget _buildTypeCard(String title, IconData icon, String subtitle, String type) {
    bool selected = _orderType == type;
    return GestureDetector(
      onTap: () => setState(() => _orderType = type),
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
              TextButton.icon(
                icon: const Icon(Icons.swap_horiz, size: 16),
                onPressed: () => setState(() => _orderType = _orderType == 'Laundry' ? 'Store' : 'Laundry'),
                label: Text("Switch to ${_orderType == 'Laundry' ? 'Store' : 'Laundry'}", style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _orderType == 'Laundry' ? _buildLaundrySelection() : _buildStoreSelection(),
        ),
      ],
    );
  }

  Widget _buildLaundrySelection() {
    return Consumer<LaundryService>(
      builder: (context, laundrySvc, _) {
        if (laundrySvc.services.isEmpty) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: laundrySvc.services.length,
          itemBuilder: (context, index) {
            final service = laundrySvc.services[index];
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
                  fillColor: Colors.white.withOpacity(0.05),
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
                                  color: Colors.white.withOpacity(0.05), 
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

  void _addLaundryItemDialog(ServiceItem item, ServiceOption option) {
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
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${item.name} to bucket"), duration: const Duration(seconds: 1)));
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
                    _addLaundryItemDialog(item, option);
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added ${product.name} to bucket"), duration: const Duration(seconds: 1)));
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Step 4: Logistics", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("How will the client get their items?", style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 30),
              
              _buildOptionCard("Store Pickup", Icons.store_mall_directory_outlined, "Client will collect from branch.", pos.deliveryOption == 'Pickup', () => setState(() {
                pos.deliveryOption = 'Pickup';
                pos.deliveryFee = 0;
              })),
              const SizedBox(height: 20),
              _buildOptionCard("Home Delivery", Icons.delivery_dining_outlined, "We deliver to client's address.", pos.deliveryOption == 'Deliver', () => setState(() => pos.deliveryOption = 'Deliver')),
              
              if (pos.deliveryOption == 'Deliver') ...[
                const SizedBox(height: 30),
                _buildTextField("Delivery Address", _addressController, Icons.location_on_outlined),
                const SizedBox(height: 20),
                const Text("Select Delivery Zone", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: pos.selectedBranch!.deliveryZones.map((zone) {
                    bool selected = pos.deliveryFee == zone.baseFee;
                    return GestureDetector(
                      onTap: () => setState(() => pos.deliveryFee = zone.baseFee),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.secondaryColor : Colors.white.withOpacity(0.05),
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
                  }).toList(),
                ),
              ],
              
              const SizedBox(height: 30),
              const Text("Special Care / Notes", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GlassContainer(
                opacity: 0.1,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: TextField(
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => pos.laundryNotes = val,
                  decoration: const InputDecoration(
                    icon: Icon(Icons.note_add_outlined, color: AppTheme.secondaryColor, size: 20),
                    hintText: "Add special instructions...",
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                  ),
                ),
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
              
              const SizedBox(height: 30),
              const Text("Payment Method", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildPaymentGrid(pos),
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
      if (pos.selectedBranch == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a branch")));
        return;
      }
      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and Phone are required")));
        return;
      }
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

    final result = await pos.createOrder();
    
    Navigator.pop(context); // Close loading

    if (result['success']) {
       _showSuccessDialog(result['order']);
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
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
}
