import 'package:laundry_app/services/api_service.dart';
import 'package:laundry_app/models/service_model.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

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

  Future<AppContentModel?> getAppContent() async {
    try {
      final response = await _apiService.client.get('/content');
      if (response.statusCode == 200) {
        return AppContentModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching content: $e");
      return null;
    }
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
