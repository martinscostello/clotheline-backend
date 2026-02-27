import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/service_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LaundryService extends ChangeNotifier {
  static final LaundryService _instance = LaundryService._internal();
  
  // Factory with DI support (sort of - Singleton makes DI hard directly, but we can init instance)
  // Actually, we should allow constructing with data for Provider.
  // The singleton pattern here complicates Provider usage if we want unique instances per tree, 
  // but usually Provider uses one. 
  // Let's modify the factory to allow setting a default state if not initialized?
  // Or better, just make the constructor accessible for Provider.
  
  factory LaundryService() => _instance;
  
  LaundryService._internal();

  // Helper for Bootstrapping (Call this before Provider usage if using Singleton)
  void hydrateFromBootstrap(List<ServiceModel> bootstrapData) {
     _services = bootstrapData;
     _isHydrated = true;
  }

  final ApiService _apiService = ApiService();

  // Start Empty - No Defaults!
  List<ServiceModel> _services = [];
  List<ServiceModel> get services => List.unmodifiable(_services);

  bool _isHydrated = false;
  bool get isHydrated => _isHydrated;

  // 1. Load Local Cache ONLY
  Future<void> loadFromCache({String? branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final key = branchId != null ? 'services_cache_$branchId' : 'services_cache_default';
      final cached = prefs.getString(key);
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
  Future<void> fetchFromApi({String? branchId, bool includeHidden = false}) async {
    // Don't block UI. Just fetch and compare.
    try {
      String endpoint = branchId != null ? '/services?branchId=$branchId' : '/services';
      if (includeHidden) {
        endpoint += branchId != null ? '&includeHidden=true' : '?includeHidden=true';
      }
      
      final response = await _apiService.client.get(endpoint);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        
        // Compare with current
        final currentJson = jsonEncode(_services.map((e) => e.toJson()).toList());
        final newServices = data.map((json) => ServiceModel.fromJson(json)).toList();
        final newServicesJson = jsonEncode(newServices.map((e) => e.toJson()).toList());

        // Always update if we are switching branches (branchId provided)
        // Or if data changed
        if (branchId != null || currentJson != newServicesJson) {
           _services = newServices;
           final prefs = await SharedPreferences.getInstance();
           
           // Branch-Aware Caching
           final key = branchId != null ? 'services_cache_$branchId' : 'services_cache_default';
           await prefs.setString(key, jsonEncode(data));
           
           notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Background sync failed: $e");
    }
  }

  // COMPATIBILITY METHOD
  Future<void> fetchServices({String? branchId, bool includeHidden = false}) async {
     await fetchFromApi(branchId: branchId, includeHidden: includeHidden);
  }

  // Find a service by ID or Name (helper)
  ServiceModel? getServiceByName(String name) {
    try {
       return _services.firstWhere((s) => s.name.toLowerCase().contains(name.toLowerCase()));
    } catch (e) {
      return null;
    }
  }

  // [NEW] Delete Service (Admin)
  Future<bool> deleteService(String serviceId) async {
    try {
      final response = await _apiService.client.delete('/services/$serviceId');
      if (response.statusCode == 200) {
        _services.removeWhere((s) => s.id == serviceId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting service: $e");
    }
    return false;
  }

  // [NEW] Bulk Reorder (Admin)
  Future<bool> updateServiceOrder(List<ServiceModel> reorderedList) async {
    try {
      final List<Map<String, dynamic>> orderData = [];
      for (int i = 0; i < reorderedList.length; i++) {
        orderData.add({
           'id': reorderedList[i].id,
           'order': i
        });
      }

      final response = await _apiService.client.put('/services/reorder', data: {
        'orders': orderData
      });

      if (response.statusCode == 200) {
        _services = List.from(reorderedList);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating service order: $e");
    }
    return false;
  }
}
