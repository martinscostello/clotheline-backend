import 'api_service.dart';

class ReportService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> fetchFinancials({DateTime? startDate, DateTime? endDate, String? branchId}) async {
    try {
      Map<String, dynamic> query = {};
      if (startDate != null && endDate != null) {
        query['startDate'] = startDate.toIso8601String();
        query['endDate'] = endDate.toIso8601String();
      }
      if (branchId != null) {
        query['branchId'] = branchId;
      }

      final response = await _api.client.get('/reports/financials', queryParameters: query);
      return response.data;
    } catch (e) {
      print("Error fetching financials: $e");
      throw Exception("Failed to load financial reports");
    }
  }
}
