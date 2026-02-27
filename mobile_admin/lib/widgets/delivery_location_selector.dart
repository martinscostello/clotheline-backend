import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:provider/provider.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
// import '../screens/user/settings/manage_addresses_screen.dart';
import 'dart:async';

class DeliveryLocationSelector extends StatefulWidget {
  final DeliveryLocationSelection? initialValue;
  final Function(DeliveryLocationSelection) onLocationSelected;
  final Function(bool)? onCollapsedStatusChanged; // New callback

  const DeliveryLocationSelector({
    super.key,
    this.initialValue,
    required this.onLocationSelected,
    this.onCollapsedStatusChanged,
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
  bool _isSaving = false;

  AreaModel? _selectedArea;
  LatLng? _customLatLng;
  String _source = 'manual';
  String _addressLabel = '';
  String? _lastCity;
  bool _isCollapsed = false; // New state

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
      } else if (_source == 'pin' || _source == 'google' || _source == 'saved') {
        _customLatLng = LatLng(widget.initialValue!.lat, widget.initialValue!.lng);
        _isCollapsed = _source == 'saved';
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
      _source = 'saved'; 
      _customLatLng = LatLng(addr.lat, addr.lng);
      _addressLabel = addr.addressLabel;
      // We store the label to show it in the summary
      _searchController.text = addr.label; 
      _suggestions = [];
      _isCollapsed = true; // Collapse on select
    });
    _notifyChange();
    widget.onCollapsedStatusChanged?.call(true);
  }

  Future<void> _saveSelection() async {
    if (_addressLabel.isEmpty || _customLatLng == null) return;
    
    setState(() => _isSaving = true);
    
    // Quick dialog for label
    final labelController = TextEditingController(text: "Home");
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Label this address"),
        content: TextField(controller: labelController, decoration: const InputDecoration(hintText: "e.g. Home, Work")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Save")),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _addressService.addAddress({
        'label': labelController.text,
        'addressLabel': _addressLabel,
        'lat': _customLatLng!.latitude,
        'lng': _customLatLng!.longitude,
        'city': _lastCity ?? (_selectedArea?.city) ?? "Abuja", 
        'landmark': _landmarkController.text,
      });

      if (success && mounted) {
        ToastUtils.show(context, "Address saved!");
        _loadSavedAddresses();
      }
    }
    setState(() => _isSaving = false);
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
    
    // If it's a saved address, we might want to prepend the label for clarity in order logs
    // but the user mostly cares about seeing the label in the UI.
    
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
    final initialPos = gmaps.LatLng(center.latitude, center.longitude);

    final result = await showGeneralDialog<gmaps.LatLng>(
      context: context,
      barrierDismissible: false,
      pageBuilder: (ctx, anim1, anim2) {
        gmaps.LatLng currentPos = initialPos;
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
                  gmaps.GoogleMap(
                    initialCameraPosition: gmaps.CameraPosition(target: initialPos, zoom: 15.0),
                    onCameraMove: (pos) => currentPos = pos.target,
                    myLocationButtonEnabled: true,
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
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
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
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
        _customLatLng = LatLng(result.latitude, result.longitude);
        _source = 'pin';
        _addressLabel = "Custom Address";
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
          _lastCity = branchCity;
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

    if (_isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: GlassContainer(
          opacity: isDark ? 0.1 : 0.05,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: const Icon(Icons.check, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Selected Location", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(_source == 'saved' ? _searchController.text : _addressLabel, 
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold), 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _isCollapsed = false);
                  widget.onCollapsedStatusChanged?.call(false);
                },
                child: const Text("Change", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Saved Addresses Section (Always Visible) ---
        const Text("Choose from Saved", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // 1. Current Saved Addresses
              ..._savedAddresses.map((addr) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  avatar: const Icon(Icons.bookmark, size: 14, color: AppTheme.primaryColor),
                  label: Text(addr.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  selected: _source == 'saved' && _addressLabel == addr.addressLabel,
                  onSelected: (_) => _selectSavedAddress(addr),
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  checkmarkColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                ),
              )).toList(),

              // 2. Dynamic Action Button (+ or Add Address)
              if (!_isLoadingSaved && _savedAddresses.length < 3)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 14, color: AppTheme.primaryColor),
                    label: Text(_savedAddresses.isEmpty ? "Manage" : "", style: const TextStyle(fontSize: 12)),
                    onPressed: () => ToastUtils.show(context, "Address management not available in Admin App", type: ToastType.info),
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text("Search for Area or Street", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),

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
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
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
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
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
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.map_outlined, color: AppTheme.primaryColor, size: 20),
                ),
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
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
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
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: TextField(
            controller: _landmarkController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: "e.g. Near the big mango tree, White House by the corner...",
              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: _onLandmarkChanged,
          ),
        ),

        if (_customLatLng != null || _addressLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_source == 'pin' || _source == 'google') ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      const Text("Location Selected", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                if (_addressLabel.isNotEmpty && (_source == 'pin' || _source == 'google') && _savedAddresses.length < 3)
                   TextButton.icon(
                    onPressed: _isSaving ? null : _saveSelection,
                    icon: _isSaving 
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 16),
                    label: const Text("Save this address", style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (_source == 'pin' || _source == 'google')
                  TextButton(
                    onPressed: () => setState(() {
                      _source = 'manual';
                      _customLatLng = null;
                      _addressLabel = _selectedArea?.name ?? '';
                      _notifyChange();
                    }),
                    child: const Text("Reset to Area", style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
              ],
            ),
          ),
      ],
    );
  }
}
