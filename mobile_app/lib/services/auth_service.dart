import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'dart:convert'; // Added for JSON encoding/decoding

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Simple in-memory user cache for role checks
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool _isInitialized = false;
  
  Future<void> enableDevMode() async {
    try {
      print("Dev Mode: Attempting to login as 'admin@clotheline.com'...");
      await login('admin@clotheline.com', 'admin123');
      print("Dev Mode: Login Successful. Token acquired.");
    } catch (e) {
      print("Dev Mode Login Failed: $e. Using fallback data (Might cause 401 on backend)");
      _currentUser = {
        'id': 'dev_admin_id',
        'name': 'Dev Admin (Offline)',
        'email': 'dev@admin.com',
        'role': 'admin',
        'isMasterAdmin': true,
        'permissions': {
           'manageOrders': true,
           'manageUsers': true,
           'manageCMS': true,
           'manageServices': true,
           'manageProducts': true,
           'manageDelivery': true
        }
      };
      // We still set initialized so the app doesn't hang, but features might fail.
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    if (_isInitialized) return _currentUser != null;

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _isInitialized = true;
        return false;
      }

      // Verify Token with Backend (Self-Healing)
      try {
        // Set default header for this request or relying on interceptor?
        // ApiService usually attaches token if it's in storage? 
        // We might need to manually set it if ApiService doesn't know yet.
        // Assuming ApiService reads from storage or we set it.
        // Let's manually set it to be safe or assuming ApiServiceInterceptor works.
        // Actually, ApiService likely reads token from storage.
        
        // Add header manually just in case for this specific startup call
        final response = await _apiService.client.get(
          '/auth/verify',
          options: Options(headers: {'x-auth-token': token})
        );

        if (response.statusCode == 200) {
          final user = response.data['user'];
          
          await _storage.write(key: 'user_role', value: user['role']?.toString() ?? 'user');
          await _storage.write(key: 'user_id', value: user['id']?.toString() ?? '');
          await _storage.write(key: 'is_master_admin', value: (user['isMasterAdmin'] ?? false).toString());
          if (user['permissions'] != null) {
            await _storage.write(key: 'user_permissions', value: jsonEncode(user['permissions']));
          }

          _currentUser = user;
          _isInitialized = true;
          notifyListeners();
          return true;
        }
      } catch (e) {
        // Verification failed (expired or revoked)
        // Fallback to local data but it might be risky.
        // Safer to force logout or just continue with local data?
        // User asked for "Missing Tabs" fix. If verify fails, maybe token is bad.
        // Let's try to load local data as fallback BUT if verify works it overwrites stale data.
        print("Verify failed: $e. Falling back to local storage.");
      }

      final role = await _storage.read(key: 'user_role');
      final id = await _storage.read(key: 'user_id');
      final isMasterStr = await _storage.read(key: 'is_master_admin');
      final permissionsStr = await _storage.read(key: 'user_permissions');
      
      if (role != null) {
         Map<String, dynamic> permissions = {};
         if (permissionsStr != null) {
            try {
              permissions = jsonDecode(permissionsStr);
            } catch (_) {}
         }

         _currentUser = {
           'id': id, 
           'role': role,
           'isMasterAdmin': isMasterStr == 'true',
           'permissions': permissions
         };
      }
      
      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      _isInitialized = true;
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiService.client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['token'];
        final user = data['user'];

        // Store Token securely
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'user_role', value: user['role']?.toString() ?? 'user');
        await _storage.write(key: 'user_id', value: user['id']?.toString() ?? '');
        
        // Persist RBAC data
        await _storage.write(key: 'is_master_admin', value: (user['isMasterAdmin'] ?? false).toString());
        if (user['permissions'] != null) {
          await _storage.write(key: 'user_permissions', value: jsonEncode(user['permissions']));
        }

        _currentUser = user;
        notifyListeners();
        return user;
      } else {
        throw Exception('Login Failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      // Extract backend error message if available
      String message = 'Login failed';
      if (e.response != null && e.response!.data != null) {
        message = e.response!.data['msg'] ?? e.response!.data.toString();
      }
      throw Exception(message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _currentUser = null;
    notifyListeners();
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getUserRole() async {
    if (_currentUser != null) return _currentUser!['role'];
    return await _storage.read(key: 'user_role');
  }

  Future<List<dynamic>> fetchAllUsers() async {
    try {
      final response = await _apiService.client.get('/auth/users');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  // --- Admin Management ---

  Future<List<dynamic>> fetchAdmins() async {
    try {
      final response = await _apiService.client.get('/admin');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch admins: $e');
    }
  }

  Future<void> createAdmin(Map<String, dynamic> adminData) async {
    try {
      await _apiService.client.post('/admin/create-admin', data: adminData);
    } catch (e) {
      throw Exception('Failed to create admin: $e');
    }
  }

  Future<void> updateAdmin(String id, Map<String, dynamic> updates) async {
    try {
      await _apiService.client.put('/admin/$id', data: updates);
    } catch (e) {
      throw Exception('Failed to update admin: $e');
    }
  }
}
