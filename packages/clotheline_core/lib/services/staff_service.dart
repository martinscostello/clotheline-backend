import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'api_service.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:url_launcher/url_launcher.dart';

class StaffService {
  final ApiService _apiService = ApiService();

  Future<String?> uploadImage(String filePath) async {
    try {
      MultipartFile multipartFile;
      if (kIsWeb) {
        final file = File(filePath);
        final bytes = await file.readAsBytes();
        multipartFile = MultipartFile.fromBytes(bytes, filename: filePath.split('/').last);
      } else {
        multipartFile = await MultipartFile.fromFile(filePath);
      }

      final formData = FormData.fromMap({
        'image': multipartFile,
      });
      final response = await _apiService.client.post(
        '/upload', 
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );
      if (response.statusCode == 200) {
        return response.data['filePath'];
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Staff>> fetchStaff({String? branchId}) async {
    try {
      final url = branchId != null ? '/staff?branchId=$branchId' : '/staff';
      final response = await _apiService.client.get(url);
      if (response.statusCode == 200) {
        return (response.data as List).map((json) => Staff.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Staff> createStaff(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.client.post('/staff', data: data);
      return Staff.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Staff> updateStaff(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.client.put('/staff/$id', data: data);
      return Staff.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Staff> addWarning(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.client.post('/staff/warning', data: data);
      return Staff.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Staff> removeWarning(String staffId, String warningId) async {
    try {
      final response = await _apiService.client.post('/staff/warning/remove', data: {
        'staffId': staffId,
        'warningId': warningId,
      });
      return Staff.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> archiveStaff(String id, String reason) async {
    try {
      await _apiService.client.put('/staff/$id/archive', data: {'archiveReason': reason});
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      await _apiService.client.delete('/staff/$id');
    } catch (e) {
      rethrow;
    }
  }

  // --- WhatsApp Integration ---
  
  Future<void> sendWarningToWhatsApp({
    required String phone,
    required String staffName,
    required String position,
    required String branchName,
    required String severity,
    required String reason,
    String? notes,
    required int warningCount,
  }) async {
    // Sanitize phone (must start with country code, remove +)
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('234')) {
        // Assume Nigeria if no prefix
        cleanPhone = '234${cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone}';
    }

    final branchCompanyName = branchName.toLowerCase().contains('abuja') ? 'Brimarck' : 'Clotheline';
    
    final message = '''Dear $staffName,
This is an official warning from $branchCompanyName $branchName branch.

Position: $position
Severity: $severity
Reason: $reason
${notes != null && notes.isNotEmpty ? 'Notes: $notes\n' : ''}
Please treat this matter seriously.
You currently have $warningCount warning(s) on record.

Management.''';

    // Use queryParameters to handle encoding automatically
    final nativeUri = Uri.parse('whatsapp://send').replace(queryParameters: {
      'phone': cleanPhone,
      'text': message,
    });
    
    final webUri = Uri.parse('https://wa.me/$cleanPhone').replace(queryParameters: {
      'text': message,
    });

    print("Attempting to launch WhatsApp. Phone: $cleanPhone");

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else {
        print("Native WhatsApp not found, trying web fallback: $webUri");
        // For web fallback, use platformDefault mode which is often more reliable for opening browsing intents
        if (await canLaunchUrl(webUri)) {
             await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
             // As a last resort, try launching without checking canLaunchUrl, sometimes check fails but launch works
             try {
                await launchUrl(webUri, mode: LaunchMode.externalApplication);
             } catch (e) {
                throw 'Could not launch WhatsApp (Web fallback failed: $e)';
             }
        }
      }
    } catch (e) {
      print("WhatsApp launch error: $e");
      throw Exception('Could not launch WhatsApp: $e');
    }
  }

  Future<Staff> recordPayment(String staffId, double amount, String method, String reference) async {
    try {
      final response = await _apiService.client.post('/staff/payment', data: {
        'staffId': staffId,
        'amount': amount,
        'paymentDate': DateTime.now().toIso8601String(),
        'method': method,
        'reference': reference
      });
      return Staff.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}
