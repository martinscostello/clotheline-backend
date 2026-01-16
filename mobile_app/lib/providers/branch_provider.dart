import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/branch_model.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';

class BranchProvider extends ChangeNotifier {
  Branch? _selectedBranch;
  List<Branch> _branches = [];
  bool _isLoading = true;

  Branch? get selectedBranch => _selectedBranch;
  List<Branch> get branches => _branches;
  bool get isLoading => _isLoading;

  BranchProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadCachedData(); // Fast local load
    fetchBranches(); // Background refresh
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
        await _loadSavedBranch(); 
        
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching branches: $e");
    }
  }

  Future<void> _loadSavedBranch() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selected_branch_id');
    
    if (savedId != null) {
      try {
        _selectedBranch = _branches.firstWhere((b) => b.id == savedId);
        // Sync CartService
        CartService().setBranch(savedId); 
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

  Future<bool> updateBranch(String id, Map<String, dynamic> data) async {
    try {
      final ApiService api = ApiService();
      final response = await api.client.put('/branches/$id', data: data);
      if (response.statusCode == 200) {
        await fetchBranches(); // Refresh list to get updated data
        return true;
      }
      return false;
    } catch (e) {
      print("Error updating branch: $e");
      return false;
    }
  }
}
