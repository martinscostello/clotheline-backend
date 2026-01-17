import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'dart:convert'; // Added for JSON encoding/decoding

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

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

  // 1. Optimistic Local Load (Fast)
  Future<bool> loadFromStorage() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _isInitialized = true;
        return false;
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
         
         _isInitialized = true;
         notifyListeners();
         return true;
      }
      
      _isInitialized = true;
      return false; 
    } catch (e) {
      _isInitialized = true;
      return false;
    }
  }

  // 2. Background Validation (Network)
  Future<bool> validateSession() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) return false;

      final response = await _apiService.client.get(
        '/auth/verify',
        options: Options(headers: {'x-auth-token': token})
      );

      if (response.statusCode == 200) {
        final user = response.data['user'];
        // Update local storage with fresh data
        await _storage.write(key: 'user_role', value: user['role']?.toString() ?? 'user');
        await _storage.write(key: 'user_id', value: user['id']?.toString() ?? '');
        await _storage.write(key: 'is_master_admin', value: (user['isMasterAdmin'] ?? false).toString());
        if (user['permissions'] != null) {
          await _storage.write(key: 'user_permissions', value: jsonEncode(user['permissions']));
        }
        
        // Update memory
        _currentUser = user; 
        notifyListeners();
        return true;
      } else {
        // Token invalid - force logout
        await logout();
        return false;
      }
    } catch (e) {
      print("Session Validation Failed: $e");
      // If network error, KEEP user logged in (Optimistic).
      // Only logout if 401/403
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
         await logout();
         return false;
      }
      return true; // Assume valid if just offline
    }
  }

  // Deprecated - kept for compatibility if needed, but implementation redirects to new flow
  Future<bool> tryAutoLogin() async {
    final loaded = await loadFromStorage();
    if (loaded) {
      validateSession(); // Fire and forget
    }
    return loaded;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _apiService.client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        return _processAuthResponse(response.data);
      } else {
        throw Exception('Login Failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    try {
      final response = await _apiService.client.post('/auth/signup', data: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': 'user' // Default role
      });

      if (response.statusCode == 200) {
        // DOES NOT AUTO-LOGIN ANYMORE
        // Returns { msg: 'OTP sent', email: ... }
        return response.data;
      } else {
        throw Exception('Signup Failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<Map<String, dynamic>> verifyEmail(String email, String otp) async {
    try {
      final response = await _apiService.client.post('/auth/verify-email', data: {
        'email': email,
        'otp': otp
      });

      if (response.statusCode == 200) {
        // NOW we login and store tokens
        return _processAuthResponse(response.data);
      } else {
         throw Exception('Verification Failed');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // [NEW] Resend OTP
  Future<void> resendOtp(String email) async {
    try {
      final response = await _apiService.client.post('/auth/resend-otp', data: {
        'email': email
      });
      
      if (response.statusCode != 200) {
         throw Exception('Failed to resend OTP');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // Helper to store tokens and set user
  Future<Map<String, dynamic>> _processAuthResponse(Map<String, dynamic> data) async {
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
  }

  void _handleDioError(DioException e) {
    String message = 'Authentication failed';
    if (e.response != null && e.response!.data != null) {
      // Handle both string and json error responses
      final data = e.response!.data;
      if (data is Map && data.containsKey('msg')) {
        message = data['msg'];
      } else {
        message = data.toString();
      }
    }
    throw Exception(message);
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
