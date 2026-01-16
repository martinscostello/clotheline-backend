import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  List<String> _favoriteIds = [];
  List<String> get favoriteIds => List.unmodifiable(_favoriteIds);

  bool _isInitialized = false;

  Future<void> loadFavorites() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _favoriteIds = prefs.getStringList('favorite_product_ids') ?? [];
    } catch (e) {
      debugPrint("Error loading favorites: $e");
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(String productId) async {
    if (!_isInitialized) await loadFavorites();

    if (_favoriteIds.contains(productId)) {
      _favoriteIds.remove(productId);
    } else {
      _favoriteIds.add(productId);
    }

    notifyListeners();
    _saveToDisk();
  }

  bool isFavorite(String productId) {
    return _favoriteIds.contains(productId);
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorite_product_ids', _favoriteIds);
    } catch (e) {
      debugPrint("Error saving favorites: $e");
    }
  }
}
