import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiService {
  // Use localhost for iOS Simulator, or 10.0.2.2 for Android Emulator
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5001/api'; // Web localhost
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5001/api'; // Android Emulator
    }
    return 'http://localhost:5001/api'; // iOS Simulator
  }
  
  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle global errors (like 401 Unauthorized) here
        print("API Error: ${e.response?.statusCode} - ${e.message}");
        return handler.next(e);
      },
    ));
  }

  Dio get client => _dio;
}
