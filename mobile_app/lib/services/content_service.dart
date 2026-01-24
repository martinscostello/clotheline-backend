import 'package:laundry_app/services/api_service.dart';
import 'package:laundry_app/models/service_model.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:laundry_app/data/seed_data.dart'; // Added Import

class ContentService {
  final ApiService _apiService = ApiService();

  Future<List<ServiceModel>> getServices() async {
    try {
      final response = await _apiService.client.get('/services');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.whereType<Map>().map((json) => ServiceModel.fromJson(Map<String, dynamic>.from(json))).toList();
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

  // --- OFFLINE FIRST CONTENT LOGIC ---

  // 1. Load Cache Only
  Future<AppContentModel?> loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final cachedString = prefs.getString('app_content_cache');
      if (cachedString != null) {
        return AppContentModel.fromJson(jsonDecode(cachedString));
      }
    } catch (_) {}
    
    // Fallback to Seed Data (First Launch)
    return AppContentModel.fromJson(kDefaultContent); 
  }
  
  // 2. Silent Sync
  Future<AppContentModel?> fetchFromApi() async {
    final prefs = await SharedPreferences.getInstance();
     try {
      final response = await _apiService.client.get('/content');
      if (response.statusCode == 200) {
        // Cache data
        await prefs.setString('app_content_cache', jsonEncode(response.data));
        return AppContentModel.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error silently fetching content: $e");
    }
    return null;
  }
  
  // COMPATIBILITY METHODS (Wrapper)
  Future<AppContentModel> getAppContent() async {
     // Try cache first
     final cached = await loadFromCache();
     if (cached != null) return cached;
     
     // Fallback to API
     final api = await fetchFromApi();
     if (api != null) return api;

     return AppContentModel(
       id: "empty", 
       brandText: "Welcome", 
       heroCarousel: [], 
       homeGridServices: [],
       productAds: [],
       productCategories: [],
       contactAddress: "",
       contactPhone: ""
     );
  }

  Future<AppContentModel?> refreshAppContent() async {
    return fetchFromApi();
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

  Future<String?> uploadImage(String filePath, {Function(int, int)? onProgress}) async {
    try {
      String fileName = filePath.split('/').last;
      String mimeType = 'jpeg';
      String type = 'image';
      
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.png')) {
        mimeType = 'png';
      } else if (lowerName.endsWith('.gif')) mimeType = 'gif';
      else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) mimeType = 'jpeg';
      else if (lowerName.endsWith('.mp4')) { type = 'video'; mimeType = 'mp4'; }
      else if (lowerName.endsWith('.mov')) { type = 'video'; mimeType = 'quicktime'; }
      else if (lowerName.endsWith('.avi')) { type = 'video'; mimeType = 'x-msvideo'; }

      // Create FormData
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType(type, mimeType), 
        ),
      });

      final response = await _apiService.client.post(
        '/upload',
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.statusCode == 200) {
        final path = response.data['filePath'];
        // Cloudinary returns full URL
        if (path.toString().startsWith('http')) return path;
        
        final relativePath = path;
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
