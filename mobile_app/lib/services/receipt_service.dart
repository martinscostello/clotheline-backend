import 'dart:typed_data';
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';

class ReceiptService {
  final ApiService _api = ApiService();

  Future<void> downloadReceipt(OrderModel order) async {
    try {
      final response = await _api.client.get(
        '/reports/invoice/${order.id}',
        options: Options(responseType: ResponseType.bytes)
      );
      
      final Uint8List bytes = Uint8List.fromList(response.data);
      await Printing.sharePdf(bytes: bytes, filename: 'invoice_${order.id.substring(order.id.length-6)}.pdf');
    } catch (e) {
      print("Error downloading receipt: $e");
      // Fallback? Or throw.
      throw Exception("Failed to download receipt");
    }
  }
}
