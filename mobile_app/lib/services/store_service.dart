import 'package:flutter/material.dart';
import 'package:laundry_app/services/api_service.dart';
import '../models/store_product.dart';
import '../models/category_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Service to manage Store Data (Product Listing, Editing)
class StoreService extends ChangeNotifier {
  static final StoreService _instance = StoreService._internal();
  factory StoreService() => _instance;
  StoreService._internal();

  final ApiService _apiService = ApiService();

  List<CategoryModel> _categoryObjects = [];
  List<CategoryModel> get categoryObjects => List.unmodifiable(_categoryObjects);

  Future<void> fetchProducts({bool forceRefresh = false}) async {
    if (_products.isNotEmpty && !forceRefresh) return;

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
      final response = await _apiService.client.get('/categories');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Parse into CategoryModel objects
        _categoryObjects = data.map((json) => CategoryModel.fromJson(json)).toList();
        
        // Update the string list for UI compatibility (StoreScreen filter)
        _categories = ["All", ..._categoryObjects.map((c) => c.name).toList()];
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  Future<bool> addCategory(String name) async {
    try {
      final response = await _apiService.client.post('/categories', data: {'name': name});
      if (response.statusCode == 200) {
        await fetchCategories();
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      final response = await _apiService.client.delete('/categories/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchCategories();
        return true;
      }
      return false;
    } catch (e) { return false; }
  }


  Future<void> rotateFeaturedProducts() async {
    if (_products.isEmpty && _featuredProducts.isEmpty) await fetchProducts();
    
    // If we have products, pick 5 random ones
    if (_products.isNotEmpty) {
      final shuffled = List<StoreProduct>.from(_products)..shuffle();
      final newFeatured = shuffled.take(5).toList();
      
      // Check if different from current
      final currentIds = _featuredProducts.map((e) => e.id).toSet();
      final newIds = newFeatured.map((e) => e.id).toSet();
      
      if (currentIds.difference(newIds).isNotEmpty || newIds.difference(currentIds).isNotEmpty) {
          _featuredProducts = newFeatured;
          notifyListeners();
      }
    }
  }

  Future<void> fetchFeaturedProducts() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load from cache first
    if (_featuredProducts.isEmpty) {
      try {
        final cached = prefs.getString('featured_products_cache');
        if (cached != null) {
          final List<dynamic> data = jsonDecode(cached);
          _featuredProducts = data.map((json) => StoreProduct.fromJson(json)).toList();
          notifyListeners();
        }
      } catch (e) {}
    }

    // 2. Fetch ALL products then random select 5
    // This supports the "Random at intervals" requirement better than backend limit
    try {
      final response = await _apiService.client.get('/products'); // Get ALL
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final allProducts = data.map((json) => StoreProduct.fromJson(json)).toList();
        _products = allProducts; // Update main list too while we are at it

        if (allProducts.isNotEmpty) {
           final shuffled = List<StoreProduct>.from(allProducts)..shuffle();
           final newFeatured = shuffled.take(5).toList();
           
           _featuredProducts = newFeatured;
           notifyListeners();
           
           // Cache THIS selection
           await prefs.setString('featured_products_cache', jsonEncode(newFeatured.map((e)=>e.toJson()).toList()));
        }
      }
    } catch (e) {
      debugPrint("Error fetching featured products: $e");
    }
  }

  Future<bool> addProduct(Map<String, dynamic> productData) async {
    try {
      final response = await _apiService.client.post('/products', data: productData);
      if (response.statusCode == 200) {
        await fetchProducts(forceRefresh: true); // Refresh
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
        await fetchProducts(forceRefresh: true);
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
