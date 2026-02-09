import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/booking_models.dart';
import '../models/store_product.dart';

class ReceiptService {
  static Future<void> printReceipt({
    required String orderNumber,
    required String customerName,
    required String branchName,
    required List<CartItem> laundryItems,
    required List<StoreCartItem> storeItems,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required String paymentMethod,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text("CLOTHELINE", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Text("Laundry & Store", style: pw.TextStyle(fontSize: 10)),
                    pw.Text(branchName, style: pw.TextStyle(fontSize: 10)),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Order #: $orderNumber"),
              pw.Text("Customer: $customerName"),
              pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}"),
              pw.Text("Type: Walk-in POS"),
              pw.Divider(),
              
              if (laundryItems.isNotEmpty) ...[
                pw.Text("LAUNDRY SERVICES", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...laundryItems.map((i) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("${i.item.name} (${i.serviceType.name}) x${i.quantity}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("N${i.totalPrice.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 9)),
                  ],
                )),
                pw.SizedBox(height: 5),
              ],
              
              if (storeItems.isNotEmpty) ...[
                pw.Text("STORE PRODUCTS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...storeItems.map((i) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("${i.product.name} x${i.quantity}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("N${i.totalPrice.toStringAsFixed(0)}", style: const pw.TextStyle(fontSize: 9)),
                  ],
                )),
                pw.SizedBox(height: 5),
              ],
              
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Subtotal:"),
                  pw.Text("N${subtotal.toStringAsFixed(0)}"),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Delivery Fee:"),
                  pw.Text("N${deliveryFee.toStringAsFixed(0)}"),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text("N${total.toStringAsFixed(0)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.Divider(),
              pw.Text("Payment: ${paymentMethod.toUpperCase()}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text("Thank you for your patronage!", style: const pw.TextStyle(fontSize: 8)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
