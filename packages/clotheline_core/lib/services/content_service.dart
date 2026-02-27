import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data'; // [NEW] For Web Byte Buffers
import 'package:clotheline_core/clotheline_core.dart'; // Added Import

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

  // Branch-aware cache key
  String _cacheKey(String? branchId) =>
      branchId != null ? 'app_content_cache_$branchId' : 'app_content_cache';

  // 1. Load Cache Only (branch-aware)
  Future<AppContentModel?> loadFromCache({String? branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final cachedString = prefs.getString(_cacheKey(branchId));
      if (cachedString != null) {
        return AppContentModel.fromJson(jsonDecode(cachedString));
      }
      // Fall back to global cache if branch cache is empty
      if (branchId != null) {
        final globalCached = prefs.getString(_cacheKey(null));
        if (globalCached != null) {
          return AppContentModel.fromJson(jsonDecode(globalCached));
        }
      }
    } catch (_) {}
    
    // Fallback to Seed Data (First Launch)
    return AppContentModel.fromJson(kDefaultContent); 
  }
  
  // 2. Silent Sync (branch-aware)
  Future<AppContentModel?> fetchFromApi({String? branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final queryParams = branchId != null ? '?branchId=$branchId' : '';
      final response = await _apiService.client.get('/content$queryParams');
      if (response.statusCode == 200) {
        // Cache data under branch-specific key
        await prefs.setString(_cacheKey(branchId), jsonEncode(response.data));
        return AppContentModel.fromJson(response.data);
      }
    } catch (e) {
      debugPrint("Error silently fetching content: $e");
    }
    return null;
  }
  
  // COMPATIBILITY METHODS (Wrapper)
  Future<AppContentModel> getAppContent({String? branchId}) async {
     // Try branch-specific cache first
     final cached = await loadFromCache(branchId: branchId);
     if (cached != null) return cached;
     
     // Fallback to API
     final api = await fetchFromApi(branchId: branchId);
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

  Future<AppContentModel?> refreshAppContent({String? branchId}) async {
    return fetchFromApi(branchId: branchId);
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

  // --- BRANCH OVERRIDE MANAGEMENT ---

  Future<bool> updateBranchContentOverride(String branchId, {
    List<Map<String, dynamic>>? heroCarousel,
    List<Map<String, dynamic>>? productAds,
  }) async {
    try {
      final response = await _apiService.client.put('/content/branch-override', data: {
        'branchId': branchId,
        if (heroCarousel != null) 'heroCarousel': heroCarousel,
        if (productAds != null) 'productAds': productAds,
      });
      if (response.statusCode == 200) {
        // Invalidate branch cache to force refetch
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cacheKey(branchId));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating branch content override: $e");
      return false;
    }
  }

  Future<bool> clearBranchContentOverride(String branchId) async {
    try {
      final response = await _apiService.client.delete('/content/branch-override/$branchId');
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_cacheKey(branchId));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error clearing branch content override: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> getBranchContentOverride(String branchId) async {
    try {
      final response = await _apiService.client.get('/content/branch-override/$branchId');
      if (response.statusCode == 200) return response.data;
      return null;
    } catch (e) {
      debugPrint("Error fetching branch content override: $e");
      return null;
    }
  }

  Future<String?> uploadImage(String filePath, {Uint8List? fileBytes, String? explicitFileName, Function(int, int)? onProgress}) async {
    try {
      String fileName = explicitFileName ?? filePath.split('/').last;
      String mimeType = 'jpeg';
      String type = 'image';
      
      final lowerName = fileName.toLowerCase();
      if (lowerName.endsWith('.png')) {
        mimeType = 'png';
      } else if (lowerName.endsWith('.gif')) { mimeType = 'gif'; }
      else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) { mimeType = 'jpeg'; }
      else if (lowerName.endsWith('.mp4')) { type = 'video'; mimeType = 'mp4'; }
      else if (lowerName.endsWith('.mov')) { type = 'video'; mimeType = 'quicktime'; }
      else if (lowerName.endsWith('.avi')) { type = 'video'; mimeType = 'x-msvideo'; }

      // [CRITICAL] Create MultipartFile conditionally based on platform (Bytes vs File Paths)
      MultipartFile multipartFile;
      if (fileBytes != null) {
        multipartFile = MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: MediaType(type, mimeType),
        );
      } else {
        multipartFile = await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType(type, mimeType), 
        );
      }

      // Create FormData
      final formData = FormData.fromMap({
        'image': multipartFile,
      });

      final response = await _apiService.client.post(
        '/upload',
        data: formData,
        onSendProgress: onProgress,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
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
