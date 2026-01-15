import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiService {
  // Use localhost for iOS Simulator, or 10.0.2.2 for Android Emulator
  // Use localhost for iOS Simulator, or 10.0.2.2 for Android Emulator
  // Use localhost for iOS Simulator, or 10.0.2.2 for Android Emulator
  static String get baseUrl {
    return 'https://clotheline-api.onrender.com/api'; // Production
    // return 'http://localhost:10000/api'; // Local Development (Simulator)
    // return 'http://YOUR_Mac_IP:10000/api'; // Local Development (Physical Device)
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

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          // Wrap in try-catch to prevent crash if storage is inaccessible (iOS lock state)
          final token = await _storage.read(key: 'auth_token').catchError((e) {
             debugPrint("WARN: Failed to read auth_token from SecureStorage: $e");
             return null;
          });
          
          if (token != null) {
            options.headers['x-auth-token'] = token;
          }
        } catch (e) {
          debugPrint("CRITICAL: SecureStorage read error: $e");
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle global errors (like 401 Unauthorized) here
        if (e.response != null) {
           debugPrint("API Error: ${e.response?.statusCode} - ${e.message}");
        }
        return handler.next(e);
      },
    ));
  }

  Dio get client => _dio;
}
