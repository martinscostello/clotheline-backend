import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass/LaundryGlassBackground.dart';
import '../../../widgets/glass/UnifiedGlassHeader.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../services/address_service.dart';
import '../../../widgets/delivery_location_selector.dart';
import '../../../models/delivery_location_model.dart';
import '../../../utils/toast_utils.dart';

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
                        const Text("Label (e.g. Home, Office)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        TextField(
                          controller: labelController,
                          decoration: const InputDecoration(hintText: "Enter a label..."),
                        ),
                        const SizedBox(height: 20),
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
                        'city': tempSelection!.area ?? "Benin", // Fallback city
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
}
