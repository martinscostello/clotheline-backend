import 'package:flutter/material.dart';
import 'package:laundry_app/services/api_service.dart';
import '../models/service_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LaundryService extends ChangeNotifier {
  static final LaundryService _instance = LaundryService._internal();
  factory LaundryService() => _instance;
  LaundryService._internal();

  final ApiService _apiService = ApiService();

  // Initialize with Defaults immediately to ensure UI never spins
  List<ServiceModel> _services = _defaults.map((json) => ServiceModel.fromJson(json)).toList();
  List<ServiceModel> get services => List.unmodifiable(_services);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Hardcoded Defaults for "First Run Offline" experience
  static final List<Map<String, dynamic>> _defaults = [
    {
      "name": "Wash & Fold",
      "description": "Everyday clothes washed, dried, and neatly folded.",
      "image": "assets/images/service_laundry.png",
      "pricePerKg": 1500,
      "packages": []
    },
    {
       "name": "Dry Cleaning",
       "description": "Professional care for delicate fabrics and suits.",
       "image": "assets/images/service_laundry.png", // Reuse valid asset
       "pricePerKg": 0,
       "isLocked": false,
       "packages": [] 
    },
    {
       "name": "Shoe Care",
       "description": "Expert cleaning for sneakers and formal shoes.",
       "image": "assets/images/service_shoes.png",
       "pricePerKg": 0,
       "packages": []
    },
     {
      "name": "Household & Rugs",
      "description": "Deep cleaning for duvets, curtains, and rugs.",
      "image": "assets/images/service_rug.png",
      "pricePerKg": 0,
       "packages": []
    }
  ];

  Future<void> fetchServices() async {
    _isLoading = true;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();

    // 1. Try loading from cache immediately
    if (_services.isEmpty) {
      try {
        final cached = prefs.getString('services_cache');
        if (cached != null) {
          final List<dynamic> data = jsonDecode(cached);
          _services = data.map((json) => ServiceModel.fromJson(json)).toList();
        } else {
           // 1b. Use Defaults if no cache
           _services = _defaults.map((json) => ServiceModel.fromJson(json)).toList();
        }
        // Notify so UI renders cached/default data while fetching fresh
        notifyListeners(); 
      } catch (e) {
         debugPrint("Error loading services cache: $e");
         _services = _defaults.map((json) => ServiceModel.fromJson(json)).toList();
         notifyListeners();
      }
    }

    // 2. Fetch from API
    try {
      final response = await _apiService.client.get('/services');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Compare with current to avoid blink
        final currentJson = jsonEncode(_services.map((e) => e.toJson()).toList());
        final newJson = jsonEncode(data); // data is already List<dynamic> or Map? Response.data is usually List for this endpoint

        // The "data" from dio might be List<dynamic>. We need to ensure we compare apples to apples.
        // Easiest is to parse and re-encode, or just encode response.data if we trust structure.
        // Let's rely on parsing to models to be safe.
        final newServices = data.map((json) => ServiceModel.fromJson(json)).toList();
        final newServicesJson = jsonEncode(newServices.map((e) => e.toJson()).toList());

        if (currentJson != newServicesJson) {
           _services = newServices;
           await prefs.setString('services_cache', jsonEncode(data));
           notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
    } finally {
      _isLoading = false;
      // notifyListeners(); // REMOVE this finally notify to prevent double rebuild if nothing changed
    }
  }

  // Find a service by ID or Name (helper)
  ServiceModel? getServiceByName(String name) {
    try {
       return _services.firstWhere((s) => s.name.toLowerCase().contains(name.toLowerCase()));
    } catch (e) {
      return null;
    }
  }
}
