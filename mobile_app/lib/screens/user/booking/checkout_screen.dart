import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../models/booking_models.dart';
import '../../../services/cart_service.dart';
import 'package:flutter/services.dart';
import '../../../services/content_service.dart';
import '../../../models/app_content_model.dart';
import '../../../services/order_service.dart';
import '../../../services/delivery_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../main_layout.dart';
import '../../../providers/branch_provider.dart';
import '../../../services/payment_service.dart';
import '../../../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/currency_formatter.dart';

class CheckoutScreen extends StatefulWidget {
  // Use Singleton instead of passing list
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> with SingleTickerProviderStateMixin {
  final _cartService = CartService();
  int _currentStage = 1;
  
  // Logic Selections
  int _beforeWashOption = 1; 
  int _afterWashOption = 1;

  // Controllers
  final _pickupAddressController = TextEditingController();
  final _pickupPhoneController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _deliveryPhoneController = TextEditingController();

  // Location Data
  LatLng? _pickupLatLng;
  LatLng? _deliveryLatLng;
  double _pickupFee = 0.0;
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

  Future<void> _fetchContent() async {
    final content = await _contentService.getAppContent();
    if(mounted && content != null) {
      setState(() {
        _branchAddress = content.contactAddress;
        _branchPhone = content.contactPhone;
      });
    }
  }

  // Navigation Helpers
  String _getStageTitle() {
    if (_currentStage == 1) return "Pickup & Drop-off";
    if (_currentStage == 2) return "Order Summary";
    return "Checkout";
  }
  
  // LOGIC: Get Location
  Future<void> _getCurrentLocation(bool isPickup) async {
    setState(() => _isLocating = true);
    
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location services are disabled.")));
      setState(() => _isLocating = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permissions are denied")));
        setState(() => _isLocating = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permissions are permanently denied, we cannot request permissions.")));
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
        if (isPickup) {
          _pickupLatLng = LatLng(position.latitude, position.longitude);
          _pickupFee = fee;
          // Note: NOT updating address controller text
        } else {
          _deliveryLatLng = LatLng(position.latitude, position.longitude);
          _deliveryFee = fee;
          // Note: NOT updating address controller text
        }
      });
      
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
    } finally {
      setState(() => _isLocating = false);
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
        appBar: AppBar(
          title: Text(_getStageTitle(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_currentStage > 1) {
                setState(() => _currentStage--);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        body: ListenableBuilder(
          listenable: _cartService,
          builder: (context, _) {
            return Column(
              children: [
                // Step Indicator
                _buildStepIndicator(isDark),
  
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildStageContent(isDark, textColor),
                  ),
                ),
  
                 // Navigation Buttons
                 _buildBottomBar(isDark),
              ],
            );
          }
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
          // Before Wash Section
          _buildSectionHeader("Before Wash", textColor),
          const SizedBox(height: 15),
          _buildOptionTile(
            value: 1,
            groupValue: _beforeWashOption,
            title: "Pickup: We will pickup",
            subtitle: "Schedule a pickup time",
            onChanged: (val) => setState(() => _beforeWashOption = val!),
            isDark: isDark,
            colors: textColor,
          ),
          if (_beforeWashOption == 1) _buildAddressInputs(_pickupAddressController, _pickupPhoneController, isDark, true),
          
          const SizedBox(height: 10),
          _buildOptionTile(
            value: 2,
            groupValue: _beforeWashOption,
            title: "I'll Drop off",
            subtitle: "Bring to our location",
            onChanged: (val) {
               setState(() {
                 _beforeWashOption = val!;
                 _pickupFee = 0.0; // Reset fee
                 _pickupLatLng = null; // Reset GPS
               });
            },
            isDark: isDark,
            colors: textColor,
          ),
          if (_beforeWashOption == 2) _buildBranchInfo(isDark),

          const SizedBox(height: 30),

          // After Wash Section
          _buildSectionHeader("After Wash", textColor),
          const SizedBox(height: 15),
           _buildOptionTile(
            value: 1,
            groupValue: _afterWashOption,
            title: "Deliver to Me",
            subtitle: "Schedule a delivery time",
            onChanged: (val) => setState(() => _afterWashOption = val!),
            isDark: isDark,
            colors: textColor,
          ),
          if (_afterWashOption == 1) _buildAddressInputs(_deliveryAddressController, _deliveryPhoneController, isDark, false, labelPrefix: "Delivery"),

          const SizedBox(height: 10),
          _buildOptionTile(
            value: 2,
            groupValue: _afterWashOption,
            title: "I'll Pick up",
            subtitle: "Collect from our location",
            onChanged: (val) {
               setState(() {
                 _afterWashOption = val!;
                 _deliveryFee = 0.0; // Reset fee
                 _deliveryLatLng = null; // Reset GPS
               });
            },
            isDark: isDark,
            colors: textColor,
          ),
           if (_afterWashOption == 2) _buildBranchInfo(isDark),
        ],
      );
    } else {
      // Stage 2: Summary
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           _buildSectionHeader("Order Details", textColor),
           const SizedBox(height: 15),
           _buildSummaryCard(isDark, textColor),
           
           const SizedBox(height: 30),
            _buildSectionHeader("Logistics", textColor),
            const SizedBox(height: 10),
            _buildLogisticsSummary(isDark, textColor),
        ],
      );
    }
  }

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

  Widget _buildAddressInputs(TextEditingController addrCtrl, TextEditingController phoneCtrl, bool isDark, bool isPickup, {String labelPrefix = "Pickup"}) {
    // Check if GPS is active for this field
    bool isGpsActive = isPickup ? _pickupLatLng != null : _deliveryLatLng != null;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 10, bottom: 20, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildTextField(addrCtrl, "$labelPrefix Address (Manual Entry)", Icons.location_on, isDark)),
              const SizedBox(width: 8),
              
              // Animated GPS Button
              InkWell(
                onTap: () => _getCurrentLocation(isPickup),
                child: AnimatedBuilder(
                  animation: _breathingAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isGpsActive ? _breathingAnimation.value : 1.0,
                      child: Container(
                        height: 50, width: 50,
                        decoration: BoxDecoration(
                          color: isGpsActive 
                              ? AppTheme.primaryColor 
                              : AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryColor),
                          boxShadow: isGpsActive ? [
                            BoxShadow(color: AppTheme.primaryColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                          ] : [],
                        ),
                        child: Icon(Icons.my_location, color: isGpsActive ? Colors.white : AppTheme.primaryColor),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
          const SizedBox(height: 5),
          // Note Text
          Text(
            "Turn on GPS to get accurate Delivery fee", 
            style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)
          ),
          const SizedBox(height: 10),
          _buildTextField(phoneCtrl, "Contact Phone", Icons.phone, isDark),
        ],
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

    return Container(
      margin: const EdgeInsets.only(left: 20, bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, style: BorderStyle.solid),
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
    );
  }

  Widget _buildSummaryCard(bool isDark, Color textColor) {
    // Correct Total Calculation incl Tax and Logistics
    double subtotal = _cartService.subtotal;
    double tax = _cartService.taxAmount;
    double logistics = _pickupFee + _deliveryFee;
    double total = _cartService.totalAmount + logistics; 

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          // Laundry Items
          ..._cartService.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text("${item.quantity}x ${item.item.name} (${item.serviceType.name})", style: TextStyle(color: textColor))),
                Text(CurrencyFormatter.format(item.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
          )),
          
          const Divider(),
          
          // Subtotal Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Subtotal", style: TextStyle(color: textColor)),
              Text(CurrencyFormatter.format(subtotal), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 5),

           // VAT Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("VAT (${_cartService.taxRate}%)", style: TextStyle(color: textColor)),
              Text(CurrencyFormatter.format(tax), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),

          if (_beforeWashOption == 1 || _afterWashOption == 1) const Divider(),

          
          if (_beforeWashOption == 1) // Pickup selected
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("Pickup Fee", style: TextStyle(color: textColor)),
                 Text(CurrencyFormatter.format(_pickupFee), style: const TextStyle(fontWeight: FontWeight.bold)),
               ],
             ),
          
          if (_afterWashOption == 1) // Delivery selected
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("Delivery Fee", style: TextStyle(color: textColor)),
                 Text(CurrencyFormatter.format(_deliveryFee), style: const TextStyle(fontWeight: FontWeight.bold)),
               ],
             ),
          
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(CurrencyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsSummary(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogisticsRow("Pickup", _beforeWashOption == 1 ? "At: ${_pickupAddressController.text}" : "Drop off at Branch", textColor),
          const SizedBox(height: 10),
          _buildLogisticsRow("Delivery", _afterWashOption == 1 ? "To: ${_deliveryAddressController.text}" : "Pick up at Branch", textColor),
        ],
      ),
    );
  }

  Widget _buildLogisticsRow(String label, String value, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        Expanded(child: Text(value, style: TextStyle(color: textColor))),
      ],
    );
  }

  final _orderService = OrderService();
  final _paymentService = PaymentService();
  bool _isSubmitting = false;

  Future<void> _submitOrder() async {
    setState(() => _isSubmitting = true);

    // 1. Check for Mixed Cart (Bucket + Store)
    String scope = 'bucket';
    bool includeStoreItems = false;

    if (_cartService.storeItems.isNotEmpty) {
      // Prompt User
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Items in Cart"),
          content: const Text("You have items in your Store Cart. How would you like to proceed?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'separate'),
              child: const Text("Pay Laundry Only"),
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
        includeStoreItems = true;
      } else {
        // Default or 'separate'
        scope = 'bucket';
        includeStoreItems = false;
      }
    }

    // Prepare Items
    List<Map<String, dynamic>> items = [];
    
    // Laundry Items (Always included in Bucket checkout)
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

    // Store Items (Conditional)
    if (includeStoreItems) {
      for (var i in _cartService.storeItems) {
        items.add({
          'itemType': 'Product',
          'itemId': i.product.id,
          'name': i.product.name + (i.variant != null ? " (${i.variant!.name})" : ""),
          'quantity': i.quantity,
          'price': i.price
        });
      }
    }

    // [Multi-Branch] Get Selected Branch
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final selectedBranch = branchProvider.selectedBranch;
    
    // Get Email for Paystack
    final auth = Provider.of<AuthService>(context, listen: false);
    final String email = auth.currentUser?['email'] ?? "guest@clotheline.com";

    // Debug: Ensure we don't send empty items (Standard logic)
    if (items.isEmpty) {
       setState(() => _isSubmitting = false);
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No items to checkout")));
       return;
    }

    final orderData = {
      'scope': scope, // [STRICT SCOPE]
      'branchId': selectedBranch?.id,
      'items': items,
      // 'totalAmount': total, // Backend calculates this now to be secure
      'pickupOption': _beforeWashOption == 1 ? 'Pickup' : 'Dropoff',
      'deliveryOption': _afterWashOption == 1 ? 'Deliver' : 'Pickup',
      'pickupAddress': _beforeWashOption == 1 ? _pickupAddressController.text : null,
      'pickupPhone': _beforeWashOption == 1 ? _pickupPhoneController.text : null,
      'deliveryAddress': _afterWashOption == 1 ? _deliveryAddressController.text : null,
      'deliveryPhone': _afterWashOption == 1 ? _deliveryPhoneController.text : null,
      'pickupCoordinates': _pickupLatLng != null ? {'lat': _pickupLatLng!.latitude, 'lng': _pickupLatLng!.longitude} : null,
      'deliveryCoordinates': _deliveryLatLng != null ? {'lat': _deliveryLatLng!.latitude, 'lng': _deliveryLatLng!.longitude} : null,
      'pickupFee': _pickupFee,
      'deliveryFee': _deliveryFee,
      'guestInfo': {
        'name': auth.currentUser != null ? (auth.currentUser!['name'] ?? 'Guest User') : 'Guest User', 
        'email': email, // Pass email for Paystack
        'phone': _pickupPhoneController.text.isNotEmpty ? _pickupPhoneController.text : _deliveryPhoneController.text
      }
    };

    try {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Initializing Payment...")));

      // 1. Initialize Payment (Get URL & Ref)
      final initResult = await _paymentService.initializePayment(orderData);
      
      if (initResult == null) {
        throw Exception("Failed to initialize payment");
      }

      final String url = initResult['authorization_url'];
      final String ref = initResult['reference'];

      // 2. Open WebView
      if (!mounted) return;
      final bool paymentCompleted = await _paymentService.openPaymentWebView(context, url, ref);

      if (paymentCompleted) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verifying Payment...")));
         
         // 3. Verify & Create Order
         final verifyResult = await _paymentService.verifyAndCreateOrder(ref);
         
         if (verifyResult != null && verifyResult['status'] == 'success') {
            // Success!
            setState(() => _isSubmitting = false);
            
            if(!mounted) return;
            _cartService.clearCart(); 
            
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainLayout(initialIndex: 2)), 
              (route) => false
            );
            
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful! Order Confirmed."), backgroundColor: Colors.green));
         } else {
             // Verification failed
             throw Exception("Payment verification failed");
         }
      } else {
          // User closed webview
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment cancelled")));
          setState(() => _isSubmitting = false);
      }

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      setState(() => _isSubmitting = false);
    }
  }

  // Dialer
  Future<void> _callBranch() async {
    final cleanPhone = _branchPhone.replaceAll(RegExp(r'[^\d+]'), ''); // Keep digits and +
    if (cleanPhone.isEmpty) return;
    
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: cleanPhone,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch dialer")));
    }
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
           BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
        ]
      ),
      child: _currentStage == 1 
        ? SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => setState(() => _currentStage = 2),
              child: const Text("PROCEED", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        : Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _isSubmitting ? null : _submitOrder,
                  child: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("PAY NOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _showCallDialog, 
                  child: const Text("Call to Place Order", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ),
              ),
            ],
          ),
    );
  }

  // New Dialog Logic
  void _showCallDialog() {
    // Prefer Branch Phone
    final branch = Provider.of<BranchProvider>(context, listen: false).selectedBranch;
    final phoneToCall = branch?.phone ?? _branchPhone; 

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Call to Place Order"),
        content: Text("Dial - $phoneToCall"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            onPressed: () {
               Navigator.pop(ctx);
               _launchIntenDialer(phoneToCall);
            },
            child: const Text("Call"),
          ),
        ],
      ),
    );
  }

  Future<void> _launchIntenDialer(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), ''); 
    if (cleanPhone.isEmpty) return;
    
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch dialer")));
    }
  }
}
