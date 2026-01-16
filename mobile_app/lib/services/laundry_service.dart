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

  // Start Empty - No Defaults!
  List<ServiceModel> _services = [];
  List<ServiceModel> get services => List.unmodifiable(_services);

  bool _isHydrated = false;
  bool get isHydrated => _isHydrated;

  // 1. Load Local Cache ONLY
  Future<void> loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final cached = prefs.getString('services_cache');
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        _services = data.map((json) => ServiceModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("Error loading services cache: $e");
    } finally {
      _isHydrated = true;
      notifyListeners();
    }
  }

  // 2. Silent Background Sync
  Future<void> fetchFromApi() async {
    // Don't block UI. Just fetch and compare.
    try {
      final response = await _apiService.client.get('/services');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        
        // Compare with current
        final currentJson = jsonEncode(_services.map((e) => e.toJson()).toList());
        final newServices = data.map((json) => ServiceModel.fromJson(json)).toList();
        final newServicesJson = jsonEncode(newServices.map((e) => e.toJson()).toList());

        if (currentJson != newServicesJson) {
           _services = newServices;
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString('services_cache', jsonEncode(data));
           notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Background sync failed: $e");
    }
  }

  // COMPATIBILITY METHOD
  Future<void> fetchServices() async {
     await fetchFromApi();
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
