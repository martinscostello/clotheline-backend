import 'package:flutter/material.dart';
import '../../../../models/service_model.dart';
import '../../../../services/api_service.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'admin_edit_service_screen.dart'; // We will create this next

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  List<ServiceModel> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final response = await http.get(Uri.parse('${ApiService.baseUrl}/services'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _services = data.map((e) => ServiceModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Manage Services", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
      ),
      body: LiquidBackground(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.85,
              ),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                return GestureDetector(
                  onTap: () async {
                     await Navigator.push(
                       context, 
                       MaterialPageRoute(builder: (_) => AdminEditServiceScreen(service: service))
                     );
                     _fetchServices(); // Refresh on return
                  },
                  child: GlassContainer(
                    opacity: 0.1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon / Image
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(int.parse(service.color.replaceAll('#', '0xFF'))).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconData(service.icon),
                            color: Color(int.parse(service.color.replaceAll('#', '0xFF'))),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Name
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            service.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Status Badge
                        const SizedBox(height: 8),
                        if (service.isLocked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                            child: Text(service.lockedLabel, style: const TextStyle(color: Colors.white, fontSize: 10)),
                          )
                        else if (service.discountPercentage > 0)
                           Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                            child: Text("-${service.discountPercentage}% OFF", style: const TextStyle(color: Colors.white, fontSize: 10)),
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'dry_cleaning': return Icons.dry_cleaning;
      case 'local_laundry_service': return Icons.local_laundry_service;
      case 'do_not_step': return Icons.do_not_step;
      case 'water_drop': return Icons.water_drop;
      case 'house': return Icons.house;
      default: return Icons.category;
    }
  }
}
