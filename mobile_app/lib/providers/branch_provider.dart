import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/branch_model.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/laundry_service.dart';
import 'package:dio/dio.dart';

class BranchProvider extends ChangeNotifier {
  Branch? _selectedBranch;
  List<Branch> _branches = [];
  bool _isLoading = true;

  Branch? get selectedBranch => _selectedBranch;
  List<Branch> get branches {
    // If we have a user and they are restricted, filter the branches
    if (_authService != null && _authService!.currentUser != null) {
      final user = _authService!.currentUser!;
      final bool isMaster = user['isMasterAdmin'] == true;
      final bool isAdmin = user['role'] == 'admin';
      final List<dynamic>? assigned = user['assignedBranches'];

      if (isAdmin && !isMaster && assigned != null && assigned.isNotEmpty) {
        return _branches.where((b) => assigned.contains(b.id)).toList();
      }
    }
    return _branches;
  }

  AuthService? _authService;
  void updateAuth(AuthService auth) {
    _authService = auth;
    notifyListeners();
  }
  bool get isLoading => _isLoading;

  BranchProvider() {
    // defer init to avoid async constructor issues, or rely on bootstrap
  }
  
  void hydrateFromBootstrap(List<Branch> branches, String? selectedId) {
     _branches = branches;
     if (selectedId != null && branches.isNotEmpty) {
        try {
           _selectedBranch = branches.firstWhere((b) => b.id == selectedId);
           // Also sync sub-services immediately if possible, or let UI trigger it
           // LaundryService().fetchServices(branchId: selectedId); // Careful with Singleton logic order
        } catch (_) {}
     }
     _isLoading = false;
  }

  Future<void> _init() async {
     // Legacy Fallback if no bootstrap
     if (_branches.isEmpty) {
        await _loadCachedData();
        fetchBranches();
     }
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load Cached Branches
    final String? branchesJson = prefs.getString('cached_branches');
    if (branchesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(branchesJson); // Requires dart:convert
        _branches = decoded.map((json) => Branch.fromJson(json)).toList();
      } catch (e) {
        print("Error parsing cached branches: $e");
      }
    }

    // 2. Load Selected Branch ID
    final savedId = prefs.getString('selected_branch_id');
    if (savedId != null && _branches.isNotEmpty) {
      try {
        _selectedBranch = _branches.firstWhere((b) => b.id == savedId);
        // Sync CartService
        CartService().setBranch(savedId);
      } catch (e) {
        // ID might not exist in cache logic
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchBranches({bool force = false}) async {
    try {
      final ApiService api = ApiService();
      final response = await api.client.get('/branches');
      if (response.statusCode == 200) {
        _branches = (response.data as List).map((json) => Branch.fromJson(json)).toList();
        
        // Cache it
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('cached_branches', jsonEncode(response.data));

        // Re-validate selection
        await loadSavedBranch(); 
        
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching branches: $e");
    }
  }

  Future<void> loadSavedBranch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selected_branch_id');
    
    if (savedId != null) {
      try {
        _selectedBranch = _branches.firstWhere((b) => b.id == savedId);
        // Sync CartService & Data
        CartService().setBranch(savedId);
        LaundryService().fetchServices(branchId: savedId); 
      } catch (e) {
        // Saved branch might be deleted or not loaded yet
      }
    }
    
    // Strict Logic: If no saved branch, DO NOT default. Leave _selectedBranch as null.
    // This allows the app to prompt the user (via AuthCheckWrapper -> BranchSelectionScreen).
  }

  Future<void> selectBranch(Branch branch) async {
    _selectedBranch = branch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_branch_id', branch.id);
    
    // Trigger Data Refresh for new Branch
    await LaundryService().fetchServices(branchId: branch.id);
    CartService().setBranch(branch.id); // Also sync Cart
    
    notifyListeners();
  }

  Future<bool> createBranch(Map<String, dynamic> data) async {
    try {
      final ApiService api = ApiService();
      final response = await api.client.post('/branches', data: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchBranches();
        return true;
      }
      return false;
    } catch (e) {
      print("Error creating branch: $e");
      return false;
    }
  }

  Future<bool> seedBranches() async {
    try {
      final ApiService api = ApiService();
      // POST to /branches/seed
      final response = await api.client.post('/branches/seed');
      if (response.statusCode == 200) {
        await fetchBranches(force: true);
        return true;
      }
      return false;
    } catch (e) {
      print("Error seeding branches: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> updateBranch(String id, Map<String, dynamic> data) async {
    try {
      final ApiService api = ApiService();
      // Debug
      print("Sending PUT to /branches/$id with data: $data");

      final response = await api.client.put('/branches/$id', data: data);
      
      print("Update Response: ${response.statusCode} - ${response.data}");

      if (response.statusCode == 200) {
        await fetchBranches(); // Refresh list to get updated data
        return {'success': true};
      }
      return {
        'success': false, 
        'message': "Failed: ${response.statusCode} - ${response.data['msg'] ?? response.data['message'] ?? 'Unknown Error'}"
      };
    } catch (e) {
      print("Error updating branch: $e");
      if (e is DioException) {
         return {
           'success': false,
           'message': "DioError: ${e.response?.statusCode ?? 'NoStatus'} - ${e.response?.data ?? e.message}"
         };
      }
      return {'success': false, 'message': "Exception: $e"};
    }
  }
}
