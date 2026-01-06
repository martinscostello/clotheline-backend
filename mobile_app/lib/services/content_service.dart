import 'package:laundry_app/services/api_service.dart';
import 'package:laundry_app/models/service_model.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ContentService {
  final ApiService _apiService = ApiService();

  Future<List<ServiceModel>> getServices() async {
    try {
      final response = await _apiService.client.get('/services');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ServiceModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load services');
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
      return [];
    }
  }

  Future<bool> createService(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.client.post('/services', data: data);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error creating service: $e");
      return false;
    }
  }

  Future<bool> updateService(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.client.put('/services/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating service: $e");
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    try {
      final response = await _apiService.client.delete('/services/$id');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error deleting service: $e");
      return false;
    }
  }

  // Defaults
  static final Map<String, dynamic> _defaults = {
    "_id": "default_content_id",
    "brandText": "Good Morning",
    "heroCarousel": [
      {
        "imageUrl": "https://images.unsplash.com/photo-1545173168-9f1947eebb8f?q=80&w=2971&auto=format&fit=crop", // Safe generic laundry img
        "title": "Premium Laundry Service",
        "tagLine": "We care for your clothes",
        "titleColor": "white",
        "tagLineColor": "white70"
      },
      {
         "imageUrl": "https://images.unsplash.com/photo-1582735689369-4fe89db7114c?q=80&w=2970&auto=format&fit=crop",
         "title": "Fast Pickup & Delivery",
         "tagLine": "Schedule in seconds",
         "titleColor": "white",
         "tagLineColor": "white70"
      }
    ]
  };

  // Fast Load: Cache -> Defaults
  Future<AppContentModel> getAppContent() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Try Cache
    try {
      final cachedString = prefs.getString('app_content_cache');
      if (cachedString != null) {
        return AppContentModel.fromJson(jsonDecode(cachedString));
      }
    } catch (_) {}

    // 2. Return Defaults
    return AppContentModel.fromJson(_defaults);
  }
  
  // Background Refresh: Network -> Cache
  Future<AppContentModel?> refreshAppContent() async {
    final prefs = await SharedPreferences.getInstance();
     try {
      final response = await _apiService.client.get('/content');
      if (response.statusCode == 200) {
        // Cache data
        await prefs.setString('app_content_cache', jsonEncode(response.data));
        return AppContentModel.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error fetching content from API: $e");
    }
    return null;
  }

  Future<bool> updateAppContent(Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.client.put('/content', data: updates);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error updating content: $e");
      return false;
    }
  }
  Future<String?> uploadImage(String filePath) async {
    try {
      String fileName = filePath.split('/').last;
      
      // Create FormData
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'), // Adjust if needed
        ),
      });

      final response = await _apiService.client.post(
        '/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        // Construct full URL.
        // Assuming backend returns relative path like "/uploads/filename.jpg"
        // And ApiService baseUrl is "http://localhost:5001/api"
        // We need "http://localhost:5001/uploads/filename.jpg"
        
        // This is a bit of a hack since ApiService might point to /api
        // We want to strip /api and append the path
        final relativePath = response.data['filePath'];
        final baseUrl = ApiService.baseUrl.replaceAll('/api', '');
        return "$baseUrl$relativePath";
      }
      return null;
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }
}
