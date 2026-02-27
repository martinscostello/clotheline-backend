import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';


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
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
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
      onError: (DioException e, handler) async {
        // Handle global errors (like 401 Unauthorized) here
        if (e.response != null) {
           debugPrint("API Error: ${e.response?.statusCode} - ${e.message}");
        }

        // --- RETRY LOGIC ---
        // Retry on connection errors or 5xx server errors
        bool shouldRetry = e.type == DioExceptionType.connectionTimeout ||
                           e.type == DioExceptionType.sendTimeout || 
                           e.type == DioExceptionType.receiveTimeout ||
                           e.type == DioExceptionType.connectionError ||
                           (e.response != null && e.response!.statusCode! >= 500);

        if (shouldRetry) {
          final RequestOptions requestOptions = e.requestOptions;
          // Check previous attempts
          int attempts = requestOptions.extra['retry_attempts'] ?? 0;
          if (attempts < 3) {
            attempts++;
            requestOptions.extra['retry_attempts'] = attempts;
            
            // Exponential Backoff: 1s, 2s, 4s
            final delay = Duration(seconds: (1 << (attempts - 1))); 
            debugPrint("Retrying request: ${requestOptions.path} (Attempt $attempts) in ${delay.inSeconds}s...");
            
            await Future.delayed(delay);

            try {
              final response = await _dio.fetch(requestOptions);
              return handler.resolve(response);
            } catch (e) {
              // Parse new error? The interceptor will start over for new error?
              // No, _dio.fetch triggers interceptors again.
              // We need to return the new error or let it bubble?
              // If _dio.fetch throws, we are in catch.
              return handler.next(e is DioException ? e : DioException(requestOptions: requestOptions, error: e));
            }
          }
        }

        return handler.next(e);
      },
    ));
  }

  Dio get client => _dio;
}
