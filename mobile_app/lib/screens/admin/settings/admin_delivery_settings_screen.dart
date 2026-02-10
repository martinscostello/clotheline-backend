import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../models/branch_model.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../utils/toast_utils.dart';

class AdminDeliverySettingsScreen extends StatefulWidget {
  const AdminDeliverySettingsScreen({super.key});

  @override
  State<AdminDeliverySettingsScreen> createState() => _AdminDeliverySettingsScreenState();
}

class _AdminDeliverySettingsScreenState extends State<AdminDeliverySettingsScreen> {
  Branch? _editingBranch; // If not null, showing Editor

  @override
  void initState() {
    super.initState();
    // Refresh branches on enter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BranchProvider>(context, listen: false).fetchBranches();
    });
  }

  void _createNewBranch() {
      final nameCtrl = TextEditingController();
      final addressCtrl = TextEditingController(); 

      showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF202020),
          title: const Text("Create New Branch", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Branch Name (e.g. Benin)", labelStyle: TextStyle(color: Colors.white70)), style: const TextStyle(color: Colors.white)),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "Address", labelStyle: TextStyle(color: Colors.white70)), style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              child: const Text("Create"),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && addressCtrl.text.isNotEmpty) {
                   Navigator.pop(ctx);
                   
                   final provider = Provider.of<BranchProvider>(context, listen: false);
                   final success = await provider.createBranch({
                     "name": nameCtrl.text,
                     "address": addressCtrl.text,
                     "phone": "08000000000",
                     "location": {
                       "lat": 6.335, // Defaults, edited later in map
                       "lng": 5.603
                     },
                     "isDefault": false
                   });
                   
                   if (success && mounted) {
                      ToastUtils.show(context, "Branch Created! Tap to Edit.", type: ToastType.success);
                   }
                }
              }, 
            )
          ],
        )
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_editingBranch != null) {
      return _BranchMapEditor(
        branch: _editingBranch!,
        onClose: () => setState(() => _editingBranch = null),
      );
    }

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Delivery Centers", style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createNewBranch,
          label: const Text("Add Branch"),
          icon: const Icon(Icons.add_location_alt),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: LiquidBackground(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
            child: Consumer<BranchProvider>(
              builder: (context, provider, _) {
                if (provider.branches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         const Text("No Branches Found", style: TextStyle(color: Colors.white)),
                         const SizedBox(height: 20),
                         ElevatedButton.icon(
                           icon: const Icon(Icons.download),
                           label: const Text("Initialize Defaults (Benin/Abuja)"),
                           style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                           onPressed: () async {
                              // Call Seed Endpoint
                              // Note: We need to add seedBranches method to provider first
                              final success = await provider.seedBranches();
                              if (!mounted) return;
                              if (success) {
                                ToastUtils.show(context, "Branches Initialized!", type: ToastType.success);
                              } else {
                                 ToastUtils.show(context, "Failed to Initialize. Check Connection.", type: ToastType.error);
                              }
                           }
                         ),
                         const SizedBox(height: 10),
                         TextButton(
                           child: const Text("Refresh List"),
                           onPressed: () => provider.fetchBranches(force: true),
                         )
                      ],
                    )
                  );
                }
                return ListView.separated(
                  itemCount: provider.branches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 15),
                  itemBuilder: (ctx, index) {
                    final branch = provider.branches[index];
                    return GlassContainer(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        title: Text(branch.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text(branch.address, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 5),
                            Text("Lat: ${branch.location.latitude} | Lng: ${branch.location.longitude}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.edit, color: Colors.white),
                        ),
                        onTap: () {
                          setState(() => _editingBranch = branch);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// --- DETAIL EDITOR ---

class _BranchMapEditor extends StatefulWidget {
  final Branch branch;
  final VoidCallback onClose;

  const _BranchMapEditor({required this.branch, required this.onClose});

  @override
  State<_BranchMapEditor> createState() => _BranchMapEditorState();
}

class _BranchMapEditorState extends State<_BranchMapEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isEditLocationEnabled = false; // [FIX] Mistap protection
  gmaps.MapType _activeMapType = gmaps.MapType.normal; // [NEW] Map view types
  
  List<DeliveryZone> _zones = [];

  final List<Color> _zoneColors = [
    const Color(0xFF2ECC71),
    const Color(0xFFF1C40F),
    const Color(0xFFE67E22),
    const Color(0xFFE74C3C),
    const Color(0xFF9E9E9E),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.branch.name);
    _addressCtrl = TextEditingController(text: widget.branch.address);
    _phoneCtrl = TextEditingController(text: widget.branch.phone);
    _latCtrl = TextEditingController(text: widget.branch.location.latitude.toString());
    _lngCtrl = TextEditingController(text: widget.branch.location.longitude.toString());
    
    _initializeZones();
    
    void markDirty() {
      if (!_isDirty) setState(() => _isDirty = true);
    }
    _nameCtrl.addListener(markDirty);
    _addressCtrl.addListener(markDirty);
    _phoneCtrl.addListener(markDirty);
    _latCtrl.addListener(markDirty);
    _lngCtrl.addListener(markDirty);
  }
  
  void _initializeZones() {
    _zones = List.from(widget.branch.deliveryZones);
    
    // Sort logic to identify existing zones by radius
    _zones.sort((a, b) => a.radiusKm.compareTo(b.radiusKm));

    if (_zones.isEmpty) {
      _zones.add(DeliveryZone(name: "Zone A", description: "0 - 5.0 km", radiusKm: 5.0, baseFee: 500, color: '#2ECC71'));
    }
    
    // Force descriptions to align with ranges initially
    _recalculateDescriptions();
  }

  void _recalculateDescriptions() {
    for (int i = 0; i < _zones.length; i++) {
        double start = (i == 0) ? 0 : _zones[i-1].radiusKm;
        double end = _zones[i].radiusKm;
        
        String desc = "${start.toStringAsFixed(1)} - ${end.toStringAsFixed(1)} km";
        
        // Update keeping other props
        _zones[i] = DeliveryZone(
          name: _zones[i].name,
          description: desc,
          radiusKm: end,
          baseFee: _zones[i].baseFee,
          color: _zones[i].color
        );
    }
  }

  // Helper: Start of a zone is End of previous
  double _getStartDistance(int index) => (index == 0) ? 0 : _zones[index - 1].radiusKm;

  void _updateZoneRadius(int index, String val) {
    final double? newRadius = double.tryParse(val);
    if (newRadius == null) return;
    
    final start = _getStartDistance(index);
    // Strict Validation: Cannot be less than start. 
    if (newRadius <= start) return; // Prevent collapse

    setState(() {
      _isDirty = true;
      
      // Update this zone
      _zones[index] = DeliveryZone(
        name: _zones[index].name,
        description: "", // Will recalc
        radiusKm: newRadius,
        baseFee: _zones[index].baseFee,
        color: _zones[index].color
      );
      
      // Cascade push: Ensure next zones are strictly greater
      for (int i = index + 1; i < _zones.length; i++) { 
         if (_zones[i].radiusKm <= _zones[i-1].radiusKm + 0.5) {
             _zones[i] = DeliveryZone(
               name: _zones[i].name, description: "", 
               radiusKm: _zones[i-1].radiusKm + 1.0, // Push out by at least 1km
               baseFee: _zones[i].baseFee, color: _zones[i].color
             );
         }
      }
      
      _recalculateDescriptions();
    });
  }

  void _updateZoneFee(int index, String val) {
    final double? newFee = double.tryParse(val);
    if (newFee == null) return;
    
    // Only mark dirty if actually changed
    if (_zones[index].baseFee != newFee) {
      setState(() {
         _isDirty = true;
         _zones[index] = DeliveryZone(
           name: _zones[index].name,
           description: _zones[index].description, 
           radiusKm: _zones[index].radiusKm, 
           baseFee: newFee,
           color: _zones[index].color
         );
      });
    }
  }

  void _addZone() {
    setState(() {
      _isDirty = true;
      double lastRadius = _zones.isEmpty ? 0 : _zones.last.radiusKm;
      
      final nextColor = _zoneColors[_zones.length % _zoneColors.length];
      final colorHex = '#${nextColor.value.toRadixString(16).substring(2).toUpperCase()}';

      _zones.add(DeliveryZone(
        name: "Zone ${String.fromCharCode(65 + _zones.length)}",
        description: "",
        radiusKm: lastRadius + 5.0,
        baseFee: 1000,
        color: colorHex,
      ));
      _recalculateDescriptions();
    });
  }

  void _removeZone(int index) {
    if (_zones.length <= 1) return;
    setState(() {
      _isDirty = true;
      _zones.removeAt(index);
      _recalculateDescriptions();
    });
  }

  Future<void> _saveChanges() async {
    if (!_isDirty) return; 

    final double? lat = double.tryParse(_latCtrl.text);
    final double? lng = double.tryParse(_lngCtrl.text);

    if (lat == null || lng == null) {
       ToastUtils.show(context, "Invalid Coordinates", type: ToastType.error);
       return;
    }

    setState(() => _isSaving = true);
    
    // Strict Serialization: Send all zones properties clearly
    final zonesData = _zones.map((z) => {
      'name': z.name,
      'description': z.description,
      'radiusKm': z.radiusKm,
      'baseFee': z.baseFee, 
      'color': z.color
    }).toList();

    try {
      final provider = Provider.of<BranchProvider>(context, listen: false);
      final result = await provider.updateBranch(widget.branch.id, {
        'name': _nameCtrl.text,
        'address': _addressCtrl.text,
        'phone': _phoneCtrl.text,
        'location': {'lat': lat, 'lng': lng},
        'deliveryZones': zonesData
      });

      setState(() => _isSaving = false);
      
      if (result['success'] == true) {
        setState(() { _isDirty = false; _isEditLocationEnabled = false; }); // Clear dirty flag on success
        if (mounted) {
           ToastUtils.show(context, "Delivery zones updated successfully", type: ToastType.success);
        }
      } else {
         final msg = result['message'] ?? "Failed to save changes.";
         if (mounted) ToastUtils.show(context, msg, type: ToastType.error);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ToastUtils.show(context, "Error: $e", type: ToastType.error);
    }
  }
  
  void _expandMap() {
    final lat = double.tryParse(_latCtrl.text) ?? widget.branch.location.latitude;
    final lng = double.tryParse(_lngCtrl.text) ?? widget.branch.location.longitude;
    final center = gmaps.LatLng(lat, lng);

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  gmaps.GoogleMap(
                    initialCameraPosition: gmaps.CameraPosition(target: center, zoom: 15),
                    mapType: _activeMapType,
                    onTap: (point) {
                      _onMapTap(point);
                      setDialogState(() {}); // Refresh dialog markers
                    },
                    myLocationButtonEnabled: true,
                    myLocationEnabled: true,
                    zoomControlsEnabled: true,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                    },
                    circles: List.generate(_zones.length, (idx) {
                      final z = _zones[idx];
                      final color = Color(int.parse(z.color.replaceAll('#', '0xFF')));
                      return gmaps.Circle(
                        circleId: gmaps.CircleId(z.name + idx.toString()),
                        center: center,
                        radius: z.radiusKm * 1000,
                        fillColor: color.withOpacity(0.15),
                        strokeColor: color,
                        strokeWidth: 2,
                      );
                    }).reversed.toSet(),
                    markers: {
                      gmaps.Marker(markerId: const gmaps.MarkerId('branch'), position: center, icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure)),
                    },
                  ),

                  // Close Button
                  Positioned(
                    top: 50, left: 20,
                    child: _mapControlBtn(Icons.close, () => Navigator.pop(context), isActive: true),
                  ),

                  // Map Controls
                  Positioned(
                    top: 50, right: 20,
                    child: Column(
                      children: [
                        _mapControlBtn(Icons.layers_outlined, () {
                          _showViewSelector();
                          setDialogState(() {});
                        }),
                        const SizedBox(height: 10),
                        _mapControlBtn(Icons.streetview, _launchStreetView),
                      ],
                    ),
                  ),
                  
                  // Edit Mode Toggle
                  Positioned(
                    bottom: 40, left: 20, right: 20,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _isEditLocationEnabled = !_isEditLocationEnabled);
                          setDialogState(() {});
                        },
                        child: _editLocationToggle(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _launchStreetView() async {
    final lat = double.tryParse(_latCtrl.text) ?? widget.branch.location.latitude;
    final lng = double.tryParse(_lngCtrl.text) ?? widget.branch.location.longitude;
    final url = 'google.streetview:cbll=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      final webUrl = 'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng';
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    }
  }

  void _onMapTap(gmaps.LatLng point) {
    if (!_isEditLocationEnabled) return; // [FIX] Lock movements
    _latCtrl.text = point.latitude.toStringAsFixed(6);
    _lngCtrl.text = point.longitude.toStringAsFixed(6);
    setState(() => _isDirty = true); 
  }

  void _showViewSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Map View Type", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            _viewOption("Normal", gmaps.MapType.normal, Icons.map_outlined),
            _viewOption("Satellite", gmaps.MapType.satellite, Icons.satellite_alt_outlined),
            _viewOption("Hybrid", gmaps.MapType.hybrid, Icons.layers_outlined),
            _viewOption("Terrain", gmaps.MapType.terrain, Icons.terrain_outlined),
          ],
        ),
      ),
    );
  }

  Widget _viewOption(String label, gmaps.MapType type, IconData icon) {
    final isSelected = _activeMapType == type;
    return _listAction(
      label: label, icon: icon, color: isSelected ? AppTheme.primaryColor : Colors.white70,
      onTap: () {
        setState(() => _activeMapType = type);
        Navigator.pop(context);
      },
    );
  }

  Widget _mapControlBtn(IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: isActive ? AppTheme.primaryColor : Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)]),
        child: Icon(icon, color: isActive ? Colors.black : Colors.black87),
      ),
    );
  }

  Widget _editLocationToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isEditLocationEnabled = !_isEditLocationEnabled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: _isEditLocationEnabled ? Colors.blue : Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(30), border: Border.all(color: _isEditLocationEnabled ? Colors.white38 : Colors.white12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_isEditLocationEnabled ? Icons.location_on : Icons.location_off, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(_isEditLocationEnabled ? "CLICK MAP TO MOVE" : "LOCATION LOCKED (TAP TO EDIT)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(_latCtrl.text) ?? widget.branch.location.latitude;
    final lng = double.tryParse(_lngCtrl.text) ?? widget.branch.location.longitude;
    final center = gmaps.LatLng(lat, lng);

    return Theme(
      data: AppTheme.darkTheme,
      child: PopScope(
        canPop: !_isDirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              title: const Text("Unsaved Changes", style: TextStyle(color: Colors.white)),
              content: const Text("You have unsaved changes. Discard them?", style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Stay")),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Discard", style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (shouldPop == true && context.mounted) Navigator.pop(context);
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () {
              if (_isDirty) {
                ToastUtils.show(context, "Please save or discard changes.", type: ToastType.info);
              } else {
                widget.onClose();
              }
            }),
            title: Text("Edit ${widget.branch.name}", style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: (_isDirty && !_isSaving) ? _saveChanges : null,
                  icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, color: Colors.white),
                  label: Text(_isSaving ? "Saving..." : "Save", style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: _isDirty ? Colors.blue : Colors.grey.withOpacity(0.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                ),
              )
            ],
          ),
          body: LiquidBackground(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  
                  // --- GOOGLE MAP SECTION ---
                  SizedBox(
                    height: 400,
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white12), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15)]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Stack(
                          children: [
                            gmaps.GoogleMap(
                              initialCameraPosition: gmaps.CameraPosition(target: center, zoom: 12),
                              mapType: _activeMapType,
                              onMapCreated: (c) => {}, 
                              onTap: _onMapTap,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              gestureRecognizers: {
                                Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                              },
                              circles: List.generate(_zones.length, (idx) {
                                final z = _zones[idx];
                                final color = Color(int.parse(z.color.replaceAll('#', '0xFF')));
                                return gmaps.Circle(
                                  circleId: gmaps.CircleId(z.name + idx.toString()),
                                  center: center,
                                  radius: z.radiusKm * 1000,
                                  fillColor: color.withOpacity(0.15),
                                  strokeColor: color,
                                  strokeWidth: 2,
                                );
                              }).reversed.toSet(),
                              markers: {
                                gmaps.Marker(markerId: const gmaps.MarkerId('branch'), position: center, icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure)),
                              },
                            ),

                            // Map Controls
                            Positioned(
                              top: 20, right: 20,
                              child: Column(
                                children: [
                                  _mapControlBtn(Icons.layers_outlined, () => _showViewSelector()),
                                  const SizedBox(height: 10),
                                  _mapControlBtn(Icons.streetview, _launchStreetView),
                                  const SizedBox(height: 10),
                                  _mapControlBtn(Icons.fullscreen, _expandMap),
                                ],
                              ),
                            ),
                            
                            // Edit Mode Toggle
                            Positioned(
                              bottom: 20, left: 20, right: 20,
                              child: Center(
                                child: _editLocationToggle(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- DETAILS EDITOR ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GlassContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Branch Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _buildInput("Address", _addressCtrl),
                          const SizedBox(height: 10),
                          _buildInput("Phone", _phoneCtrl),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // --- ZONE EDITOR ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Delivery Zones", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            TextButton.icon(
                              onPressed: _addZone,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text("Add Zone"),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.secondaryColor),
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(_zones.length, (i) => _buildZoneCard(i, _zones[i])),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Define _listAction inline since it might be missing
  Widget _listAction({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
     return TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
     );
  }

  Widget _buildZoneCard(int index, DeliveryZone z) {
     final Color color = _zoneColors[index % _zoneColors.length];
     final startKm = _getStartDistance(index);
     
     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))),
       padding: const EdgeInsets.all(12),
       child: Column(
         children: [
           Row(
             children: [
               Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
               const SizedBox(width: 10),
               Expanded(child: Text(z.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))),
               const Text("Ends:", style: TextStyle(color: Colors.white54, fontSize: 12)),
               const SizedBox(width: 5),
               SizedBox(
                 width: 50,
                 child: TextFormField(
                   key: ValueKey("radius_${z.radiusKm}_$index"),
                   initialValue: z.radiusKm.toString(),
                   keyboardType: TextInputType.number,
                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                   textAlign: TextAlign.center,
                   decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4), border: InputBorder.none),
                   onChanged: (val) => _updateZoneRadius(index, val),
                 ),
               ),
               const Text("km", style: TextStyle(color: Colors.white54, fontSize: 12)),
               if (_zones.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _removeZone(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
             ],
           ),
           const Divider(color: Colors.white10),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                Text("${startKm.toStringAsFixed(1)} - ${z.radiusKm.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(
                  width: 100,
                  child: TextField(
                    decoration: InputDecoration(prefixText: "N ", prefixStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.black26, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: z.baseFee.toStringAsFixed(0))..selection = TextSelection.collapsed(offset: z.baseFee.toStringAsFixed(0).length),
                    onChanged: (val) => _updateZoneFee(index, val),
                  ),
                )
             ],
           )
         ],
       ),
     );
  }
}
