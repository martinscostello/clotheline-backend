import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';

class ReportProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Data Holders
  Map<String, dynamic>? _financials;
  Map<String, dynamic>? _analytics;
  List<dynamic> _expenses = [];
  List<dynamic> _goals = [];
  String? _error; // [NEW]

  // Getters
  Map<String, dynamic>? get financials => _financials;
  Map<String, dynamic>? get analytics => _analytics;
  List<dynamic> get expenses => _expenses;
  List<dynamic> get goals => _goals;
  String? get error => _error; // [NEW]

  // Filters
  String _rangeLabel = "This Month";
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedBranchId; // Null = All Branches

  String get rangeLabel => _rangeLabel;
  String? get selectedBranchId => _selectedBranchId;

  // Constructor
  ReportProvider() {
    // Set default range to This Month
    _updateDateRange("This Month");
  }

  void setBranch(String? branchId) {
    _selectedBranchId = branchId;
    notifyListeners();
    refreshAll();
  }

  void setDateRange(String rangeLabel) {
    _rangeLabel = rangeLabel;
    _updateDateRange(rangeLabel);
    notifyListeners();
    refreshAll();
  }

  void _updateDateRange(String label) {
    final now = DateTime.now();
    if (label == "Today") {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = now;
    } else if (label == "This Week") {
      _startDate = now.subtract(Duration(days: now.weekday - 1));
      _endDate = now;
    } else if (label == "This Month") {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
    } else if (label == "This Year") {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = now;
    } else {
      _startDate = null; // All Time
      _endDate = null;
    }
  }
  
  void setCustomRange(DateTime start, DateTime end) {
      _rangeLabel = "Custom";
      _startDate = start;
      _endDate = end;
      notifyListeners();
      refreshAll();
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      _error = null; // Reset
      await Future.wait([
        fetchFinancials(),
        fetchAnalytics(),
        fetchExpenses(),
        fetchGoals()
      ]);
    } catch (e) {
      print("Error refreshing reports: $e");
      // Basic extraction of dio error message if available, else string
      // Assuming DioException is type of e if using Dio
      if (e.toString().contains("response")) {
         // Try to find status code or message?? 
         // For now just show string, or cast if we import Dio
      }
      _error = e.toString().replaceAll("DioException", "Error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> fetchFinancials() async {
      final params = _buildParams();
      final res = await _api.client.get('/reports/financials', queryParameters: params);
      _financials = res.data;
  }

  Future<void> fetchAnalytics() async {
      final params = _buildParams();
      final res = await _api.client.get('/reports/analytics', queryParameters: params);
      _analytics = res.data;
  }
  
  Future<void> fetchExpenses() async {
       // separate params if needed, but expenses usually obey same filters
       final params = _buildParams();
       final res = await _api.client.get('/reports/expenses', queryParameters: params);
       _expenses = res.data;
  }
  
  Future<void> fetchGoals() async {
          // Goals usually filtered by branch only, less so by date range (as they have their own period)
          // But we pass branchId
          final Map<String, dynamic> params = {};
          if (_selectedBranchId != null) params['branchId'] = _selectedBranchId;
          
          final res = await _api.client.get('/reports/goals', queryParameters: params);
          _goals = res.data;
  }

  Map<String, dynamic> _buildParams() {
    final Map<String, dynamic> params = {};
    if (_startDate != null) params['startDate'] = _startDate!.toIso8601String();
    if (_endDate != null) params['endDate'] = _endDate!.toIso8601String();
    if (_selectedBranchId != null) params['branchId'] = _selectedBranchId;
    return params;
  }
  
  // ACTIONS
  
  Future<bool> addExpense(Map<String, dynamic> data) async {
      try {
          await _api.client.post('/reports/expenses', data: data);
          fetchExpenses(); // Refresh list
          fetchFinancials(); // Refresh totals
          return true;
      } catch (e) {
          return false;
      }
  }
  
  Future<bool> addGoal(Map<String, dynamic> data) async {
       try {
           await _api.client.post('/reports/goals', data: data);
           fetchGoals();
           fetchFinancials(); // Update progress
           return true;
       } catch (e) {
           return false;
       }
  }
}
