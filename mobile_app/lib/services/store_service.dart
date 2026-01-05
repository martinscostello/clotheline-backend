import 'package:flutter/material.dart';
import 'package:laundry_app/services/api_service.dart';
import '../models/store_product.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Service to manage Store Data (Product Listing, Editing)
class StoreService extends ChangeNotifier {
  static final StoreService _instance = StoreService._internal();
  factory StoreService() => _instance;
  StoreService._internal();

  final ApiService _apiService = ApiService();

  List<StoreProduct> _products = [];
  List<StoreProduct> get products => List.unmodifiable(_products);

  List<String> _categories = ["All"];
  List<String> get categories => List.unmodifiable(_categories);

  List<StoreProduct> _featuredProducts = [];
  List<StoreProduct> get featuredProducts => List.unmodifiable(_featuredProducts);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/products');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _products = data.map((json) => StoreProduct.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response = await _apiService.client.get('/products/categories');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _categories = ["All", ...data.map((e) => e.toString()).toList()];
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  Future<void> fetchFeaturedProducts() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load from cache first if empty
    if (_featuredProducts.isEmpty) {
      try {
        final cached = prefs.getString('featured_products_cache');
        if (cached != null) {
          final List<dynamic> data = jsonDecode(cached);
          _featuredProducts = data.map((json) => StoreProduct.fromJson(json)).toList();
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Error loading featured product cache: $e");
      }
    }

    // 2. Fetch from API
    try {
      final response = await _apiService.client.get('/products?limit=5');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _featuredProducts = data.map((json) => StoreProduct.fromJson(json)).toList();
        notifyListeners();
        
        // Save to cache
        await prefs.setString('featured_products_cache', jsonEncode(data));
      }
    } catch (e) {
      debugPrint("Error fetching featured products: $e");
    }
  }

  Future<bool> addProduct(Map<String, dynamic> productData) async {
    try {
      final response = await _apiService.client.post('/products', data: productData);
      if (response.statusCode == 200) {
        await fetchProducts(); // Refresh
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error adding product: $e");
      return false;
    }
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.client.put('/products/$id', data: updates);
      if (response.statusCode == 200) {
        // Optimistic update
        final index = _products.indexWhere((p) => p.id == id);
        if (index != -1) {
           // We might need to refetch to be sure, or merge updates.
           // For simplicity, refetch.
        }
        await fetchProducts();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating product: $e");
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      final response = await _apiService.client.delete('/products/$id');
      if (response.statusCode == 200) {
        _products.removeWhere((p) => p.id == id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting product: $e");
      return false;
    }
  }
}
