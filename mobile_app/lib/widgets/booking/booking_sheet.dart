import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:clotheline_core/clotheline_core.dart';

import 'package:clotheline_core/clotheline_core.dart';


import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../screens/user/main_layout.dart';

class BookingSheet extends StatefulWidget {
  final ServiceModel serviceModel;


  const BookingSheet({super.key, required this.serviceModel});

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  final _cartService = CartService(); 
  
  // Selections
  ServiceItem? _selectedType;
  ServiceOption? _selectedService; // [CHANGED] From ServiceVariant
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Default selections
    if (widget.serviceModel.items.isNotEmpty) {
      _selectedType = widget.serviceModel.items.first;
      if (_selectedType!.services.isNotEmpty) {
        _selectedService = _selectedType!.services.first;
      }
    }
    
    // Refresh tax settings from backend (includes 50% safety cap)
    _cartService.fetchTaxSettings();
  }

  void _addToBucket() {
    if (_selectedType != null) {
      // For non-deployment services, require a service selection
      if (_selectedService == null && widget.serviceModel.fulfillmentMode != 'deployment') {
        ToastUtils.show(context, "Please select a ${widget.serviceModel.subTypeLabel}", type: ToastType.warning);
        return;
      }

      final serviceTypeObj = _selectedService != null ? ServiceType(
        id: _selectedService!.name, 
        name: _selectedService!.name,
        priceMultiplier: 1.0
      ) : null;
      
      final typeItem = ClothingItem(
        id: _selectedType!.name, 
        name: _selectedType!.name, 
        basePrice: _selectedService?.price ?? 0.0
      );

      _cartService.addItem(CartItem(
        item: typeItem,
        serviceType: serviceTypeObj,
        quantity: _quantity,
        discountPercentage: widget.serviceModel.discountPercentage,
        fulfillmentMode: widget.serviceModel.fulfillmentMode,
        quoteRequired: widget.serviceModel.quoteRequired,
        inspectionFee: widget.serviceModel.inspectionFee,
        inspectionFeeZones: widget.serviceModel.inspectionFeeZones,
        deploymentLocation: widget.serviceModel.deploymentLocation,
        serviceId: widget.serviceModel.id,
        serviceName: widget.serviceModel.name,
      ));
      
      setState(() {
        _quantity = 1;
      });
      final toastMsg = widget.serviceModel.fulfillmentMode == 'deployment' ? "Added for Inspection" : "Added to bucket";
      ToastUtils.show(context, toastMsg, type: ToastType.success);
    }
  }

  void _proceedToCheckout() {
    Navigator.pop(context); // Close sheet
    // Navigate to Orders Tab (index 2) which contains the Unified Bucket
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainLayout(initialIndex: 2)),
      (route) => route.isFirst,
    );
  }

  void _showTypeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    String searchQuery = "";
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter items based on search query
            final filteredItems = widget.serviceModel.items.where((item) {
              return item.name.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75, // Better height for search
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const SizedBox(height: 10),
                   Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300, 
                          borderRadius: BorderRadius.circular(2)
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
                      child: Text(widget.serviceModel.typeLabel, style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black
                      )),
                    ),
                    
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F0F1E) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                              ),
                              child: TextField(
                                controller: searchController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                onChanged: (val) {
                                  setModalState(() => searchQuery = val);
                                },
                                decoration: InputDecoration(
                                  hintText: "Search...",
                                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black45),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.only(top: 12),
                                  suffixIcon: searchQuery.isNotEmpty 
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 18),
                                        onPressed: () {
                                          searchController.clear();
                                          setModalState(() => searchQuery = "");
                                        }
                                      )
                                    : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Attention Animation
                          Icon(Icons.flash_on, color: AppTheme.primaryColor)
                            .animate(onPlay: (controller) => controller.repeat(reverse: true))
                            .scaleXY(begin: 1.0, end: 1.2, duration: 600.ms)
                            .tint(color: Colors.amber) // Flashy color
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: filteredItems.isEmpty
                        ? Center(child: Text("No items found", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final isSelected = item.name == _selectedType?.name;
                              
                              return ListTile(
                                onTap: () {
                                  setState(() {
                                    _selectedType = item;
                                    _selectedService = item.services.isNotEmpty ? item.services.first : null;
                                  });
                                  Navigator.pop(context);
                                },
                                title: Text(item.name, style: TextStyle(
                                  color: isSelected ? AppTheme.primaryColor : (isDark ? Colors.white : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                )),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryColor) : null,
                                contentPadding: EdgeInsets.zero,
                              );
                            },
                          ),
                    ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showServiceTypeSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5, // Smaller height for variants usually
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
               const SizedBox(height: 10),
               Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300, 
                      borderRadius: BorderRadius.circular(2)
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text("Select Service Type", style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black
                  )),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _selectedType?.services.length ?? 0,
                    separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final service = _selectedType!.services[index];
                      final isSelected = service.name == _selectedService?.name;
                      
                      String priceText = CurrencyFormatter.format(service.price);

                      return ListTile(
                        onTap: () {
                          setState(() => _selectedService = service);
                          Navigator.pop(context);
                        },
                        title: Text(service.name, style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        )),
                         trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(priceText, style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.bold
                            )),
                            if (isSelected) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                            ]
                          ],
                        ),
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    // Listen to cart changes to rebuild UI (e.g. for the preview list)
    return ListenableBuilder(
      listenable: _cartService,
      builder: (context, child) {
        final cartItems = _cartService.items.where((i) => i.serviceId == widget.serviceModel.id).toList();
        final bool isDeployment = widget.serviceModel.fulfillmentMode == 'deployment';
        
        // Mode-specific totals
        final double modeGross = cartItems.fold(0.0, (sum, i) => sum + i.baseTotal);
        final double modeDiscount = cartItems.fold(0.0, (sum, i) => sum + i.discountValue);
        final double modeNet = modeGross - modeDiscount;
        final double modeTax = modeNet * (_cartService.taxRate / 100);
        final double modeGrandTotal = modeNet + modeTax;
        
        // Payable Now logic
        final double modePayableSubtotal = cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);
        final double modePayableTax = isDeployment ? 0.0 : (modePayableSubtotal - modeDiscount) * (_cartService.taxRate / 100);
        
        // [FIX] Don't subtract discount from Inspection Fees
        final double modePayableTotal = isDeployment 
            ? modePayableSubtotal + modePayableTax 
            : (modePayableSubtotal - modeDiscount) + modePayableTax;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
               if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))
            ]
          ),
          padding: const EdgeInsets.only(left: 24, right: 24, top: 12),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), 
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300, 
                    borderRadius: BorderRadius.circular(2)
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              Text("Book ${widget.serviceModel.name}", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Select Type
                      if (widget.serviceModel.items.isNotEmpty) ...[
                        Text(widget.serviceModel.typeLabel, style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showTypeSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedType?.name ?? widget.serviceModel.typeLabel,
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedType != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      "Select",
                                      style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (_selectedType != null && _selectedType!.services.isEmpty && widget.serviceModel.fulfillmentMode != 'deployment')
                           const Padding(
                             padding: EdgeInsets.only(top: 8, left: 4),
                             child: Text("No services available for this type", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                           ),
                        const SizedBox(height: 20),
                      ] else ...[
                         Center(child: Text("No items available for this service", style: TextStyle(color: secondaryTextColor))),
                         const SizedBox(height: 20),
                      ],

                      // 2. Service Type
                      if (_selectedType != null && _selectedType!.services.isNotEmpty) ...[
                        Text(widget.serviceModel.subTypeLabel, style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showServiceTypeSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedService?.name ?? widget.serviceModel.subTypeLabel,
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(
                                     _selectedService != null 
                                       ? CurrencyFormatter.format(_selectedService!.price)
                                       : "Select",
                                     style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                         const SizedBox(height: 20),
                      ],

                      // 3. Quantity
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Quantity", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(15)
                            ),
                            child: Row(
                              children: [
                                IconButton(icon: Icon(Icons.remove, color: textColor), onPressed: () => setState(() => _quantity = _quantity > 1 ? _quantity - 1 : 1)),
                                Text("$_quantity", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                IconButton(icon: Icon(Icons.add, color: textColor), onPressed: () => setState(() => _quantity++)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Add To Bucket Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(widget.serviceModel.fulfillmentMode == 'deployment' ? Icons.calendar_today_outlined : Icons.shopping_basket_outlined),
                          label: Text(widget.serviceModel.fulfillmentMode == 'deployment' ? "SCHEDULE INSPECTION" : "ADD TO BUCKET"), 
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                            foregroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          onPressed: _addToBucket,
                        ),
                      ),

                      // Bucket Preview (Mini Cart)
                      if (cartItems.isNotEmpty) ...[
                         const SizedBox(height: 30),
                         Divider(color: secondaryTextColor.withValues(alpha: 0.2)),
                         const SizedBox(height: 10),
                         Column(
                           children: [
                             if (isDeployment && modeGrandTotal > 0) ...[
                                _buildBreakdownRow(
                                  "Service Subtotal", 
                                  modeGross, 
                                  textColor.withOpacity(0.6), 
                                  isDark
                                ),
                                // Add discount breakdown for estimate
                                if (modeDiscount > 0)
                                  _buildBreakdownRow("Discount", -modeDiscount, Colors.greenAccent, isDark),
                                  
                                _buildBreakdownRow(
                                  "Est. VAT (${_cartService.taxRate}%)", 
                                  modeTax, 
                                  textColor.withOpacity(0.6), 
                                  isDark
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Est. Grand Total", style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(
                                      CurrencyFormatter.format(modeGrandTotal),
                                      style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 13)
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                                  child: Text("Payable only after on-site inspection", style: TextStyle(color: Colors.orangeAccent.withOpacity(0.7), fontSize: 10, fontStyle: FontStyle.italic)),
                                ),
                                const Divider(thickness: 1),
                                const SizedBox(height: 8),
                             ],

                             if (isDeployment)
                               const Align(
                                 alignment: Alignment.centerLeft,
                                 child: Padding(
                                   padding: EdgeInsets.only(bottom: 8),
                                   child: Text("PAYABLE NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                                 ),
                               ),

                             _buildBreakdownRow(
                               isDeployment ? "Inspection Fee" : "Total Items", 
                               modePayableSubtotal, 
                               textColor, 
                               isDark,
                               isPending: isDeployment,
                             ),
                             
                             if (!isDeployment && modeDiscount > 0)
                               _buildBreakdownRow("Discount", -modeDiscount, Colors.greenAccent, isDark),
                             
                             if (!isDeployment)
                               _buildBreakdownRow("VAT (${_cartService.taxRate}%)", modePayableTax, textColor, isDark),
                             
                             const SizedBox(height: 8),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Text(
                                   isDeployment ? "Total Due Now" : "Grand Total", 
                                   style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)
                                 ),
                                 Text(
                                   (isDeployment && _cartService.deliveryLocation == null)
                                     ? "Pending Address"
                                     : CurrencyFormatter.format(modePayableTotal),
                                   style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)
                                 ),
                               ],
                             ),
                           ],
                         ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), // Raise it from bottom
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.primaryColor,
                         foregroundColor: Colors.white,
                         padding: const EdgeInsets.symmetric(vertical: 18),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                         shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                         elevation: 10,
                       ),
                      onPressed: _proceedToCheckout,
                      child: const Text("PROCEED TO CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ),

          ],
        ),
      );
    },
  );
}

  Widget _buildBreakdownRow(String label, double? amount, Color color, bool isDark, {bool isPending = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
          Text(
            (amount == null || isPending) ? "Pending Address" : CurrencyFormatter.format(amount),
            style: TextStyle(color: (amount == null || isPending) ? Colors.orangeAccent : color, fontSize: 13, fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }
}
