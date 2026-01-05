import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Simple in-memory user cache for role checks
  Map<String, dynamic>? _currentUser;

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
        await _storage.write(key: 'user_role', value: user['role']);
        await _storage.write(key: 'user_id', value: user['id']);

        _currentUser = user;
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
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getUserRole() async {
    if (_currentUser != null) return _currentUser!['role'];
    return await _storage.read(key: 'user_role');
  }
}
