import 'package:flutter/material.dart';
import 'package:laundry_app/services/api_service.dart';
import '../models/store_product.dart';
import '../models/category_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:laundry_app/data/seed_data.dart'; // Added Import

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

  List<CategoryModel> _categoryObjects = [];
  List<CategoryModel> get categoryObjects => List.unmodifiable(_categoryObjects);

  bool _isHydrated = false;
  bool get isHydrated => _isHydrated;

  // 1. Load Cache Only
  Future<void> loadFromCache({String? branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // 1. Products Cache (Branch Aware)
      final prodKey = branchId != null ? 'products_cache_$branchId' : 'products_cache';
      final cached = prefs.getString(prodKey);
      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        _products = data.whereType<Map>().map((json) => StoreProduct.fromJson(Map<String, dynamic>.from(json))).toList();
      } else if (branchId == null) {
        // Fallback to Seed Data only for global context
        _products = kDefaultProducts.map((json) => StoreProduct.fromJson(json)).toList();
      }
      
      // 2. Categories Cache (Global)
      final cachedCats = prefs.getString('categories_cache');
      if (cachedCats != null) {
         final List<dynamic> data = jsonDecode(cachedCats);
         _categoryObjects = data.map((json) => CategoryModel.fromJson(json)).toList();
         _categories = ["All", ..._categoryObjects.map((c) => c.name)];
      }
    } catch (e) {
      debugPrint("Error loading store cache: $e");
    } finally {
      _isHydrated = true;
      notifyListeners();
    }
  }

  // 2. Silent Sync
  Future<void> fetchFromApi({String? branchId}) async {
    _isLoading = true;
    
    // Fetch Products
    try {
      final endpoint = branchId != null ? '/products?branchId=$branchId' : '/products'; // Strict Scope
      final response = await _apiService.client.get(endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final newProducts = data.whereType<Map>().map((json) => StoreProduct.fromJson(Map<String, dynamic>.from(json))).toList();
        
        // Cache Logic (Simple overwrite for now, optimized diffing can be added if needed)
        _products = newProducts;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('products_cache_$branchId', jsonEncode(data)); // Branch-aware cache key
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching products: $e");
    }

    // Fetch Categories
    try {
       final response = await _apiService.client.get('/categories');
       if (response.statusCode == 200) {
          final List<dynamic> data = response.data;
          _categoryObjects = data.map((json) => CategoryModel.fromJson(json)).toList();
          _categories = ["All", ..._categoryObjects.map((c) => c.name)];
          
          // Persist Categories
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('categories_cache', jsonEncode(data));
          
          notifyListeners();
       }
    } catch(e) {
       debugPrint("Error fetching categories: $e");
    }

    _isLoading = false;
  }

  // COMPATIBILITY (Wraps silent sync)
  Future<void> fetchProducts({String? branchId, bool forceRefresh = false}) async {
    // Note: We might want separate cache keys for Separate branches.
    if (!_isHydrated && branchId == null) await loadFromCache();
    await fetchFromApi(branchId: branchId);
  }
  
  // Categories Helper
  Future<void> fetchCategories() async {
     // Explicitly fetch global data from API to ensure fresh list
     await fetchFromApi();
  }



  Future<String?> addCategory(String name) async {
    try {
      final response = await _apiService.client.post('/categories', data: {'name': name});
      if (response.statusCode == 200) {
        await fetchCategories();
        return null; // Success
      }
      return response.data['msg'] ?? "Failed with status ${response.statusCode}";
    } catch (e) { return "Error: $e"; }
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

  Future<void> fetchFeaturedProducts({String? branchId, bool onlyCache = false}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load from cache first
    // Note: We might want branch-specific cache key, but for now global is okay as it rotates
    if (_featuredProducts.isEmpty) {
      try {
        final cached = prefs.getString('featured_products_cache');
        if (cached != null) {
          final List<dynamic> data = jsonDecode(cached);
          _featuredProducts = data.whereType<Map>().map((json) => StoreProduct.fromJson(Map<String, dynamic>.from(json))).toList();
          notifyListeners();
        }
      } catch (e) {}
    }

    if (onlyCache) return;

    // 2. Fetch ALL products then random select 5
    try {
      final endpoint = branchId != null ? '/products?branchId=$branchId' : '/products'; 
      final response = await _apiService.client.get(endpoint);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final allProducts = data.whereType<Map>().map((json) => StoreProduct.fromJson(Map<String, dynamic>.from(json))).toList();
        
         // Only update main products if we are in the "Active Branch" context
         // But StoreService is singleton, so be careful. 
         // For now, let's NOT overwrite _products here to avoid state thrashing if just fetching featured for Home.
         // _products = allProducts; 

        if (allProducts.isNotEmpty) {
           final shuffled = List<StoreProduct>.from(allProducts)..shuffle();
           final newFeatured = shuffled.take(5).toList();
           
           _featuredProducts = newFeatured;
           notifyListeners();
           
           // Cache THIS selection
           await prefs.setString('featured_products_cache', jsonEncode(newFeatured.map((e)=>e.toJson()).toList()));
        } else {
           // If branch has no products, clear featured
           _featuredProducts = [];
           notifyListeners();
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
