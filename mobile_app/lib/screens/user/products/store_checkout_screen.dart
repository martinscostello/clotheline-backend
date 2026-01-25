import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/cart_service.dart';
import '../../../services/content_service.dart';
// import '../../../models/app_content_model.dart';
import '../../../services/order_service.dart';
import '../../../services/delivery_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../providers/branch_provider.dart';
import '../../../services/payment_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/toast_utils.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';

class StoreCheckoutScreen extends StatefulWidget {
  const StoreCheckoutScreen({super.key});

  @override
  State<StoreCheckoutScreen> createState() => _StoreCheckoutScreenState();
}

class _StoreCheckoutScreenState extends State<StoreCheckoutScreen> with SingleTickerProviderStateMixin {
  final _cartService = CartService();
  int _currentStage = 1;
  
  // Logic Selections
  int _deliveryOption = 0; // 0 = Unselected, 1 = Deliver, 2 = Pickup

  // Controllers
  final _deliveryAddressController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  // Location Data
  LatLng? _deliveryLatLng;
  double _deliveryFee = 0.0;
  bool _isLocating = false;

  // Animation
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  // Branch Info
  String _branchAddress = "Loading...";
  String _branchPhone = "Loading...";
  final _contentService = ContentService();

  @override
  void initState() {
     super.initState();
     _fetchContent();
     WidgetsBinding.instance.addPostFrameCallback((_) {
       Provider.of<DeliveryService>(context, listen: false).fetchSettings();
     });

     _breathingController = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 1500),
     )..repeat(reverse: true);
     
     _breathingAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
       CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut)
     );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  // LOGIC: Get Location (Standardized)
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) ToastUtils.show(context, "Location services are disabled.", type: ToastType.error);
      setState(() => _isLocating = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted) ToastUtils.show(context, "Location permissions are denied", type: ToastType.error);
        setState(() => _isLocating = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if(mounted) ToastUtils.show(context, "Location permissions are permanently denied.", type: ToastType.error);
      setState(() => _isLocating = false);
      return;
    } 

    try {
      Position position = await Geolocator.getCurrentPosition();
      final deliveryService = Provider.of<DeliveryService>(context, listen: false);
      final branchProvider = Provider.of<BranchProvider>(context, listen: false);
      
      double fee = deliveryService.calculateDeliveryFee(
        position.latitude, 
        position.longitude,
        branch: branchProvider.selectedBranch
      );
      
      setState(() {
         // Only Update Delivery GPS & Fee
         _deliveryLatLng = LatLng(position.latitude, position.longitude);
         _deliveryFee = fee;
      });
      
    } catch (e) {
      if(mounted) ToastUtils.show(context, "Error getting location: $e", type: ToastType.error);
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _fetchContent() async {
    final content = await _contentService.getAppContent();
    if(mounted) {
      setState(() {
        _branchAddress = content.contactAddress;
        _branchPhone = content.contactPhone;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return PopScope(
      canPop: _currentStage == 1,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentStage > 1) {
          setState(() => _currentStage--);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        body: LaundryGlassBackground(
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: _cartService,
                builder: (context, _) {
                  if (_cartService.storeItems.isEmpty && _currentStage == 1) {
                     return const Center(child: Text("Cart is empty"));
                  }
                  
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 90, 
                      bottom: 180, // Space for bottom bar
                      left: 20, 
                      right: 20
                    ),
                    child: Column(
                      children: [
                        _buildStepIndicator(isDark),
                        _buildStageContent(isDark, textColor),
                      ],
                    ),
                  );
                }
              ),

              // Bottom Bar overlay
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _buildBottomBar(isDark),
              ),
              
              // Header
              Positioned(
                top: 0, left: 0, right: 0,
                child: UnifiedGlassHeader(
                  isDark: isDark,
                  title: Text(_currentStage == 1 ? "Delivery Options" : "Order Summary", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  onBack: () {
                    if (_currentStage > 1) {
                      setState(() => _currentStage--);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepDot(1, isDark),
          _buildStepLine(1, isDark),
          _buildStepDot(2, isDark),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, bool isDark) {
    final isActive = _currentStage >= step;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryColor : (isDark ? Colors.white10 : Colors.grey.shade300),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text("$step", style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStepLine(int step, bool isDark) {
    final isActive = _currentStage > step;
    return Container(
      width: 50,
      height: 2,
      color: isActive ? AppTheme.primaryColor : (isDark ? Colors.white10 : Colors.grey.shade300),
    );
  }

  Widget _buildStageContent(bool isDark, Color textColor) {
    if (_currentStage == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text("How do you want your products?", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
           const SizedBox(height: 20),
           
           // Option 1: Delivery
           _buildOptionTile(
            value: 1,
            groupValue: _deliveryOption,
            title: "Review Delivery",
            subtitle: "We deliver to your doorstep",
            onChanged: (val) => setState(() => _deliveryOption = val!),
            isDark: isDark,
            colors: textColor,
          ),
          if (_deliveryOption == 1) 
            Padding(
               padding: const EdgeInsets.only(left: 20, right: 10, bottom: 20),
               child: Column(
                 children: [
                   Row(
                     children: [
                       Expanded(child: _buildTextField(_deliveryAddressController, "Delivery Address (Manual or GPS)", Icons.location_on, isDark)),
                       const SizedBox(width: 8),
                       InkWell(
                          onTap: _getCurrentLocation,
                          child: AnimatedBuilder(
                            animation: _breathingAnimation,
                            builder: (context, child) {
                              bool isActive = _deliveryLatLng != null;
                              return Transform.scale(
                                scale: isActive ? _breathingAnimation.value : 1.0,
                                child: Container(
                                  height: 50, width: 50,
                                  decoration: BoxDecoration(
                                    color: isActive ? AppTheme.primaryColor : AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.primaryColor),
                                  ),
                                  child: Icon(Icons.my_location, color: isActive ? Colors.white : AppTheme.primaryColor),
                                ),
                              );
                            },
                          ),
                        )
                     ],
                   ),
                   if (_deliveryLatLng == null)
                     Padding(
                       padding: const EdgeInsets.only(top: 5, left: 5),
                       child: Text("Use GPS for accurate fee calculation", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                     ),
                   const SizedBox(height: 10),
                   _buildTextField(_contactPhoneController, "Contact Phone", Icons.phone, isDark),
                 ],
               ),
            ),

          const SizedBox(height: 10),
          
          // Option 2: Pickup
          _buildOptionTile(
            value: 2,
            groupValue: _deliveryOption,
            title: "I'll Pick up",
            subtitle: "Collect from our branch",
            onChanged: (val) => setState(() => _deliveryOption = val!),
            isDark: isDark,
            colors: textColor,
          ),
          if (_deliveryOption == 2) _buildBranchInfo(isDark),
        ],
      );
    } else {
      // Summary
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text("Order Details", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildSummaryCard(isDark, textColor),
            
            const SizedBox(height: 30),
             Text("Delivery Option", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             ClipRRect(
               borderRadius: BorderRadius.circular(15),
               child: BackdropFilter(
                 filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                 child: Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                     borderRadius: BorderRadius.circular(15),
                     border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                   ),
                   child: Row(
                     children: [
                       Icon(_deliveryOption == 1 ? Icons.local_shipping : Icons.store, color: AppTheme.primaryColor),
                       const SizedBox(width: 15),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(_deliveryOption == 1 ? "Delivery to Doorstep" : "Pickup at Branch", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                             if (_deliveryOption == 1) ...[
                               Text(_deliveryAddressController.text, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                               Text("Tel: ${_contactPhoneController.text}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                             ],
                             if (_deliveryOption == 2)
                               Consumer<BranchProvider>(
                                 builder: (context, branchProvider, _) {
                                   final branch = branchProvider.selectedBranch;
                                   final displayAddress = branch?.address ?? _branchAddress;
                                   final displayPhone = branch?.phone ?? _branchPhone;
                                   return Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Text("Office: $displayAddress", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                                       Text("Tel: $displayPhone", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                                     ],
                                   );
                                 }
                               ),
                           ],
                         ),
                       )
                     ],
                   ),
                 ),
               ),
             )
        ],
      );
    }
  }

  Widget _buildSummaryCard(bool isDark, Color textColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
      child: Column(
        children: [
          // ONLY Store Items
          ..._cartService.storeItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("${item.quantity}x ${item.product.name} ${item.variant != null ? '(${item.variant!.name})' : ''}", style: TextStyle(color: textColor))),
                Text(CurrencyFormatter.format(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
          )),
          const Divider(),
          
          if (_deliveryFee > 0) ...[
            const SizedBox(height: 10),
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Delivery Fee", style: TextStyle(color: textColor)),
                Text(CurrencyFormatter.format(_deliveryFee), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],

          const SizedBox(height: 10),
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("VAT (${_cartService.taxRate}%)", style: TextStyle(color: textColor)),
              Text(CurrencyFormatter.format(_cartService.storeTaxAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),

          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Amount", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(CurrencyFormatter.format(_cartService.storeTotalAmount + _cartService.storeTaxAmount + _deliveryFee), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
            ],
          ),
        ],
      ),
    ),),);
  }

  // ... (Helper widgets similar to CheckoutScreen) ...
  // To save space/complexity I'll inline simplest versions or copy relevant ones.
  
  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildOptionTile({
    required int value, 
    required int groupValue, 
    required String title, 
    required String subtitle, 
    required ValueChanged<int?> onChanged,
    required bool isDark,
    required Color colors,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : (isDark ? Colors.white10 : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: colors, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        ),
      ),
    );
  }

  Widget _buildBranchInfo(bool isDark) {
    // Prefer BranchProvider info
    final branch = Provider.of<BranchProvider>(context).selectedBranch;
    final displayAddress = branch?.address ?? _branchAddress;
    final displayPhone = branch?.phone ?? _branchPhone;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          margin: const EdgeInsets.only(left: 20, bottom: 20),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), style: BorderStyle.solid),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Our Branch Location:", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.store, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(displayAddress, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.call, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(displayPhone, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          ]),
        ],
      ),
    ),),);
  }

  final _orderService = OrderService();
  bool _isSubmitting = false;

  Future<void> _submitOrder() async {
    setState(() => _isSubmitting = true);
    
    // 1. Check for Mixed Cart (Bucket + Store)
    String scope = 'cart';
    bool includeLaundryItems = false;

    if (_cartService.items.isNotEmpty) {
      // Prompt User
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Items in My Bucket"),
          content: const Text("You have laundry items in your bucket. How would you like to proceed?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'separate'),
              child: const Text("Pay Store Only"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, 'combined'),
              child: const Text("Pay All Together"),
            ),
          ],
        ),
      );

      if (result == 'combined') {
        scope = 'combined';
        includeLaundryItems = true;
      } else {
        // Default or 'separate'
        scope = 'cart';
        includeLaundryItems = false;
      }
    }

    List<Map<String, dynamic>> items = [];
    
    // Store Items (Always included in Store checkout)
    for (var i in _cartService.storeItems) {
      items.add({
        'itemType': 'Product',
        'itemId': i.product.id,
        'name': i.product.name,
        'variant': i.variant?.name,
        'quantity': i.quantity,
        'price': i.price
      });
    }

    // Laundry Items (Conditional)
    if (includeLaundryItems) {
      for (var i in _cartService.items) {
        items.add({
          'itemType': 'Service',
          'itemId': i.item.id,
          'name': i.item.name,
          'serviceType': i.serviceType.name,
          'quantity': i.quantity,
          'price': i.totalPrice / i.quantity // Unit price
        });
      }
    }

    // [Multi-Branch] Get Selected Branch
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final selectedBranch = branchProvider.selectedBranch;

    // [Safeguard] Ensure Checkout Branch matches Cart Branch
    if (selectedBranch?.id != _cartService.activeBranchId && _cartService.activeBranchId != null) {
       setState(() => _isSubmitting = false);
       ToastUtils.show(context, "Branch mismatch. Please clear cart or switch branch back.", type: ToastType.error);
       return;
    }
    
    // Get Email for Paystack
    final auth = Provider.of<AuthService>(context, listen: false);
    final String email = auth.currentUser?['email'] ?? "guest@clotheline.com";

    // Debug: Ensure we don't send empty items (Standard logic)
    if (items.isEmpty) {
       setState(() => _isSubmitting = false);
       ToastUtils.show(context, "No items to checkout", type: ToastType.info);
       return;
    }

    final orderData = {
      'scope': scope, // [STRICT SCOPE]
      'branchId': selectedBranch?.id, 
      'items': items,
      // 'totalAmount': _cartService.totalAmount + _deliveryFee, // Calculated on backend
      'subtotal': _cartService.subtotal,
      'discountAmount': _cartService.discountAmount,
      'promoCode': _cartService.appliedPromotion?['code'],
      'taxAmount': _cartService.taxAmount,
      'appliedPromotion': _cartService.appliedPromotion, // Snapshot Promo
      'pickupOption': _deliveryOption == 2 ? 'Pickup' : 'None', 
      'deliveryOption': _deliveryOption == 1 ? 'Deliver' : 'Pickup',
      'deliveryAddress': _deliveryOption == 1 ? _deliveryAddressController.text : null,
      'deliveryPhone': _deliveryOption == 1 ? _contactPhoneController.text : null,
      'deliveryCoordinates': _deliveryOption == 1 && _deliveryLatLng != null ? {'lat': _deliveryLatLng!.latitude, 'lng': _deliveryLatLng!.longitude} : null,
      'deliveryFee': _deliveryOption == 1 ? _deliveryFee : 0,
      'guestInfo': {
         'name': 'Guest User',
         'email': email,
         'phone': _contactPhoneController.text
      }
    };

    try {
      if(mounted) ToastUtils.show(context, "Initializing Payment...", type: ToastType.info);

      // 1. Initialize & Get URL
      final initResult = await _paymentService().initializePayment(orderData); // Use instance or singleton? _paymentService instantiation
      // Correction: _paymentService is not field in StoreCheckoutScreenState? Ah, it was instantiated in submitOrder locally in previous code.
      // I need to instantiate it.
      
      if (initResult == null) {
         throw Exception("Failed to initialize payment");
      }
      
      final String url = initResult['authorization_url'];
      final String ref = initResult['reference'];

      // 2. Open WebView
      if (!mounted) return;
      // final paymentService = PaymentService(); // Instantiate if needed
      final bool paymentCompleted = await PaymentService().openPaymentWebView(context, url, ref); // Static or new instance

      if (paymentCompleted) {
         if(mounted) ToastUtils.show(context, "Verifying Payment...", type: ToastType.info);
         
         // 3. Verify & Create
         final verifyResult = await PaymentService().verifyAndCreateOrder(ref);
         
         if (verifyResult != null && verifyResult['status'] == 'success') {
            setState(() => _isSubmitting = false);
            
            if(!mounted) return;
            _cartService.clearStoreItems();
            
            showDialog(
              context: context, 
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text("Order Placed & Paid!"),
                content: const Text("Your store order has been successfully placed."),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop(); 
                      Navigator.of(context).pop(); 
                      Navigator.of(context).pop(); 
                    }, 
                    child: const Text("OK")
                  )
                ],
              )
            );
         } else {
             throw Exception("Payment verification failed");
         }
      } else {
         if(mounted) ToastUtils.show(context, "Payment cancelled", type: ToastType.info);
         setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if(mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
      setState(() => _isSubmitting = false);
    }
  }
  
  // Helper for PaymentService access if not defined in State
  PaymentService _paymentService() => PaymentService();

  Widget _buildBottomBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 20),
      child: _currentStage == 1 
        ? SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: () {
                // Validation
                if (_deliveryOption == 0) {
                  ToastUtils.show(context, "Please select a Delivery Option", type: ToastType.warning);
                  return;
                }
                if (_deliveryOption == 1 && (_deliveryAddressController.text.isEmpty || _contactPhoneController.text.isEmpty)) {
                   ToastUtils.show(context, "Address and Phone are required for delivery", type: ToastType.warning);
                   return;
                }
                setState(() => _currentStage = 2);
              },
              child: const Text("PROCEED TO SUMMARY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        : SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _isSubmitting ? null : _submitOrder,
              child: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("CONFIRM ORDER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
    );
  }
}
