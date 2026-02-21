import 'package:flutter/foundation.dart'; // [NEW] Added for kIsWeb
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import '../models/review_model.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

class ReviewService extends ChangeNotifier {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Submit review
  Future<Map<String, dynamic>> submitReview({
    required String productId,
    required String orderId,
    required int rating,
    String? comment,
    List<File> images = const [],
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Upload images first (if any)
      List<String> imageUrls = [];
      for (var imageFile in images) {
        final imageUrl = await _uploadImage(imageFile);
        if (imageUrl != null) {
          imageUrls.add(imageUrl);
        }
      }

      // 2. Submit review
      final response = await _apiService.client.post('/reviews', data: {
        'productId': productId,
        'orderId': orderId,
        'rating': rating,
        'comment': comment,
        'images': imageUrls,
      });

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Review submitted successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to submit review'};
      }
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      final msg = e.response?.data['message'] ?? e.message ?? 'An unknown error occurred';
      return {'success': false, 'message': msg};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Submit admin "illusion" review
  Future<Map<String, dynamic>> submitAdminReview({
    required String productId,
    required int rating,
    required String userName,
    String? comment,
    List<File> images = const [],
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Upload images
      List<String> imageUrls = [];
      for (var imageFile in images) {
        final imageUrl = await _uploadImage(imageFile);
        if (imageUrl != null) {
          imageUrls.add(imageUrl);
        }
      }

      // 2. Submit admin review
      final response = await _apiService.client.post('/reviews/admin/create-illusion', data: {
        'productId': productId,
        'rating': rating,
        'userName': userName,
        'comment': comment,
        'images': imageUrls,
      });

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Admin review created successfully'};
      } else {
        return {'success': false, 'message': response.data['message'] ?? 'Failed to create admin review'};
      }
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      final msg = e.response?.data['message'] ?? e.message ?? 'An unknown error occurred';
      return {'success': false, 'message': msg};
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Upload single image to existing upload endpoint
  Future<String?> _uploadImage(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      
      MultipartFile multipartFile;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType("image", "jpeg"),
        );
      } else {
        multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          contentType: MediaType("image", "jpeg"),
        );
      }

      FormData formData = FormData.fromMap({
        "image": multipartFile,
      });

      final response = await _apiService.client.post("/upload", data: formData);

      if (response.statusCode == 200) {
        return response.data["filePath"];
      }
    } catch (e) {
      debugPrint("Image upload error: $e");
    }
    return null;
  }

  // Get reviews for a product
  Future<List<ReviewModel>> getProductReviews(String productId) async {
    try {
      final response = await _apiService.client.get('/reviews/product/$productId');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ReviewModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
    }
    return [];
  }

  // Admin: Get all reviews
  Future<List<ReviewModel>> getAllReviewsAdmin() async {
    try {
      final response = await _apiService.client.get('/reviews/admin/all');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ReviewModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching admin reviews: $e");
    }
    return [];
  }

  // Admin: Toggle visibility
  Future<bool> toggleVisibility(String reviewId) async {
    try {
      final response = await _apiService.client.patch('/reviews/admin/$reviewId/toggle-visibility');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error toggling visibility: $e");
      return false;
    }
  }
}
