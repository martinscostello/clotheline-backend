import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/delivery_service.dart';
import '../../../widgets/glass/LiquidBackground.dart';
import '../../../widgets/glass/GlassContainer.dart';
import '../../../theme/app_theme.dart';

class AdminDeliverySettingsScreen extends StatefulWidget {
  const AdminDeliverySettingsScreen({super.key});

  @override
  State<AdminDeliverySettingsScreen> createState() => _AdminDeliverySettingsScreenState();
}

class _AdminDeliverySettingsScreenState extends State<AdminDeliverySettingsScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = true;

  bool _isMapExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    await Provider.of<DeliveryService>(context, listen: false).fetchSettings();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final deliveryService = Provider.of<DeliveryService>(context);
    final settings = deliveryService.settings;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }
    
    if (settings == null) {
       return Scaffold(
         extendBodyBehindAppBar: true,
         appBar: AppBar(
            title: const Text("Delivery Settings", style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent, 
            iconTheme: const IconThemeData(color: Colors.white),
         ),
         body: LiquidBackground(
           child: Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 const Icon(Icons.error_outline, color: Colors.white54, size: 60),
                 const SizedBox(height: 20),
                 const Text("Failed to load settings", style: TextStyle(color: Colors.white, fontSize: 18)),
                 const SizedBox(height: 20),
                 ElevatedButton(
                   onPressed: () { 
                      setState(() => _isLoading = true);
                      _fetchData(); 
                   },
                   child: const Text("Retry"),
                 )
               ],
             ),
           ),
         ),
       );
    }

    final laundryLoc = settings['laundryLocation'];
    final LatLng laundryLatLng = LatLng(laundryLoc['lat'], laundryLoc['lng']);
    
    // Sort zones by radius for correct Band Logic (A -> B -> C -> D)
    final List<dynamic> rawZones = settings['zones'] ?? [];
    final List<Map<String, dynamic>> zones = List<Map<String, dynamic>>.from(rawZones);
    zones.sort((a, b) => (a['radiusKm'] as num).compareTo(b['radiusKm'] as num));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _isMapExpanded ? const SizedBox() : const Text("Delivery Zones & Fees", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isMapExpanded) ...[
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.orangeAccent),
              tooltip: 'Reset to Defaults',
              onPressed: () => _confirmReset(context, deliveryService),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _fetchData(),
            )
          ]
        ],
      ),
      body: LiquidBackground(
        child: Column(
          children: [
            // MAP VIEW
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isMapExpanded ? MediaQuery.of(context).size.height : MediaQuery.of(context).size.height * 0.45,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: laundryLatLng,
                      initialZoom: 11.5,
                      minZoom: 10,
                      maxZoom: 15,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.antigravity.clotheline.admin', 
                        tileProvider: NetworkTileProvider(),
                      ),
                      // Render Zones as Circles (Painter's Algo: Draw Largest First)
                      CircleLayer(
                        circles: () {
                          // Reverse sort for drawing (D -> C -> B -> A)
                          final drawZones = List<Map<String, dynamic>>.from(zones);
                          drawZones.sort((a, b) => (b['radiusKm'] as num).compareTo(a['radiusKm'] as num));

                          return drawZones.map<CircleMarker>((zone) {
                             Color color = _parseColor(zone['color']);
                             return CircleMarker(
                               point: laundryLatLng,
                               color: color.withOpacity(0.25), 
                               borderColor: color,
                               borderStrokeWidth: 2,
                               radius: (zone['radiusKm'] as num).toDouble() * 1000, 
                               useRadiusInMeter: true,
                             );
                          }).toList();
                        }(),
                      ),
                      // Laundry Marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: laundryLatLng,
                            width: 50,
                            height: 50,
                            child: const Column(
                              children: [
                                Icon(Icons.store, color: Colors.redAccent, size: 35),
                                Text("HQ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10))
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Expand/Collapse Button
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isMapExpanded = !_isMapExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isMapExpanded ? Icons.close_fullscreen : Icons.open_in_full, color: Colors.white, size: 20),
                            if (!_isMapExpanded) ...[
                              const SizedBox(width: 8),
                              const Text("Expand Map", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            
            // LIST VIEW (Bottom Half) - Only show if not expanded
            if (!_isMapExpanded)
            Expanded(
              child: GlassContainer(
                opacity: 0.1,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text("Delivery Bands (Zones)", style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    const Text("Zones start where the previous one ends.", style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 10),
                    
                    // Render Zones with "From - To" logic
                    ...zones.asMap().entries.map((entry) {
                       int idx = entry.key;
                       Map<String, dynamic> zone = entry.value;
                       
                       // Calculate Range
                       double startKm = 0;
                       if (idx > 0) {
                         startKm = (zones[idx - 1]['radiusKm'] as num).toDouble();
                       }
                       double endKm = (zone['radiusKm'] as num).toDouble();
                       
                       return _buildZoneTile(context, zone, startKm, endKm, deliveryService, zones);
                    }).toList(),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneTile(BuildContext context, Map<String, dynamic> zone, double startKm, double endKm, DeliveryService service, List<Map<String, dynamic>> allZones) {
    Color color = _parseColor(zone['color']);
    
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, radius: 14, child: Text(zone['name'].toString().substring(5,6), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))),
        title: Text(zone['name'], style: const TextStyle(color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.straighten, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  "${startKm.toStringAsFixed(1)} km  ➝  ${endKm.toStringAsFixed(1)} km",
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            const SizedBox(height: 2),
             Row(
              children: [
                const Icon(Icons.payments_outlined, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  "₦${zone['baseFee']}",
                  style: const TextStyle(color: Colors.white70, fontSize: 13)
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.edit, color: Colors.white54, size: 20),
        onTap: () => _showEditZoneDialog(context, zone, startKm, endKm, service, allZones),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.blue;
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  void _confirmReset(BuildContext context, DeliveryService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text("Reset to Defaults?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will overwrite all current delivery zones with the default system configuration (Zone A-D). This action cannot be undone.",
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              // Send empty zones list or specific flag to trigger backend reset?
              // Or just manually set the known defaults here? 
              // Creating a clean set of defaults to push:
              final defaultZones = [
                { "name": "Zone A - Immediate", "description": "0 - 2.5 km (Neighborhood)", "radiusKm": 2.5, "baseFee": 500.0, "color": "4CAF50" },
                { "name": "Zone B - Core City", "description": "2.5 - 5.5 km (City Center)", "radiusKm": 5.5, "baseFee": 1000.0, "color": "FFC107" },
                { "name": "Zone C - Extended", "description": "5.5 - 9.0 km (Suburbs)", "radiusKm": 9.0, "baseFee": 1500.0, "color": "FF9800" },
                { "name": "Zone D - Outskirts", "description": "9.0 - 14.0 km (Far)", "radiusKm": 14.0, "baseFee": 2500.0, "color": "F44336" }
              ];
              await service.updateSettings({
                'zones': defaultZones, 
                'freeDistanceKm': 0, // Reset legacy
                'perKmCharge': 0 // Reset legacy
              });
              _fetchData();
            },
            child: const Text("Reset"),
          )
        ],
      ),
    );
  }

  void _showEditZoneDialog(BuildContext context, Map<String, dynamic> zone, double startKm, double currentMax, DeliveryService service, List<Map<String, dynamic>> allZones) {
     final feeCtrl = TextEditingController(text: zone['baseFee'].toString());
     final radiusCtrl = TextEditingController(text: zone['radiusKm'].toString());

     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         backgroundColor: const Color(0xFF1E1E2C),
         title: Text("Edit ${zone['name']}", style: const TextStyle(color: Colors.white)),
         content: SingleChildScrollView(
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               // Range Visualizer
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                 child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text("FROM (Fixed)", style: TextStyle(color: Colors.white38, fontSize: 10)),
                           Text("${startKm.toStringAsFixed(1)} KM", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                         ],
                       ),
                       const Icon(Icons.arrow_forward, color: Colors.white24, size: 16),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.end,
                         children: [
                           const Text("TO (Editable)", style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                           Text("${currentMax.toStringAsFixed(1)} KM", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                         ],
                       )
                    ],
                 ),
               ),
               const SizedBox(height: 20),
               
               TextField(
                 controller: radiusCtrl,
                 keyboardType: TextInputType.number,
                 style: const TextStyle(color: Colors.white),
                 decoration: const InputDecoration(
                    labelText: "End Distance (Radius)", 
                    labelStyle: TextStyle(color: Colors.greenAccent),
                    suffixText: "km",
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent, width: 2)),
                  ),
               ),
               const SizedBox(height: 15),
               TextField(
                 controller: feeCtrl,
                 keyboardType: TextInputType.number,
                 style: const TextStyle(color: Colors.white),
                 decoration: const InputDecoration(
                   labelText: "Base Fee", 
                   labelStyle: TextStyle(color: Colors.white54),
                   suffixText: "₦",
                   border: OutlineInputBorder(),
                 ),
               ),
             ],
           ),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
             onPressed: () async {
                // Construct clean zones array to update
                final updatedZones = allZones.map((z) {
                    if (z['name'] == zone['name']) {
                      // Update this specific zone
                      return {
                        'name': z['name'],
                        'description': z['description'] ?? '',
                        'radiusKm': double.tryParse(radiusCtrl.text) ?? z['radiusKm'],
                        'baseFee': double.tryParse(feeCtrl.text) ?? z['baseFee'],
                        'color': z['color'],
                        // NO CENTER FIELD
                      };
                    }
                    // Return others as-is, ensuring no legacy 'center' leaks if present in old cache
                    // But to be safe, we strip 'center' from all
                    return {
                        'name': z['name'],
                        'description': z['description'] ?? '',
                        'radiusKm': z['radiusKm'],
                        'baseFee': z['baseFee'],
                        'color': z['color'],
                    };
                }).toList();
                
                // Sort them again? Just to be safe? 
                // No, preserving identity is better, sorting happens on render.
                
                await service.updateSettings({'zones': updatedZones});
                
                if (mounted) Navigator.pop(ctx);
             },
             child: const Text("Save Changes"),
           )
         ],
       ),
     );
  }
}
