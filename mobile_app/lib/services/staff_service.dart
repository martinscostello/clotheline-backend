import 'package:dio/dio.dart';
import 'api_service.dart';
import '../models/staff_model.dart';
import 'package:url_launcher/url_launcher.dart';

class StaffService {
  final ApiService _apiService = ApiService();

  Future<String?> uploadImage(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      final response = await _apiService.client.post('/upload', data: formData);
      if (response.statusCode == 200) {
        return response.data['filePath'];
      }
      return null;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
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
      throw Exception('Failed to fetch staff: $e');
    }
  }

  Future<Staff> createStaff(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.client.post('/staff', data: data);
      return Staff.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to create staff: $e');
    }
  }

  Future<Staff> updateStaff(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.client.put('/staff/$id', data: data);
      return Staff.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to update staff: $e');
    }
  }

  Future<Staff> addWarning(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.client.post('/staff/warning', data: data);
      return Staff.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to add warning: $e');
    }
  }

  Future<void> archiveStaff(String id, String reason) async {
    try {
      await _apiService.client.put('/staff/$id/archive', data: {'archiveReason': reason});
    } catch (e) {
      throw Exception('Failed to archive staff: $e');
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      await _apiService.client.delete('/staff/$id');
    } catch (e) {
      throw Exception('Failed to delete staff: $e');
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

    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$cleanPhone?text=$encodedMessage';
    
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch WhatsApp');
    }
  }
}
