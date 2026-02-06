import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add SharedPrefs
import 'api_service.dart';
import 'dart:convert'; // Added for JSON encoding/decoding
import 'push_notification_service.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Simple in-memory user cache for role checks
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool _isGuest = false;
  bool get isGuest => _isGuest;
  bool _isInitialized = false;

  // [BOOTSTRAP] Synchronous Hydration
  void hydrateSimpleProfile(Map<String, dynamic>? profile, String? role, {bool isGuest = false}) {
    _isGuest = isGuest;
    if (profile != null) {
      _currentUser = {
         ...profile,
         'role': role ?? 'user'
      };
      _isInitialized = true;
    }
  }
  
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

  Future<void> continueAsGuest() async {
    _isGuest = true;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    await prefs.setBool('is_logged_in', false);
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
      
      final prefs = await SharedPreferences.getInstance();
      _isGuest = prefs.getBool('is_guest') ?? false;

      
      // [FIX] Load Profile
      final name = await _storage.read(key: 'user_name');
      final email = await _storage.read(key: 'user_email');
      final avatarId = await _storage.read(key: 'user_avatar_id');
      
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
           'name': name ?? '',
           'email': email ?? '',
           'avatarId': avatarId,
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
        
        if (user['permissions'] != null) {
          await _storage.write(key: 'user_permissions', value: jsonEncode(user['permissions']));
        }
        
        // [FIX] Only overwrite local avatar if backend explicitly sends it
        if (user.containsKey('avatarId')) {
           await _storage.write(key: 'user_avatar_id', value: user['avatarId']?.toString() ?? '');
        } else {
           // Backend didn't send avatar (legacy/cached), but we might have it locally.
           // Inject it into the fresh 'user' object so the UI doesn't flicker/reset.
           final savedAvatar = await _storage.read(key: 'user_avatar_id');
           if (savedAvatar != null && savedAvatar.isNotEmpty) {
             user['avatarId'] = savedAvatar;
           }
        }
        
        _currentUser = user; 
        
        // [NEW] Sync Token on Auto-Login
        syncFcmToken();
        
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
        _isGuest = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('is_guest');
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
    String? branchId, // Add optional branchId
  }) async {
    try {
      final response = await _apiService.client.post('/auth/signup', data: {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': 'user', // Default role
        'branchId': branchId // Pass branchId
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

  // [NEW] Forgot Password
  Future<void> forgotPassword(String email) async {
    try {
      final response = await _apiService.client.post('/auth/forgot-password', data: {'email': email});
      if (response.statusCode != 200) throw Exception('Failed to request reset OTP');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // [NEW] Reset Password
  Future<void> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await _apiService.client.post('/auth/reset-password', data: {
        'email': email,
        'otp': otp,
        'newPassword': newPassword
      });
      if (response.statusCode != 200) throw Exception('Failed to reset password');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // [NEW] Change Password (Logged-in)
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _apiService.client.put('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword
      });
      if (response.statusCode != 200) throw Exception('Failed to update password');
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
    
    // [FIX] Persist Profile Data
    await _storage.write(key: 'user_name', value: user['name']?.toString() ?? '');
    await _storage.write(key: 'user_email', value: user['email']?.toString() ?? '');

    await _storage.write(key: 'user_name', value: user['name']?.toString() ?? '');
    await _storage.write(key: 'user_email', value: user['email']?.toString() ?? '');
    await _storage.write(key: 'user_avatar_id', value: user['avatarId']?.toString() ?? ''); // [FIX] Persist Avatar
    final prefs = await SharedPreferences.getInstance();
    
    // [FIX] Sync Avatar to SharedPrefs for Bootloader
    if (user['avatarId'] != null) {
      await prefs.setString('user_avatar_id', user['avatarId'].toString());
    } else {
      await prefs.remove('user_avatar_id');
    }
    
    // 1. Branch
    if (user['preferredBranch'] != null) {
       await prefs.setString('selected_branch_id', user['preferredBranch'].toString());
    }
    
    // 2. Optimistic Auth Flags (for Instant Launch)
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('saved_user_role', user['role']?.toString() ?? 'user');
    
    // [FIX] Persist Profile for Instant Launch (Bootloader)
    await prefs.setString('user_name', user['name']?.toString() ?? '');
    await prefs.setString('user_email', user['email']?.toString() ?? '');

    // Persist RBAC data
    await _storage.write(key: 'is_master_admin', value: (user['isMasterAdmin'] ?? false).toString());
    if (user['permissions'] != null) {
      await _storage.write(key: 'user_permissions', value: jsonEncode(user['permissions']));
    }

    _currentUser = user;
    
    // [NEW] Sync FCM Token in Background
    syncFcmToken();
    
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
    
    // Clear Optimistic Flags
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    
    _currentUser = null;
    _isGuest = false;
    await prefs.remove('is_guest');
    
    notifyListeners();
  }

  Future<void> deleteAccount(String password) async {
    try {
      final response = await _apiService.client.delete(
        '/auth/delete-account',
        data: {'password': password},
      );
      if (response.statusCode == 200) {
        await logout();
      } else {
        throw Exception("Failed to delete account");
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getUserRole() async {
    if (_currentUser != null) return _currentUser!['role'];
    return await _storage.read(key: 'user_role');
  }

  // [Check for Ghost Account]
  Future<bool> hasValidProfile() async {
    final name = await _storage.read(key: 'user_name');
    final email = await _storage.read(key: 'user_email');
    // If either is missing/empty, profile is invalid (Ghost)
    return name != null && name.isNotEmpty && email != null && email.isNotEmpty;
  }

  // [NEW] Sync FCM Token
  Future<void> syncFcmToken() async {
    try {
       // Get current FCM token
       String? token = await PushNotificationService.getToken();
       
       if (token != null) {
          // Send to backend
          // We use the existing client - the interceptor adds x-auth-token automatically 
          // if we are logged in (Implied since we call this after login)
          await _apiService.client.put('/auth/fcm-token', data: {
            'token': token
          });
          print("FCM Token Synced: $token");
       }
    } catch (e) {
      // Create a non-breaking error log
      print("FCM Sync Warning: $e"); 
    }
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

  Future<bool> deleteUser(String userId) async {
    try {
      final response = await _apiService.client.delete('/auth/$userId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error deleting user: $e");
      return false;
    }
  }

  Future<void> updateAvatar(String avatarId) async {
    try {
      final response = await _apiService.client.put('/auth/avatar', data: {
        'avatarId': avatarId
      });
      
      if (response.statusCode == 200) {
        if (_currentUser != null) {
          _currentUser!['avatarId'] = avatarId;
          
          // Also persist to storage so it's available on next boot
          await _storage.write(key: 'user_avatar_id', value: avatarId);
          
          // [FIX] Also sync to SharedPrefs for next cold boot
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_avatar_id', avatarId);
          
          notifyListeners();
        }
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
