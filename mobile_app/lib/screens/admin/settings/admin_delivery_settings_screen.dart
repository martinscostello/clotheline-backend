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

  const _BranchMapEditor({required this.branch, required this.onClose});

  @override
  State<_BranchMapEditor> createState() => _BranchMapEditorState();
}

class _BranchMapEditorState extends State<_BranchMapEditor> {
  late TextEditingController _latController;
  late TextEditingController _lngController;
  final MapController _mapController = MapController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(text: widget.branch.location.latitude.toString());
    _lngController = TextEditingController(text: widget.branch.location.longitude.toString());
  }

  Future<void> _saveLocation() async {
    final double? lat = double.tryParse(_latController.text);
    final double? lng = double.tryParse(_lngController.text);

    if (lat == null || lng == null) return;

    setState(() => _isSaving = true);
    
    final provider = Provider.of<BranchProvider>(context, listen: false);
    final success = await provider.updateBranch(widget.branch.id, {
      'location': {'lat': lat, 'lng': lng}
    });

    setState(() => _isSaving = false);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location Updated")));
    }
  }

  void _onMapTap(TapPosition pos, LatLng point) {
    _latController.text = point.latitude.toStringAsFixed(6);
    _lngController.text = point.longitude.toStringAsFixed(6);
    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    final lat = double.tryParse(_latController.text) ?? widget.branch.location.latitude;
    final lng = double.tryParse(_lngController.text) ?? widget.branch.location.longitude;
    final center = LatLng(lat, lng);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: widget.onClose),
        title: Text("Edit ${widget.branch.name}", style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: LiquidBackground(
        child: Column(
          children: [
            const SizedBox(height: 100), // App bar space
            
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)]
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13.0,
                      onTap: _onMapTap,
                    ),
                    children: [
                       TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.clotheline.app',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(point: center, color: Colors.blue.withOpacity(0.3), useRadiusInMeter: true, radius: 3000, borderColor: Colors.blue, borderStrokeWidth: 2),
                          CircleMarker(point: center, color: Colors.orange.withOpacity(0.2), useRadiusInMeter: true, radius: 7000, borderColor: Colors.orange, borderStrokeWidth: 2),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(point: center, width: 80, height: 80, child: const Icon(Icons.location_pin, color: Colors.red, size: 40)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // Controls
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              child: GlassContainer(
                child: Column(
                  children: [
                    const Text("Update Coordinates", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildInput("Lat", _latController)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildInput("Lng", _lngController)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                        onPressed: _isSaving ? null : _saveLocation,
                        child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Changes", style: TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
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
        ),
        onChanged: (_) => setState((){}),
     );
  }
}
