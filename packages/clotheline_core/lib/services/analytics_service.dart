import 'package:flutter/foundation.dart';
import 'package:clotheline_core/clotheline_core.dart';

class AnalyticsService extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  Map<String, dynamic>? _revenueStats;
  List<dynamic>? _topItems;
  bool _isLoading = false;

  Map<String, dynamic>? get revenueStats => _revenueStats;
  List<dynamic>? get topItems => _topItems;
  bool get isLoading => _isLoading;

  Future<void> fetchRevenueStats({String range = 'week', String? branchId, String? fulfillmentMode}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final query = '?range=$range'
          '${branchId != null ? '&branchId=$branchId' : ''}'
          '${fulfillmentMode != null ? '&fulfillmentMode=$fulfillmentMode' : ''}';
      final response = await _api.client.get('/analytics/revenue$query');
      if (response.statusCode == 200) {
        _revenueStats = response.data;
      }
    } catch (e) {
      debugPrint("Error fetching revenue stats: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTopItems({int limit = 5, String? branchId, String? fulfillmentMode}) async {
    // We can load this parallel to revenue if wanted
    try {
      final query = '?limit=$limit'
          '${branchId != null ? '&branchId=$branchId' : ''}'
          '${fulfillmentMode != null ? '&fulfillmentMode=$fulfillmentMode' : ''}';
      final response = await _api.client.get('/analytics/top-items$query');
      if (response.statusCode == 200) {
        _topItems = response.data;
        notifyListeners(); // Notify separately or together?
      }
    } catch (e) {
      debugPrint("Error fetching top items: $e");
    }
  }
}
