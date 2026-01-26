import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/delivery_location_model.dart';
import '../data/areas_data.dart';
import '../theme/app_theme.dart';
import '../providers/branch_provider.dart';
import 'glass/GlassContainer.dart';
import '../services/location_search_service.dart';
import '../services/address_service.dart';
import 'dart:async';

class DeliveryLocationSelector extends StatefulWidget {
  final DeliveryLocationSelection? initialValue;
  final Function(DeliveryLocationSelection) onLocationSelected;

  const DeliveryLocationSelector({
    super.key,
    this.initialValue,
    required this.onLocationSelected,
  });

  @override
  State<DeliveryLocationSelector> createState() => _DeliveryLocationSelectorState();
}

class _DeliveryLocationSelectorState extends State<DeliveryLocationSelector> {
  late TextEditingController _landmarkController;
  late TextEditingController _searchController;
  
  final LocationSearchService _searchService = LocationSearchService();
  final AddressService _addressService = AddressService();
  
  List<GranularLocation> _suggestions = [];
  List<SavedAddress> _savedAddresses = [];
  Timer? _debounceTimer;
  bool _isLoadingSaved = true;

  AreaModel? _selectedArea;
  LatLng? _customLatLng;
  String _source = 'manual';
  String _addressLabel = '';

  @override
  void initState() {
    super.initState();
    _landmarkController = TextEditingController(text: widget.initialValue?.landmark);
    _searchController = TextEditingController();
    
    if (widget.initialValue != null) {
      _source = widget.initialValue!.source;
      _addressLabel = widget.initialValue!.addressLabel;
      if (_source == 'manual' && widget.initialValue!.area != null) {
        _selectedArea = nigeriaAreas.firstWhere(
          (a) => a.name == widget.initialValue!.area,
          orElse: () => nigeriaAreas.first,
        );
      } else if (_source == 'pin' || _source == 'google') {
        _customLatLng = LatLng(widget.initialValue!.lat, widget.initialValue!.lng);
      }
    }
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    final addresses = await _addressService.getSavedAddresses();
    if (mounted) {
      setState(() {
        _savedAddresses = addresses;
        _isLoadingSaved = false;
      });
    }
  }

  void _selectSavedAddress(SavedAddress addr) {
    setState(() {
      _source = 'manual'; // Treat as preset manual to allow fee calculation via coords
      _customLatLng = LatLng(addr.lat, addr.lng);
      _addressLabel = addr.addressLabel;
      _landmarkController.text = addr.landmark ?? '';
      _searchController.text = addr.addressLabel;
      _suggestions = [];
    });
    _notifyChange();
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onAreaChanged(AreaModel? area) {
    if (area == null) return;
    setState(() {
      _selectedArea = area;
      _source = 'manual';
      _customLatLng = null;
      _addressLabel = area.name;
    });
    _notifyChange();
  }

  void _onLandmarkChanged(String val) {
    _notifyChange();
  }

  void _notifyChange() {
    final lat = _customLatLng?.latitude ?? _selectedArea?.centroid.latitude ?? 0.0;
    final lng = _customLatLng?.longitude ?? _selectedArea?.centroid.longitude ?? 0.0;
    
    String label = _addressLabel;
    if (_landmarkController.text.isNotEmpty) {
      label += " (Near ${_landmarkController.text})";
    }

    widget.onLocationSelected(DeliveryLocationSelection(
      lat: lat,
      lng: lng,
      addressLabel: label,
      source: _source,
      area: _selectedArea?.name,
      landmark: _landmarkController.text,
    ));
  }

  Future<void> _pickOnMap() async {
    final branch = Provider.of<BranchProvider>(context, listen: false).selectedBranch;
    final center = _customLatLng ?? _selectedArea?.centroid ?? LatLng(branch?.location.lat ?? 6.33, branch?.location.lng ?? 5.60);

    final result = await showGeneralDialog<LatLng>(
      context: context,
      barrierDismissible: false,
      pageBuilder: (ctx, anim1, anim2) {
        LatLng currentPos = center;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              appBar: AppBar(
                title: const Text("Pick Delivery Location"),
                backgroundColor: AppTheme.primaryColor,
                leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, currentPos),
                    child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              body: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15.0,
                      onPositionChanged: (pos, hasGesture) {
                        if (hasGesture) {
                          currentPos = pos.center!;
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.clotheline.app',
                      ),
                    ],
                  ),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.location_pin, color: AppTheme.primaryColor, size: 50),
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: 20, right: 20,
                    child: GlassContainer(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          "Drag the map to position the pin exactly where you want us to deliver.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );

    if (result != null) {
      setState(() {
        _customLatLng = result;
        _source = 'pin';
        _addressLabel = "Dropped Pin at ${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}";
      });
      _notifyChange();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (query.isEmpty) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }

      final branch = Provider.of<BranchProvider>(context, listen: false).selectedBranch;
      final branchCity = branch?.name.contains("Benin") == true ? "Benin" : (branch?.name.contains("Abuja") == true ? "Abuja" : null);

      final results = await _searchService.getAutocomplete(query, branchCity);
      
      if (mounted) {
        setState(() {
          // Take exactly 3 results as requested
          _suggestions = results.take(3).toList();
        });
      }
    });
  }

  void _selectSuggestion(GranularLocation loc) async {
    // Show loading?
    final LatLng? coords = await _searchService.getPlaceDetails(loc.placeId);
    
    if (coords != null && mounted) {
      setState(() {
        _source = 'google';
        _customLatLng = coords;
        _addressLabel = loc.description;
        _searchController.text = loc.description;
        _suggestions = [];
      });
      _notifyChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Saved Addresses Quick-Select ---
        if (!_isLoadingSaved && _savedAddresses.isNotEmpty) ...[
          const Text("Saved Addresses", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _savedAddresses.length,
              itemBuilder: (context, index) {
                final addr = _savedAddresses[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.bookmark, size: 14, color: AppTheme.primaryColor),
                    label: Text(addr.label, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _selectSavedAddress(addr),
                    backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // --- Suggestions List Appearing ABOVE the textfield ---
        if (_suggestions.isNotEmpty)
          Container(
            key: const ValueKey('location_suggestions_list'), // Added Key
            margin: const EdgeInsets.only(bottom: 8),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
              itemBuilder: (context, index) {
                final loc = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on, size: 18, color: AppTheme.primaryColor),
                  title: Text(loc.mainText ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  subtitle: Text(loc.secondaryText ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  onTap: () => _selectSuggestion(loc),
                );
              },
            ),
          ),

        // 1. Selector Type / Search 
        Container(
          key: const ValueKey('search_field_container'), // Added Key
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: "Type to search nearby areas...",
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.map, color: AppTheme.primaryColor),
                onPressed: _pickOnMap,
                tooltip: "Pick on Map",
              )
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Manual Area Dropdown
        const Text("Select Area (Local Selection)", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Consumer<BranchProvider>(
            builder: (context, branchProvider, _) {
              final branch = branchProvider.selectedBranch;
              final branchCity = branch?.name.contains("Benin") == true ? "Benin" : (branch?.name.contains("Abuja") == true ? "Abuja" : null);
              
              final filteredAreas = nigeriaAreas.where((a) => branchCity == null || a.city == branchCity).toList();

              return DropdownButtonHideUnderline(
                child: DropdownButton<AreaModel>(
                  isExpanded: true,
                  value: _selectedArea != null && filteredAreas.contains(_selectedArea) ? _selectedArea : null,
                  hint: const Text("Choose Area", style: TextStyle(fontSize: 13)),
                  items: filteredAreas.map((area) {
                    return DropdownMenuItem<AreaModel>(
                      value: area,
                      child: Text(area.name, style: TextStyle(color: textColor, fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: _onAreaChanged,
                ),
              );
            }
          ),
        ),
        const SizedBox(height: 12),

        // 3. Landmark Input
        const Text("Landmark / Directions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: TextField(
            controller: _landmarkController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: "e.g. Near the big mango tree, White House by the corner...",
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: _onLandmarkChanged,
          ),
        ),

        if (_source == 'pin')
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                const Text("Using exact location from map pin", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _source = 'manual';
                    _customLatLng = null;
                    _addressLabel = _selectedArea?.name ?? '';
                    _notifyChange();
                  }),
                  child: const Text("Reset to Area", style: TextStyle(fontSize: 12)),
                )
              ],
            ),
          ),
      ],
    );
  }
}
