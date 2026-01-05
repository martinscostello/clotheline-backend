import 'package:flutter/material.dart';
import 'package:laundry_app/services/api_service.dart';
import '../models/service_model.dart';

class LaundryService extends ChangeNotifier {
  static final LaundryService _instance = LaundryService._internal();
  factory LaundryService() => _instance;
  LaundryService._internal();

  final ApiService _apiService = ApiService();

  List<ServiceModel> _services = [];
  List<ServiceModel> get services => List.unmodifiable(_services);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> fetchServices() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/services');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _services = data.map((json) => ServiceModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint("Error fetching services: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Find a service by ID or Name (helper)
  ServiceModel? getServiceByName(String name) {
    try {
       return _services.firstWhere((s) => s.name.toLowerCase().contains(name.toLowerCase()));
    } catch (e) {
      return null;
    }
  }
}
