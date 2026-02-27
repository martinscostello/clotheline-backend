import 'package:flutter/foundation.dart';
import 'package:clotheline_core/clotheline_core.dart';

class PromotionService extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<dynamic> _promotions = [];
  bool _isLoading = false;

  List<dynamic> get promotions => _promotions;
  bool get isLoading => _isLoading;

  Future<void> fetchPromotions() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.client.get('/promotions');
      if (response.statusCode == 200) {
        _promotions = response.data;
      }
    } catch (e) {
      debugPrint("Error list promos: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createPromotion(Map<String, dynamic> data) async {
    try {
      final response = await _api.client.post('/promotions', data: data);
      if (response.statusCode == 200) {
        _promotions.insert(0, response.data);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Error create promo: $e");
    }
    return false;
  }

  Future<bool> deletePromotion(String id) async {
    try {
       await _api.client.delete('/promotions/$id');
       _promotions.removeWhere((p) => p['_id'] == id);
       notifyListeners();
       return true;
    } catch (e) {
       debugPrint("Delete promo error: $e");
    }
    return false;
  }
}
