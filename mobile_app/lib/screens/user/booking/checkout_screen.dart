import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../services/cart_service.dart';
import '../../../services/content_service.dart';
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
import '../../../utils/toast_utils.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'combined_order_summary_screen.dart';
import '../../../widgets/delivery_location_selector.dart';
import '../../../models/delivery_location_model.dart';

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
  int _beforeWashOption = 0; // 0 = Unselected, 1 = Pickup, 2 = Dropoff
  int _afterWashOption = 0; // 0 = Unselected, 1 = Deliver, 2 = Pickup

  // Controllers
  final _pickupPhoneController = TextEditingController();
  final _deliveryPhoneController = TextEditingController();
  final _pickupPhoneFocusNode = FocusNode(); // New
  final _deliveryPhoneFocusNode = FocusNode(); // New
  final _promoController = TextEditingController(); // [New]
  DeliveryLocationSelection? _pickupSelection;
  DeliveryLocationSelection? _deliverySelection;

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
    _pickupPhoneFocusNode.dispose();
    _deliveryPhoneFocusNode.dispose();
    _pickupPhoneController.dispose();
    _deliveryPhoneController.dispose();
    _promoController.dispose();
    super.dispose();
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
      if(mounted) ToastUtils.show(context, "Location permissions are permanently denied, we cannot request permissions.", type: ToastType.error);
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
      if(mounted) ToastUtils.show(context, "Error getting location: $e", type: ToastType.error);
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
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        body: LaundryGlassBackground(
          child: Column(
            children: [
              // Header
              UnifiedGlassHeader(
                isDark: isDark,
                title: Text(_getStageTitle(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                onBack: () {
                  if (_currentStage > 1) {
                    setState(() => _currentStage--);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),

              // Scrollable Content
              Expanded(
                child: ListenableBuilder(
                  listenable: _cartService,
                  builder: (context, _) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: _buildStageContent(isDark, textColor),
                    );
                  }
                ),
              ),

              // Bottom Area (No container background)
              _buildBottomBar(isDark),
            ],
          ),
        ),
      ),
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
          if (_beforeWashOption == 1) _buildAddressInputs(true),
          
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
                 _pickupSelection = null;
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
          if (_afterWashOption == 1) _buildAddressInputs(false, labelPrefix: "Delivery"),

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
                 _deliverySelection = null;
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
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : (isDark ? Colors.white10 : Colors.grey.shade50),
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

  Widget _buildAddressInputs(bool isPickup, {String labelPrefix = "Pickup"}) {
    // Check if GPS/Selection is active for this field
    bool isGpsActive = isPickup ? _pickupSelection != null : _deliverySelection != null;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 10, bottom: 20, top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeliveryLocationSelector(
            initialValue: isPickup ? _pickupSelection : _deliverySelection,
            onCollapsedStatusChanged: (collapsed) {
              if (collapsed) {
                // Auto-focus phone number
                FocusScope.of(context).requestFocus(isPickup ? _pickupPhoneFocusNode : _deliveryPhoneFocusNode);
              }
            },
            onLocationSelected: (selection) {
              setState(() {
                if (isPickup) {
                  _pickupSelection = selection;
                  _pickupLatLng = LatLng(selection.lat, selection.lng);
                } else {
                  _deliverySelection = selection;
                  _deliveryLatLng = LatLng(selection.lat, selection.lng);
                }
                
                // Recalculate Fee
                final deliveryService = Provider.of<DeliveryService>(context, listen: false);
                final branchProvider = Provider.of<BranchProvider>(context, listen: false);
                
                double fee = deliveryService.calculateDeliveryFee(
                  selection.lat, 
                  selection.lng,
                  branch: branchProvider.selectedBranch
                );
                
                if (isPickup) {
                  _pickupFee = fee;
                } else {
                  _deliveryFee = fee;
                }
              });
            },
          ),
          const SizedBox(height: 10),
          _buildTextField(
            isPickup ? _pickupPhoneController : _deliveryPhoneController, 
            "Contact Phone", 
            Icons.phone, 
            Theme.of(context).brightness == Brightness.dark,
            keyboardType: TextInputType.phone,
            focusNode: isPickup ? _pickupPhoneFocusNode : _deliveryPhoneFocusNode,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hint, 
    IconData icon, 
    bool isDark, {
    TextInputType? keyboardType,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
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
    // Correct Total Calculation incl Tax and Logistics (Service Only)
    double subtotal = _cartService.serviceTotalAmount;
    double tax = _cartService.serviceTaxAmount; // Use granular service tax
    double logistics = _pickupFee + _deliveryFee;
    double total = subtotal + tax + logistics; // Calculate locally to ensure isolation 

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

          // [NEW] Itemized Discounts
          ..._cartService.laundryDiscounts.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key, style: const TextStyle(color: Colors.green, fontSize: 13)),
                Text("-${CurrencyFormatter.format(e.value)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          )),

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
    final branch = Provider.of<BranchProvider>(context, listen: false).selectedBranch;
    final displayAddress = branch?.address ?? _branchAddress;
    final displayPhone = branch?.phone ?? _branchPhone;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLogisticsRow(
            "Pickup", 
            _beforeWashOption == 1 
              ? "At: ${_pickupSelection?.addressLabel ?? 'Not set'}" 
              : "Drop off at Office:\n$displayAddress\nTel: $displayPhone", 
            textColor
          ),
          const SizedBox(height: 15),
          _buildLogisticsRow(
            "Delivery", 
            _afterWashOption == 1 
              ? "To: ${_deliverySelection?.addressLabel ?? 'Not set'}" 
              : "Pick up at Office:\n$displayAddress\nTel: $displayPhone", 
            textColor
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsRow(String label, String value, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
        Expanded(child: Text(value, style: TextStyle(color: textColor))),
      ],
    );
  }

  Widget _buildPromoSection(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text("Promotions / Promo Code", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_cartService.appliedPromotion != null)
             Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3))
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${_cartService.appliedPromotion!['code']} applied",
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                    )
                  ),
                  InkWell(
                    onTap: () {
                      _cartService.removePromo();
                      setState(() {});
                    },
                    child: const Icon(Icons.close, size: 18, color: Colors.grey)
                  )
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _promoController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: "Enter Code",
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  ),
                  onPressed: () async {
                    if (_promoController.text.trim().isEmpty) return;
                    FocusScope.of(context).unfocus();
                    
                    final error = await _cartService.applyPromoCode(_promoController.text.trim());
                    if (error != null) {
                      if(mounted) ToastUtils.show(context, error, type: ToastType.error);
                    } else {
                      _promoController.clear();
                      if(mounted) ToastUtils.show(context, "Discount Applied!", type: ToastType.success);
                    }
                    setState(() {}); // Rebuild to show applied status
                  },
                  child: const Text("Apply"),
                )
              ],
            )
        ],
      ),
    );
  }

  final _paymentService = PaymentService();
  bool _isSubmitting = false;

  Future<void> _submitOrder() async {
    setState(() => _isSubmitting = true);

    // 1. Check for Mixed Cart (Bucket + Store)
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
              onPressed: () {
                Navigator.pop(ctx, 'combined');
                // Navigate to Combined Summary
                Navigator.push(context, MaterialPageRoute(builder: (_) => CombinedOrderSummaryScreen(
                  logisticsData: {'deliveryFee': _deliveryFee, 'pickupFee': _pickupFee},
                  onProceed: (logistics) async {
                    Navigator.pop(context); // Close summary
                    await _processPayment(scope: 'combined', includeStoreItems: true);
                  },
                )));
              },
              child: const Text("Pay All Together"),
            ),
          ],
        ),
      );

      // If user chose Separate, continue as Bucket. If Combined, the dialog action handled it.
      if (result == 'separate') {
         await _processPayment(scope: 'bucket', includeStoreItems: false);
      }
      // If combined, it was handled in the dialog callback.
      setState(() => _isSubmitting = false); // Reset if handled externally or cancelled
    } else {
      // Standard Bucket Checkout
      await _processPayment(scope: 'bucket', includeStoreItems: false);
    }
  }

  Future<void> _processPayment({required String scope, required bool includeStoreItems}) async {
    setState(() => _isSubmitting = true);

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
       ToastUtils.show(context, "No items to checkout", type: ToastType.info);
       return;
    }

    final orderData = {
      'scope': scope, // [STRICT SCOPE]
      'branchId': selectedBranch?.id,
      'items': items,
      // 'totalAmount': total, // Backend calculates this now to be secure
      'pickupOption': _beforeWashOption == 1 ? 'Pickup' : 'Dropoff',
      'deliveryOption': _afterWashOption == 1 ? 'Deliver' : 'Pickup',
      'pickupAddress': _beforeWashOption == 1 ? _pickupSelection?.addressLabel : null,
      'pickupPhone': _beforeWashOption == 1 ? _pickupPhoneController.text : null,
      'deliveryAddress': _afterWashOption == 1 ? _deliverySelection?.addressLabel : null,
      'deliveryPhone': _afterWashOption == 1 ? _deliveryPhoneController.text : null,
      'pickupLocation': _beforeWashOption == 1 ? _pickupSelection?.toJson() : null, // [New]
      'deliveryLocation': _afterWashOption == 1 ? _deliverySelection?.toJson() : null, // [New]
      'pickupCoordinates': _pickupLatLng != null ? {'lat': _pickupLatLng!.latitude, 'lng': _pickupLatLng!.longitude} : null,
      'deliveryCoordinates': _deliveryLatLng != null ? {'lat': _deliveryLatLng!.latitude, 'lng': _deliveryLatLng!.longitude} : null,
      'pickupFee': _pickupFee,
      'deliveryFee': _deliveryFee,
      'discountBreakdown': _cartService.laundryDiscounts, // [New]
      'storeDiscount': _cartService.storeDiscountAmount, // [New]
      'guestInfo': {
        'name': auth.currentUser != null ? (auth.currentUser!['name'] ?? 'Guest User') : 'Guest User', 
        'email': email, // Pass email for Paystack
        'phone': _pickupPhoneController.text.isNotEmpty ? _pickupPhoneController.text : _deliveryPhoneController.text
      }
    };

    try {
      if(mounted) ToastUtils.show(context, "Initializing Payment...", type: ToastType.info);

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
         if(mounted) ToastUtils.show(context, "Verifying Payment...", type: ToastType.info);
         
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
            
            ToastUtils.show(context, "Payment Successful! Order Confirmed.", type: ToastType.success);
         } else {
             // Verification failed
             throw Exception("Payment verification failed");
         }
      } else {
          // User closed webview
          if(mounted) ToastUtils.show(context, "Payment cancelled", type: ToastType.info);
          setState(() => _isSubmitting = false);
      }

    } catch (e) {
      if(mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
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
      if(mounted) ToastUtils.show(context, "Could not launch dialer", type: ToastType.error);
    }
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      // key: _paymentKey, // [KEY] Payment Section (Removed)
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30), 
      child: SafeArea(
        top: false,
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
                if (_beforeWashOption == 0 || _afterWashOption == 0) {
                  ToastUtils.show(context, "Please select both Pickup and Delivery options", type: ToastType.warning);
                  return;
                }
                if (_beforeWashOption == 1 && (_pickupSelection == null || _pickupPhoneController.text.isEmpty)) {
                  ToastUtils.show(context, "Please provide pickup location and phone", type: ToastType.warning);
                  return;
                }
                if (_afterWashOption == 1 && (_deliverySelection == null || _deliveryPhoneController.text.isEmpty)) {
                  ToastUtils.show(context, "Please provide delivery location and phone", type: ToastType.warning);
                  return;
                }
                setState(() => _currentStage = 2);
              },
              child: const Text("PROCEED", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
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
                      : const Text("PAY NOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _showCallDialog, 
                  child: const Text("Call to Place Order", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ),
              ),
            ],
          ),
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
      if(mounted) ToastUtils.show(context, "Could not launch dialer", type: ToastType.error);
    }
  }
}
