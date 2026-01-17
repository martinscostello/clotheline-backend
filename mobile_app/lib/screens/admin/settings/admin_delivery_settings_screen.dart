import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../../providers/branch_provider.dart';
import '../../../../models/branch_model.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';

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
      final addressCtrl = TextEditingController(); // Assuming prompt logic similar to before
      final latCtrl = TextEditingController(text: "6.335");
      final lngCtrl = TextEditingController(text: "5.603");

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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Branch Created! Tap to Edit.")));
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

    return Scaffold(
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
                            if (success) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Branches Initialized!")));
                            } else {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to Initialize. Check Connection.")));
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
    );
  }
}

// --- DETAIL EDITOR ---

class _BranchMapEditor extends StatefulWidget {
  final Branch branch;
  final VoidCallback onClose;

  const _BranchMapEditor({super.key, required this.branch, required this.onClose});

  @override
  State<_BranchMapEditor> createState() => _BranchMapEditorState();
}

class _BranchMapEditorState extends State<_BranchMapEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  
  final MapController _mapController = MapController();
  bool _isSaving = false;
  bool _isDirty = false; // Tracks if any changes have been made
  
  // Strict: Always 5 Zones internally (A, B, C, D, E). 
  // We only render/edit A-D. E is inclusive of everything beyond D.
  List<DeliveryZone> _zones = [];

  // Strict Color Mapping
  final List<Color> _zoneColors = [
    const Color(0xFF2ECC71), // Zone A - Green
    const Color(0xFFF1C40F), // Zone B - Yellow
    const Color(0xFFE67E22), // Zone C - Orange
    const Color(0xFFE74C3C), // Zone D - Red
    const Color(0xFF9E9E9E), // Zone E - Grey (Implicit)
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
    
    // Listen to text changes to mark as dirty
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
    List<DeliveryZone> source = List.from(widget.branch.deliveryZones);
    
    // Sort logic to identify existing zones by radius
    source.sort((a, b) => a.radiusKm.compareTo(b.radiusKm));

    // Ensure we have exactly 5 zones suitable for A-E logic
    List<DeliveryZone> normalized = [];
    
    // Helper to get or default
    DeliveryZone getOrDefault(int index, String name, double r, double fee, String colorHex) {
       if (index < source.length) {
         // Force the correct name and color, but keep radius/fee if reasonable
         var s = source[index];
         return DeliveryZone(name: name, description: s.description, radiusKm: s.radiusKm, baseFee: s.baseFee, color: colorHex);
       }
       return DeliveryZone(name: name, description: "", radiusKm: r, baseFee: fee, color: colorHex);
    }

    normalized.add(getOrDefault(0, "Zone A: Immediate Coverage", 2.5, 500, '#2ECC71'));
    normalized.add(getOrDefault(1, "Zone B: Core City", 5.5, 1000, '#F1C40F'));
    normalized.add(getOrDefault(2, "Zone C: Extended City", 9.0, 2000, '#E67E22'));
    normalized.add(getOrDefault(3, "Zone D: Outskirts", 14.0, 3000, '#E74C3C'));
    normalized.add(getOrDefault(4, "Zone E: Outside Service Area", 9999, 99999, '#9E9E9E'));

    _zones = normalized;
    
    // Force descriptions to align with ranges initially
    _recalculateDescriptions();
  }

  void _recalculateDescriptions() {
    for (int i = 0; i < _zones.length; i++) {
        double start = (i == 0) ? 0 : _zones[i-1].radiusKm;
        double end = _zones[i].radiusKm;
        
        String desc;
        if (i == _zones.length - 1) {
           desc = "> $start km (Out of Service)";
        } else {
           desc = "${start.toStringAsFixed(1)} - ${end.toStringAsFixed(1)} km";
        }
        
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
  double _getStartDistance(int index) {
    if (index == 0) return 0;
    return _zones[index - 1].radiusKm;
  }

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
      for (int i = index + 1; i < _zones.length - 1; i++) { // Don't push Zone E (9999)
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

  Future<void> _saveChanges() async {
    if (!_isDirty) return; 

    final double? lat = double.tryParse(_latCtrl.text);
    final double? lng = double.tryParse(_lngCtrl.text);

    if (lat == null || lng == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Coordinates")));
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
        setState(() => _isDirty = false); // Clear dirty flag on success
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text("Delivery zones updated successfully"), 
               backgroundColor: Colors.green
             )
           );
        }
      } else {
         final msg = result['message'] ?? "Failed to save changes.";
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
  
  void _expandMap() {
    final lat = double.tryParse(_latCtrl.text) ?? widget.branch.location.latitude;
    final lng = double.tryParse(_lngCtrl.text) ?? widget.branch.location.longitude;
    final center = LatLng(lat, lng);
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12.0,
                onTap: (pos, point) {
                  _latCtrl.text = point.latitude.toStringAsFixed(6);
                  _lngCtrl.text = point.longitude.toStringAsFixed(6);
                  setState(() => _isDirty = true);
                },
              ),
              children: [
                 TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.clotheline.app'),
                 CircleLayer(
                    // Render A-D rings. 
                    circles: _zones.getRange(0, 4).toList().reversed.map((z) {
                       int idx = _zones.indexOf(z);
                       return CircleMarker(
                        point: LatLng(double.parse(_latCtrl.text), double.parse(_lngCtrl.text)),
                        color: _zoneColors[idx].withValues(alpha: 0.15),
                        useRadiusInMeter: true,
                        radius: z.radiusKm * 1000,
                        borderColor: _zoneColors[idx],
                        borderStrokeWidth: 2
                      );
                    }).toList(),
                 ),
                 MarkerLayer(markers: [Marker(point: LatLng(double.parse(_latCtrl.text), double.parse(_lngCtrl.text)), width: 80, height: 80, child: const Icon(Icons.location_pin, color: Colors.white, size: 40))]),
              ],
            ),
            Positioned(
               top: 40, left: 20,
               child: IconButton(icon: const Icon(Icons.close, color: Colors.black, size: 30), onPressed: () => Navigator.pop(ctx)),
            ),
            Positioned(
              bottom: 40, left: 20, right: 20,
              child: GlassContainer(child: const Text("Tap anywhere to move Delivery Center", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
            )
          ],
        ),
      )
    ).then((_) => setState((){})); 
  }

  void _onMapTap(TapPosition pos, LatLng point) {
    _latCtrl.text = point.latitude.toStringAsFixed(6);
    _lngCtrl.text = point.longitude.toStringAsFixed(6);
    setState(() => _isDirty = true); 
  }

  Color _parseColor(String s) {
    try {
      final hex = s.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(_latCtrl.text) ?? widget.branch.location.latitude;
    final lng = double.tryParse(_lngCtrl.text) ?? widget.branch.location.longitude;
    final center = LatLng(lat, lng);

    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Unsaved Changes"),
            content: const Text("You have unsaved changes. Convert them to reality?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Stay")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Discard")),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
           Navigator.pop(context);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () {
            if (_isDirty) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please save or discard changes.")));
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
                // Logic: Enabled only if dirty and not saving
                onPressed: (_isDirty && !_isSaving) ? _saveChanges : null,
                icon: _isSaving 
                   ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                   : const Icon(Icons.save, color: Colors.white),
                label: Text(_isSaving ? "Saving..." : "Save", style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                   backgroundColor: _isDirty ? Colors.blue : Colors.grey.withValues(alpha: 0.5),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                ),
              ),
            )
          ],
        ),
        body: LiquidBackground(
          child: Row( 
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      
                      // --- MAP SECTION ---
                      SizedBox(
                        height: 300,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                            boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)]
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    initialCenter: center,
                                    initialZoom: 11.0,
                                    onTap: _onMapTap,
                                  ),
                                  children: [
                                     TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.clotheline.app',
                                    ),
                                    CircleLayer(
                                      // Render A-D rings only.
                                      circles: _zones.getRange(0, 4).toList().reversed.map((z) {
                                         // Find index for color
                                         int idx = _zones.indexOf(z);
                                         return CircleMarker(
                                          point: center,
                                          color: _zoneColors[idx].withValues(alpha: 0.15),
                                          useRadiusInMeter: true,
                                          radius: z.radiusKm * 1000, 
                                          borderColor: _zoneColors[idx],
                                          borderStrokeWidth: 2
                                        );
                                      }).toList(),
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(point: center, width: 80, height: 80, child: const Icon(Icons.location_pin, color: Colors.white, size: 40)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 10, right: 10,
                                child: FloatingActionButton.small(
                                  backgroundColor: Colors.white,
                                  child: const Icon(Icons.fullscreen, color: Colors.black),
                                  onPressed: _expandMap,
                                )
                              )
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),

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
                            const Text("Delivery Zones (Zones A - D)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 10),
                            // STRICT: Only render exactly 4 zones (Index 0, 1, 2, 3)
                            ...[0, 1, 2, 3].map((i) {
                               return _buildZoneCard(i, _zones[i]);
                            }).toList(),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
     if (index >= _zoneColors.length) return const SizedBox();
     
     final Color color = _zoneColors[index];
     final startKm = _getStartDistance(index);
     
     return Container(
       margin: const EdgeInsets.only(bottom: 12),
       decoration: BoxDecoration(
         color: color.withValues(alpha:0.1),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: color.withValues(alpha:0.5)),
       ),
       padding: const EdgeInsets.all(12),
       child: Column(
         children: [
           Row(
             children: [
               Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
               const SizedBox(width: 10),
               Expanded(
                 child: Text(z.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16))
               ),
               
               const Text("Ends:", style: TextStyle(color: Colors.white54, fontSize: 12)),
               const SizedBox(width: 5),
               SizedBox(
                 width: 50,
                 child: TextFormField(
                   // Key ensures rebuild when calculated value changes
                   key: ValueKey("radius_${z.radiusKm}"),
                   initialValue: z.radiusKm.toString(),
                   keyboardType: TextInputType.number,
                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                   textAlign: TextAlign.center,
                   decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4), border: InputBorder.none),
                   onChanged: (val) => _updateZoneRadius(index, val),
                 ),
               ),
               const Text("km", style: TextStyle(color: Colors.white54, fontSize: 12)),
             ],
           ),
           const Divider(color: Colors.white10),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                Text(
                  "${startKm.toStringAsFixed(1)} - ${z.radiusKm.toStringAsFixed(1)} km",
                  style: const TextStyle(color: Colors.white70, fontSize: 13)
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    decoration: InputDecoration(
                       prefixText: "N ", 
                       prefixStyle: const TextStyle(color: Colors.white54),
                       filled: true, 
                       fillColor: Colors.black26,
                       isDense: true,
                       contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
                    ),
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
