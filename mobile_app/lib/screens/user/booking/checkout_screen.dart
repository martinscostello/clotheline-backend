import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../services/cart_service.dart';
import '../../../services/content_service.dart';
import '../../../services/delivery_service.dart';
import 'package:latlong2/latlong.dart';
import '../main_layout.dart';
import '../../../providers/branch_provider.dart';
import '../../../services/payment_service.dart';
import '../../../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/toast_utils.dart';
import '../../../models/booking_models.dart';
import '../../../models/service_model.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';
import 'package:laundry_app/widgets/glass/UnifiedGlassHeader.dart';
import 'combined_order_summary_screen.dart';
import '../../../widgets/delivery_location_selector.dart';
import '../../../models/delivery_location_model.dart';

class CheckoutScreen extends StatefulWidget {
  final String fulfillmentMode;
  const CheckoutScreen({super.key, this.fulfillmentMode = 'logistics'});

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

  // Animation
  late AnimationController _breathingController;

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


  bool get _isQuoteRequired {
    final filtered = _cartService.items.where((i) => i.fulfillmentMode == widget.fulfillmentMode).toList();
    return filtered.any((i) => i.quoteRequired);
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
  


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return PopScope(
      canPop: _currentStage == 1,
      onPopInvokedWithResult: (didPop, result) {
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
      // SPECIAL HANDLING FOR DEPLOYMENT MODE
      if (widget.fulfillmentMode == 'deployment') {
        return _buildDeploymentStage(isDark, textColor);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Before Wash Section
          _buildSectionHeader("Logistics (Pickup & Delivery)", textColor),
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

            const SizedBox(height: 30),
            
            // [NEW] Special Care Instructions
            if (_cartService.items.isNotEmpty) ...[
               _buildSectionHeader("🧺 Special Care Instructions", textColor),
               const SizedBox(height: 15),
               _buildSpecialCareInstructions(isDark, textColor),
               const SizedBox(height: 30),
            ],
        ],
      );
    }
  }

  final _notesController = TextEditingController();
  final int _notesMaxLength = 250;

  Widget _buildSpecialCareInstructions(bool isDark, Color textColor) {
    final List<String> chips = [
      "Gentle Wash", "No Bleach", "Cold Wash Only", 
      "Separate Whites", "Hand Wash", "Use Softener"
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((chip) => ActionChip(
            label: Text(chip, style: const TextStyle(fontSize: 12)),
            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            padding: EdgeInsets.zero,
            onPressed: () {
              String currentText = _notesController.text;
              if (currentText.length + chip.length + 2 > _notesMaxLength) {
                ToastUtils.show(context, "Note too long", type: ToastType.warning);
                return;
              }
              setState(() {
                if (currentText.isEmpty) {
                  _notesController.text = chip;
                } else if (currentText.endsWith(". ") || currentText.endsWith(" ")) {
                  _notesController.text += chip;
                } else {
                  _notesController.text += ". $chip";
                }
                // Move cursor to end
                _notesController.selection = TextSelection.fromPosition(TextPosition(offset: _notesController.text.length));
              });
            },
          )).toList(),
        ),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              TextField(
                controller: _notesController,
                maxLines: 4,
                maxLength: _notesMaxLength,
                style: TextStyle(color: textColor, fontSize: 14),
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "e.g. Do not use strong bleach. Hand wash only. Separate whites.",
                  hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(15),
                  counterStyle: const TextStyle(height: double.minPositive),
                  counterText: "",
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 15, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "${_notesController.text.length}/$_notesMaxLength",
                      style: TextStyle(
                        color: _notesController.text.length >= _notesMaxLength ? Colors.redAccent : (isDark ? Colors.white38 : Colors.black38),
                        fontSize: 10,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildDeploymentStage(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Service Location", textColor),
        const SizedBox(height: 15),
        Text(
          "Please select where the cleaning service will take place. Our specialists will arrive at this location.",
          style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 15),
        _buildAddressInputs(true), // Reuse pickup address logic for service location
        const SizedBox(height: 30),
      ],
    );
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

  Widget _buildAddressInputs(bool isPickup, {String labelPrefix = "Pickup"}) {
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
                  // Sync with CartService for real-time breakdown updates
                  _cartService.setDeliveryLocation(_pickupLatLng);
                } else {
                  _deliverySelection = selection;
                  _deliveryLatLng = LatLng(selection.lat, selection.lng);
                  // If it's a standard delivery, also sync if pickup isn't set
                  if (_pickupLatLng == null) {
                    _cartService.setDeliveryLocation(_deliveryLatLng);
                  }
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

                  // [NEW] Deployment Mode Inspection Fee Calculation
                  if (widget.fulfillmentMode == 'deployment') {
                    _pickupFee = 0.0; // Don't double charge logistics fee, inspection fee covers it
                    for (var item in _cartService.items) {
                      if (item.fulfillmentMode == 'deployment' && item.quoteRequired) {
                        item.inspectionFee = _calculateInspectionFee(selection.lat, selection.lng, item);
                      }
                    }
                  }
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

  double _calculateInspectionFee(double userLat, double userLng, CartItem item) {
    if (item.inspectionFeeZones.isEmpty) {
      return item.inspectionFee; 
    }
    
    // Fallback to branch location if service doesn't have a specific center
    final branch = Provider.of<BranchProvider>(context, listen: false).selectedBranch;
    final center = item.deploymentLocation ?? (branch != null ? LatLng(branch.location.lat, branch.location.lng) : const LatLng(6.334986, 5.603753)); // HQ fallback
    
    const Distance distanceCalc = Distance();
    final userPoint = LatLng(userLat, userLng);
    final double distanceKm = distanceCalc.as(LengthUnit.Meter, userPoint, center) / 1000;
    
    final zones = List<InspectionZone>.from(item.inspectionFeeZones);
    zones.sort((a, b) => a.radiusKm.compareTo(b.radiusKm));
    
    for (var zone in zones) {
      if (distanceKm <= zone.radiusKm) {
        return zone.fee;
      }
    }
    
    // If out of range, return the highest zone fee or current base fee
    return zones.isNotEmpty ? zones.last.fee : item.inspectionFee;
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
    bool isQuoteRequiredMode = widget.fulfillmentMode == 'deployment';

    double logistics = _pickupFee + _deliveryFee;

    // [HARD ISOLATION] Filter items by mode before calculating summary
    final modeItems = _cartService.items.where((i) => i.fulfillmentMode == widget.fulfillmentMode).toList();
    
    // Subtotal (Gross for Laundry, Inspection Fee for Deployment)
    double subtotal = modeItems.fold(0.0, (sum, i) => sum + i.totalPrice);
    
    // Discount (Mode specific)
    double modeDiscount = modeItems.fold(0.0, (sum, i) => sum + i.discountValue);
    
    // Tax (NET based, but 0 for Deployment)
    double tax = (widget.fulfillmentMode == 'deployment') 
        ? 0.0 
        : (subtotal - modeDiscount) * (_cartService.taxRate / 100);
        
    // [FIX] Total Due Now matches subtotal + logistics for Deployment
    // because subtotal already contains the flat inspection fee.
    // We isolate the service-level discount (which belongs to the future estimate) from the immediate fee.
    double total = (widget.fulfillmentMode.toLowerCase() == 'deployment')
        ? subtotal + logistics
        : (subtotal - modeDiscount) + tax + logistics;

    // Safety: Total should never be negative
    if (total < 0) total = 0;

    // [FIX] Total Total Gross estimate for the current mode items
    double estimateGross = modeItems.fold(0.0, (sum, i) => sum + i.baseTotal);
    double estimateNet = estimateGross - modeDiscount;
    double estimateTax = estimateNet * (_cartService.taxRate / 100);
    double estimateTotal = estimateNet + estimateTax;

    // Filter discounts for current mode
    final Map<String, double> modeDiscounts = {};
    for (var item in modeItems) {
      if (item.discountPercentage > 0) {
        String key = "Discount (${item.serviceType?.name ?? 'Generic'})";
        modeDiscounts[key] = (modeDiscounts[key] ?? 0.0) + item.discountValue;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isQuoteRequiredMode) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "SERVICE ESTIMATE", 
                  style: TextStyle(
                    color: AppTheme.primaryColor, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 12, 
                    letterSpacing: 1.2
                  )
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Itemized estimate grouped by service
            ...(() {
              final grouped = <String, List<CartItem>>{};
              for (var item in modeItems) {
                 final groupKey = item.serviceName ?? "Item";
                 grouped.putIfAbsent(groupKey, () => []).add(item);
              }
              
              return grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (grouped.length > 1) 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(entry.key.toUpperCase(), style: TextStyle(color: textColor.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0)),
                      ),
                    ...entry.value.map((item) {
                      double itemGross = item.item.basePrice * (item.serviceType?.priceMultiplier ?? 1.0) * item.quantity;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${item.quantity}x ${item.item.name}", 
                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)
                                  ),
                                  Text(
                                    item.serviceType?.name ?? 'Regular Service', 
                                    style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11)
                                  ),
                                ],
                              )
                            ),
                            Text(
                              CurrencyFormatter.format(itemGross), 
                              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)
                            ),
                          ],
                        ),
                      );
                    }),
                    if (grouped.length > 1) const Divider(height: 16),
                  ],
                );
              });
            }()).toList(),
            
            const Divider(height: 24),

            // Subtotal row for estimates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Service Subtotal", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                Text(
                  CurrencyFormatter.format(estimateGross), 
                  style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)
                ),
              ],
            ),
            const SizedBox(height: 6),
            
            // Itemized Discounts (Estimate based)
            ...modeDiscounts.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key, style: const TextStyle(color: Colors.green, fontSize: 12)),
                  Text("-${CurrencyFormatter.format(e.value)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("VAT (${_cartService.taxRate}%)", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
                Text(CurrencyFormatter.format(estimateTax), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Estimate", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 18)),
                Text(
                  CurrencyFormatter.format(estimateTotal), 
                  style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 18)
                ),
              ],
            ),
            const SizedBox(height: 6),
            Center(child: Text("Payable only AFTER on-site inspection", style: TextStyle(color: isDark ? Colors.orangeAccent.shade100 : Colors.orange.shade800, fontSize: 10, fontStyle: FontStyle.italic))),
            const SizedBox(height: 20),
            const Divider(thickness: 1, height: 40),
          ],

          if (isQuoteRequiredMode)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text("TOTAL PAYABLE NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.0)),
            ),

          // Items grouped by service
          ...(() {
            final grouped = <String, List<CartItem>>{};
            for (var item in modeItems) {
               final groupKey = item.serviceName ?? "Item";
               grouped.putIfAbsent(groupKey, () => []).add(item);
            }
            
            return grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   if (grouped.length > 1) 
                     Padding(
                       padding: const EdgeInsets.only(bottom: 8, top: 4),
                       child: Text(entry.key.toUpperCase(), style: TextStyle(color: textColor.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0)),
                     ),
                   ...entry.value.map((item) {
                      final bool isDeploymentInspection = item.fulfillmentMode == 'deployment' && item.quoteRequired;
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                isDeploymentInspection 
                                  ? "${item.quantity}x ${item.item.name} [Inspection Fee]"
                                  : "${item.quantity}x ${item.item.name}", 
                                style: TextStyle(color: textColor, fontWeight: isQuoteRequiredMode ? FontWeight.bold : FontWeight.normal)
                              )
                            ),
                            Text(
                              (_cartService.deliveryLocation == null && (item.quoteRequired || item.fulfillmentMode == 'deployment'))
                                ? "Pending"
                                : CurrencyFormatter.format(item.totalPrice), 
                              style: TextStyle(fontWeight: FontWeight.bold, color: (_cartService.deliveryLocation == null && (item.quoteRequired || item.fulfillmentMode == 'deployment')) ? Colors.orange : AppTheme.primaryColor)
                            ),
                          ],
                        ),
                      );
                   }),
                   if (grouped.length > 1) const Divider(height: 20),
                ],
              );
            });
          }()).toList(),
          
          if (!isQuoteRequiredMode) ...[
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Subtotal", style: TextStyle(color: textColor)),
                Text(CurrencyFormatter.format(subtotal), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 5),

            // Itemized Discounts
            ...modeDiscounts.entries.map((e) => Padding(
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
          ],

          if (_beforeWashOption == 1 || _afterWashOption == 1) const Divider(),

          
          if (_beforeWashOption == 1) // Pickup selected
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("Logistics / Pickup Fee", style: TextStyle(color: textColor)),
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
              Text(isQuoteRequiredMode ? "Total Due Now" : "Total", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(
                (_cartService.deliveryLocation == null && _cartService.items.any((i) => i.quoteRequired || i.fulfillmentMode == 'deployment'))
                  ? "Pending Address"
                  : CurrencyFormatter.format(total), 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: (_cartService.deliveryLocation == null && _cartService.items.any((i) => i.quoteRequired || i.fulfillmentMode == 'deployment')) ? Colors.orange : AppTheme.primaryColor)
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsSummary(bool isDark, Color textColor) {
    if (widget.fulfillmentMode == 'deployment') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
        ),
        child: _buildLogisticsRow(
          "Service Location", 
          _pickupSelection?.addressLabel ?? 'Not set', 
          textColor
        ),
      );
    }

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
    
    // Laundry Items (Filtered by mode)
    final filteredServiceItems = _cartService.items.where((i) => i.fulfillmentMode == widget.fulfillmentMode).toList();
    for (var i in filteredServiceItems) {
      items.add({
        'itemType': 'Service',
        'itemId': i.item.id,
        'name': i.item.name,
        'serviceType': i.serviceType?.name ?? 'Generic Service',
        'quantity': i.quantity,
        'price': i.fullEstimate / i.quantity // Unit price (Always use full estimate for record)
      });
    }

    // Store Items (Included only in logistics mode)
    if (includeStoreItems && widget.fulfillmentMode == 'logistics') {
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

    // [FIX] Logistics fees are zero for deployment orders as per user feedback
    double logistics = (widget.fulfillmentMode == 'deployment') ? 0.0 : (_pickupFee + _deliveryFee);
    
    final modeItems = _cartService.items.where((i) => i.fulfillmentMode == widget.fulfillmentMode).toList();
    double subtotalItems = modeItems.fold(0.0, (sum, i) => sum + i.totalPrice);
    double modeDiscount = modeItems.fold(0.0, (sum, i) => sum + i.discountValue);
    double tax = (widget.fulfillmentMode == 'deployment') 
        ? 0.0 
        : (subtotalItems - modeDiscount) * (_cartService.taxRate / 100);
    double calculatedTotal = (widget.fulfillmentMode.toLowerCase() == 'deployment')
        ? subtotalItems + logistics
        : (subtotalItems - modeDiscount) + tax + logistics;

    final orderData = {
      'scope': scope, 
      'branchId': selectedBranch?.id,
      'fulfillmentMode': widget.fulfillmentMode,
      'items': items,
      'totalAmount': calculatedTotal, // Backend compares this for divergence
      'pickupOption': _beforeWashOption == 1 ? 'Pickup' : 'Dropoff',
      'deliveryOption': _afterWashOption == 1 ? 'Deliver' : 'Pickup',
      'pickupAddress': widget.fulfillmentMode == 'deployment' ? _pickupSelection?.addressLabel : (_beforeWashOption == 1 ? _pickupSelection?.addressLabel : null),
      'pickupPhone': widget.fulfillmentMode == 'deployment' ? _pickupPhoneController.text : (_beforeWashOption == 1 ? _pickupPhoneController.text : null),
      'deliveryAddress': widget.fulfillmentMode == 'deployment' ? null : (_afterWashOption == 1 ? _deliverySelection?.addressLabel : null),
      'deliveryPhone': widget.fulfillmentMode == 'deployment' ? null : (_afterWashOption == 1 ? _deliveryPhoneController.text : null),
      'pickupLocation': widget.fulfillmentMode == 'deployment' ? _pickupSelection?.toJson() : (_beforeWashOption == 1 ? _pickupSelection?.toJson() : null), 
      'deliveryLocation': widget.fulfillmentMode == 'deployment' ? null : (_afterWashOption == 1 ? _deliverySelection?.toJson() : null), 
      'pickupCoordinates': widget.fulfillmentMode == 'deployment' ? (_pickupLatLng != null ? {'lat': _pickupLatLng!.latitude, 'lng': _pickupLatLng!.longitude} : null) : (_pickupLatLng != null ? {'lat': _pickupLatLng!.latitude, 'lng': _pickupLatLng!.longitude} : null),
      'deliveryCoordinates': _deliveryLatLng != null ? {'lat': _deliveryLatLng!.latitude, 'lng': _deliveryLatLng!.longitude} : null,
      'pickupFee': widget.fulfillmentMode == 'deployment' ? 0.0 : _pickupFee,
      'deliveryFee': widget.fulfillmentMode == 'deployment' ? 0.0 : _deliveryFee,
      'discountBreakdown': widget.fulfillmentMode == 'deployment' ? {} : _cartService.serviceDiscounts,
      'storeDiscount': widget.fulfillmentMode == 'deployment' ? 0.0 : _cartService.storeDiscountAmount,
      'laundryNotes': _notesController.text.isNotEmpty ? _notesController.text : null,
      
      // [NEW] Service DNA
      'quoteStatus': _isQuoteRequired ? 'Pending' : 'None',
      'inspectionFee': _cartService.items
          .where((i) => i.fulfillmentMode == widget.fulfillmentMode)
          .fold(0.0, (sum, i) => sum + (i.quoteRequired ? i.inspectionFee : 0.0)),

      'guestInfo': {
        'name': auth.currentUser != null ? (auth.currentUser!['name'] ?? 'Guest User') : 'Guest User', 
        'email': email,
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
            // IMPORTANT: Only clear the items we just bought
            if (widget.fulfillmentMode == 'logistics') {
               _cartService.clearCart(); 
            } else {
               _cartService.items.where((i) => i.fulfillmentMode == widget.fulfillmentMode).toList().forEach((i) => _cartService.removeItem(i));
            }
            
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
                if (widget.fulfillmentMode == 'deployment') {
                  if (_pickupSelection == null || _pickupPhoneController.text.isEmpty) {
                    ToastUtils.show(context, "Please provide the service location and phone", type: ToastType.warning);
                    return;
                  }
                } else {
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
                      : Text(_isQuoteRequired ? "PAY INSPECTION FEE" : "PAY NOW", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
