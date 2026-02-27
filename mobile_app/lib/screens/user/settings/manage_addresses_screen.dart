import 'package:flutter/material.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/glass/LaundryGlassBackground.dart';
import '../../../widgets/glass/UnifiedGlassHeader.dart';
import '../../../widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../../../widgets/delivery_location_selector.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  final AddressService _addressService = AddressService();
  List<SavedAddress> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final list = await _addressService.getSavedAddresses();
    if (mounted) {
      setState(() {
        _addresses = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAddress(String id) async {
    final success = await _addressService.deleteAddress(id);
    if (success && mounted) {
      ToastUtils.show(context, "Address deleted");
      _loadAddresses();
    }
  }

  void _showAddAddressDialog() {
    if (_addresses.length >= 3) {
      ToastUtils.show(context, "You can only save up to 3 addresses.", type: ToastType.warning);
      return;
    }

    DeliveryLocationSelection? tempSelection;
    final labelController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Save New Address", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepIndicator(1, "Name this address"),
                        const SizedBox(height: 8),
                        Text("Give this location a recognizable name like 'Home', 'Office' or 'My Store'.", 
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: labelController,
                          decoration: InputDecoration(
                            hintText: "e.g. Home",
                            prefixIcon: const Icon(Icons.label_outline, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildStepIndicator(2, "Select the location"),
                        const SizedBox(height: 8),
                        Text("Search for your street or use the map icon to pick the exact spot on the map.", 
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                        const SizedBox(height: 12),
                        DeliveryLocationSelector(
                          onLocationSelected: (sel) {
                            tempSelection = sel;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      if (labelController.text.isEmpty || tempSelection == null) {
                        ToastUtils.show(context, "Please provide a label and select a location", type: ToastType.warning);
                        return;
                      }

                      final success = await _addressService.addAddress({
                        'label': labelController.text,
                        'addressLabel': tempSelection!.addressLabel,
                        'lat': tempSelection!.lat,
                        'lng': tempSelection!.lng,
                        'city': tempSelection?.area != null ? nigeriaAreas.firstWhere((a) => a.name == tempSelection!.area).city : "Abuja", 
                        'landmark': tempSelection!.landmark,
                      });

                      if (success && mounted) {
                        Navigator.pop(context);
                        ToastUtils.show(context, "Address saved!");
                        _loadAddresses();
                      }
                    },
                    child: const Text("SAVE ADDRESS", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: LaundryGlassBackground(
        child: Column(
          children: [
            UnifiedGlassHeader(
              isDark: isDark,
              title: Text("Manage Addresses", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              onBack: () => Navigator.pop(context),
            ),
            
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _addresses.isEmpty 
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, size: 64, color: textColor.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text("No saved addresses yet", style: TextStyle(color: textColor.withOpacity(0.5))),
                      ],
                    ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _addresses.length,
                      itemBuilder: (context, index) {
                        final addr = _addresses[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GlassContainer(
                            opacity: isDark ? 0.1 : 0.05,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                  child: const Icon(Icons.bookmark, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(addr.label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(addr.addressLabel, style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteAddress(addr.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // Add Button
            if (_addresses.length < 3)
              Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, MediaQuery.of(context).padding.bottom + 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _showAddAddressDialog,
                    icon: const Icon(Icons.add, color: AppTheme.primaryColor),
                    label: const Text("ADD NEW ADDRESS", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            
            // Limit Message
            if (_addresses.length >= 3)
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 20),
                child: Text("Maximum of 3 addresses reached", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
          child: Text(step.toString(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
