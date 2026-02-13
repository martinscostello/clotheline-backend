import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

import '../../models/booking_models.dart';


import '../../services/cart_service.dart';
import '../../models/service_model.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/toast_utils.dart';
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
  ServiceItem? _selectedCloth;
  ServiceOption? _selectedService; // [CHANGED] From ServiceVariant
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Default selections
    if (widget.serviceModel.items.isNotEmpty) {
      _selectedCloth = widget.serviceModel.items.first;
      if (_selectedCloth!.services.isNotEmpty) {
        _selectedService = _selectedCloth!.services.first;
      }
    }
    
    // Refresh tax settings from backend (includes 50% safety cap)
    _cartService.fetchTaxSettings();
  }

  void _addToBucket() {
    if (_selectedCloth != null && _selectedService != null) {
      final serviceTypeObj = ServiceType(
        id: _selectedService!.name, 
        name: _selectedService!.name,
        priceMultiplier: 1.0 // Fixed pricing, so multiplier is effectively 1.0 relative to its own price
      );
      
      final clothItem = ClothingItem(
        id: _selectedCloth!.name, 
        name: _selectedCloth!.name, 
        basePrice: _selectedService!.price // [CHANGED] Use the service specific price
      );

      _cartService.addItem(CartItem(
        item: clothItem,
        serviceType: serviceTypeObj,
        quantity: _quantity,
        discountPercentage: widget.serviceModel.discountPercentage, 
      ));
      
      setState(() {
        _quantity = 1;
      });
      ToastUtils.show(context, "Added to bucket", type: ToastType.success);
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

  void _showClothSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                  child: Text("Select Cloth Type", style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black
                  )),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: widget.serviceModel.items.length,
                    separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final item = widget.serviceModel.items[index];
                      final isSelected = item.name == _selectedCloth?.name;
                      
                      return ListTile(
                        onTap: () {
                          setState(() {
                            _selectedCloth = item;
                            // Auto-select first service for new cloth
                            if (item.services.isNotEmpty) {
                              _selectedService = item.services.first;
                            } else {
                              _selectedService = null;
                            }
                          });
                          Navigator.pop(context);
                        },
                        title: Text(item.name, style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
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
                    itemCount: _selectedCloth?.services.length ?? 0,
                    separatorBuilder: (_, __) => Divider(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final service = _selectedCloth!.services[index];
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
        final cartItems = _cartService.items;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
               if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))
            ]
          ),
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 40),
          constraints: const BoxConstraints(maxHeight: 750), 
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
              const SizedBox(height: 20),
              
              Text("Book ${widget.serviceModel.name}", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),

              // 1. Select Cloth Type
              if (widget.serviceModel.items.isNotEmpty && _selectedCloth != null) ...[
                Text("Select Cloth Type", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _showClothSelector,
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
                        Text(
                          _selectedCloth?.name ?? "Select Type",
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                        ),
                        if (_selectedCloth != null)
                          Text(
                            "Select",
                            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_selectedCloth != null && _selectedCloth!.services.isEmpty)
                   const Padding(
                     padding: EdgeInsets.only(top: 8, left: 4),
                     child: Text("No services available for this cloth", style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                   ),
                const SizedBox(height: 20),
              ] else ...[
                 Center(child: Text("No items available for this service", style: TextStyle(color: secondaryTextColor))),
                 const SizedBox(height: 20),
              ],

              // 2. Service Type
              if (_selectedCloth != null && _selectedCloth!.services.isNotEmpty) ...[
                Text("Service Type", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
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
                        Text(
                          _selectedService?.name ?? "Select Service",
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                        ),
                        Text(
                           _selectedService != null 
                             ? CurrencyFormatter.format(_selectedService!.price)
                             : "Select",
                           style: const TextStyle(fontWeight: FontWeight.bold),
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
                  icon: const Icon(Icons.shopping_basket_outlined),
                  label: const Text("ADD TO BUCKET"), 
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
                      _buildBreakdownRow("Total Items", _cartService.serviceGrossTotalAmount, textColor, isDark),
                      if (_cartService.laundryTotalDiscount > 0)
                        _buildBreakdownRow("Discount", -_cartService.laundryTotalDiscount, Colors.greenAccent, isDark),
                      _buildBreakdownRow("VAT (${_cartService.taxRate}%)", _cartService.serviceTaxAmount, textColor, isDark),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Grand Total (est.)", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            CurrencyFormatter.format(_cartService.serviceTotalAmount + _cartService.serviceTaxAmount),
                            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18)
                          ),
                        ],
                      ),
                    ],
                  ),
                 const SizedBox(height: 15),
                 
                 // Proceed Button
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                        elevation: 10,
                      ),
                     onPressed: _proceedToCheckout,
                     child: const Text("PROCEED TO CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold)),
                   ),
                 ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(String label, double amount, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)
          ),
        ],
      ),
    );
  }
}


