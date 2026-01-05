import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../glass/GlassContainer.dart';
import '../../models/booking_models.dart';
// Import the package for the dropdown
import 'package:liquid_glass_ui/liquid_glass_ui.dart';
import '../../screens/user/booking/my_bucket_screen.dart';
import '../../services/cart_service.dart'; // [NEW] Import Service

class ClothType {
  final String id;
  final String name;
  final double price;

  ClothType({required this.id, required this.name, required this.price});
}

class BookingSheet extends StatefulWidget {
  final String categoryName;

  const BookingSheet({super.key, required this.categoryName});

  @override
  State<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<BookingSheet> {
  // Mock Data
  late List<ClothType> _clothItems; 
  
  final List<ServiceType> _serviceTypes = [
    ServiceType(id: '1', name: 'Wash & Fold', priceMultiplier: 1.0),
    ServiceType(id: '2', name: 'Iron Only', priceMultiplier: 0.8),
    ServiceType(id: '3', name: 'Dry Clean', priceMultiplier: 1.5),
  ];

  // Using Service instead of local state for items
  final _cartService = CartService(); 

  // Selections
  ClothType? _selectedCloth;
  ServiceType? _selectedService;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _initMockData();
    _selectedService = _serviceTypes[0];
  }
  
  void _initMockData() {
    if (widget.categoryName.toLowerCase().contains("footwear")) {
       _clothItems = [
        ClothType(id: 'f1', name: 'Sneakers', price: 3000),
        ClothType(id: 'f2', name: 'Boots', price: 4000),
        ClothType(id: 'f3', name: 'Shoes', price: 2500),
      ];
    } else {
      // Default / Laundry
      _clothItems = [
        ClothType(id: '1', name: 'Duvet', price: 2000),
        ClothType(id: '2', name: 'Blanket / Small Duvet', price: 1500),
        ClothType(id: '3', name: 'Towel', price: 500),
        ClothType(id: '4', name: 'Shirt', price: 800),
        ClothType(id: '5', name: 'Trousers', price: 800),
      ];
    }
    _selectedCloth = _clothItems[0];
  }

  void _addToBucket() {
    if (_selectedCloth != null && _selectedService != null) {
      // Add to global service
      _cartService.addItem(CartItem(
        item: ClothingItem(id: _selectedCloth!.id, name: _selectedCloth!.name, basePrice: _selectedCloth!.price),
        serviceType: _selectedService!,
        quantity: _quantity,
      ));
      
      setState(() {
        _quantity = 1;
      });
      // Optionally show toast?
    }
  }

  void _proceedToCheckout() {
    Navigator.pop(context); // Close sheet
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => MyBucketScreen(cart: _cartService.items)));
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
          constraints: const BoxConstraints(maxHeight: 750), // Increased height for larger dropdown
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
              
              Text("Book ${widget.categoryName}", style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),

              // 1. Select Cloth Type (LiquidGlassDropdown)
              Text("Select Cloth Type", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              // [FIX] Wider Dropdown Area (350 width target)
              // Using SizedBox to force width, assuming LiquidGlassDropdown expands
                Container( // Wrapper for layout, or just use Padding
                  padding: const EdgeInsets.symmetric(horizontal: 0), // V2 has internal padding? 
                  // V2 has internal padding 16 horiz.
                  // Let's just use the widget directly, maybe wrapped in a width constrainer if needed.
                  width: double.infinity,
                  child: LiquidGlassDropdown<ClothType>(
                    value: _selectedCloth!,
                    isDark: isDark,
                    items: _clothItems.map((c) => DropdownMenuItem(
                      value: c,
                      child: SizedBox( // Ensure width for row
                        width: 250, 
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                            Text("₦${c.price.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )).toList(),
                    onChanged: (val) {
                       if(val != null) setState(() => _selectedCloth = val);
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // 2. Service Type (LiquidGlassDropdown)
              Text("Service Type", style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
               SizedBox(
                 width: double.infinity,
                 child: LiquidGlassDropdown<ServiceType>(
                  value: _selectedService!,
                  isDark: isDark,
                  items: _serviceTypes.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name),
                  )).toList(),
                  onChanged: (val) {
                     if(val != null) setState(() => _selectedService = val);
                  },
                 ),
               ),

              const SizedBox(height: 20),

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
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text("In Bucket (${cartItems.length})", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                     Text("Total: ₦${_cartService.totalAmount.toStringAsFixed(0)}", style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                   ],
                 ),
                 const SizedBox(height: 15),
                 
                 // Proceed Button
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     child: const Text("PROCEED TO CHECKOUT", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                        elevation: 10,
                      ),
                     onPressed: _proceedToCheckout,
                   ),
                 ),
              ],
            ],
          ),
        );
      }
    );
  }
}
