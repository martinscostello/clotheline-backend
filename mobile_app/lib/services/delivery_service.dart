
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/branch_model.dart';

class DeliveryService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _settings;
  bool _isLoading = false;

  Map<String, dynamic>? get settings => _settings;
  bool get isLoading => _isLoading;

  // Fallback Defaults (Concentric Distance Bands)
  static final Map<String, dynamic> _defaults = {
    'laundryLocation': {'lat': 6.303337, 'lng': 5.5945522}, // HQ
    'isDistanceBillingEnabled': false, // Disable per-km by default, use bands
    'zones': [
       {
        'name': "Zone A - Immediate",
        'description': "0 - 2.5 km",
        'baseFee': 500,
        'radiusKm': 2.5,
        'color': '4CAF50'
       },
       {
        'name': "Zone B - Core City",
        'description': "2.5 - 5.5 km",
        'baseFee': 1000,
        'radiusKm': 5.5,
        'color': 'FFC107'
       },
       {
        'name': "Zone C - Extended",
        'description': "5.5 - 9.0 km",
        'baseFee': 1500,
        'radiusKm': 9.0,
        'color': 'FF9800'
       },
       {
        'name': "Zone D - Outskirts",
        'description': "9.0 - 14.0 km",
        'baseFee': 2500,
        'radiusKm': 14.0,
        'color': 'F44336'
       }
    ]
  };

  Future<void> fetchSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Try Local Cache First (Instant Load)
    if (_settings == null) {
      final cachedString = prefs.getString('delivery_settings_cache');
      if (cachedString != null) {
        try {
          _settings = jsonDecode(cachedString);
          notifyListeners(); // Update UI immediately with cache
        } catch (_) {}
      }
    }

    // 2. If still null (first run), load Defaults (Guarantee UI)
    if (_settings == null) {
      _settings = Map.from(_defaults);
      notifyListeners();
    }

    // 3. Background Refresh (Silent Update)
    try {
      final response = await _apiService.client.get('/delivery');
      if (response.statusCode == 200) {
        _settings = response.data;
        // Save to Cache
        await prefs.setString('delivery_settings_cache', jsonEncode(_settings));
        notifyListeners(); // Refresh UI with Server Data
      }
    } catch (e) {
      debugPrint('Background fetch failed: $e. Using cached/default data.');
    }
  }

  Future<void> updateSettings(Map<String, dynamic> updates) async {
    // Optimistic Update: Update Local UI First
    if (_settings != null) {
      _settings!.addAll(updates);
      notifyListeners();
    }

    try {
      final response = await _apiService.client.put('/delivery', data: updates);
      if (response.statusCode == 200) {
        _settings = response.data;
        // Update Cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('delivery_settings_cache', jsonEncode(_settings));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Update failed: $e');
      throw Exception('Failed to sync settings with server');
    }
  }

  // Calculate Fee Logic (Distance Bands from HQ or Branch)
  double calculateDeliveryFee(double userLat, double userLng, {Branch? branch}) {
    LatLng laundryPoint;
    List<dynamic> zones;

    if (branch != null) {
      laundryPoint = LatLng(branch.location.lat, branch.location.lng);
      zones = branch.deliveryZones.map((z) => {
        'radiusKm': z.radiusKm,
        'baseFee': z.baseFee,
        // Map other fields if needed
      }).toList();
    } else {
      // Fallback to old global settings
      if (_settings == null) {
         _settings = Map.from(_defaults); 
      }
      final laundryLoc = _settings!['laundryLocation'];
       laundryPoint = LatLng(laundryLoc['lat'], laundryLoc['lng']);
       zones = List<Map<String, dynamic>>.from(_settings!['zones']);
    }
    
    final Distance distanceCalc = const Distance();
    final userPoint = LatLng(userLat, userLng);
    
    // 1. Calculate Straight-Line Distance in Km
    final double distanceMeters = distanceCalc.as(LengthUnit.Meter, userPoint, laundryPoint);
    final double distanceKm = distanceMeters / 1000;
    
    // 2. Find Containing Band (Nearest -> Farthest)
    Map<String, dynamic>? matchedZone;
    
    // Sort zones by radius just in case (Smallest radius first)
    zones.sort((a, b) => (a['radiusKm'] as num).compareTo(b['radiusKm'] as num));

    for (var zone in zones) {
       final double maxRadius = (zone['radiusKm'] as num).toDouble();
       
       if (distanceKm <= maxRadius) {
         matchedZone = zone;
         break; // Found the smallest containing band
       }
    }
    
    // 3. Handle Out of Range
    if (matchedZone == null) {
      return -1.0; 
    }
    
    return (matchedZone['baseFee'] as num).toDouble();
  }
}
