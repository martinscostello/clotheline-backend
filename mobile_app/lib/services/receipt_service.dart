import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/booking_models.dart';
import '../models/store_product.dart';

class ReceiptService {
  static String _truncate(String text, int length) {
    if (text.length <= length) return text;
    return '${text.substring(0, length)}...';
  }

  static String _getBrandedName(String? branchName) {
    if (branchName == null) return 'CLOTHELINE';
    if (branchName.toLowerCase().contains('abuja')) return 'Brimarck';
    return 'CLOTHELINE';
  }

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
    final String brand = _getBrandedName(branchName);

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
                    pw.Text(brand.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                    pw.Text("Laundry & Store", style: pw.TextStyle(fontSize: 10)),
                    pw.Text(branchName, style: pw.TextStyle(fontSize: 10)),
                    pw.Divider(),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Order #: ${orderNumber.length > 6 ? orderNumber.substring(orderNumber.length - 6).toUpperCase() : orderNumber.toUpperCase()}"),
              pw.Text("Customer: $customerName"),
              pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}"),
              pw.Text("Type: Walk-in POS"),
              pw.Divider(),
              
              if (laundryItems.isNotEmpty) ...[
                pw.Text("LAUNDRY SERVICES", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ...laundryItems.map((i) => pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(_truncate("${i.item.name} (${i.serviceType.name}) x${i.quantity}", 28), style: const pw.TextStyle(fontSize: 9), overflow: pw.TextOverflow.clip),
                    ),
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
                    pw.Expanded(
                      child: pw.Text(_truncate("${i.product.name} x${i.quantity}", 28), style: const pw.TextStyle(fontSize: 9), overflow: pw.TextOverflow.clip),
                    ),
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

  static Future<void> printReceiptFromOrder(dynamic order) async {
    // Handle both OrderModel and Map (from API)
    String id = order is Map ? (order['_id'] ?? 'N/A') : order.id;
    String name = order is Map ? (order['guestInfo']?['name'] ?? 'Guest') : (order.guestName ?? (order.userName ?? 'Customer'));
    String branch = order is Map ? (order['branchId'] ?? 'Clotheline') : (order.branchId ?? 'Clotheline');
    
    List<CartItem> laundry = [];
    List<StoreCartItem> store = [];
    
    final items = order is Map ? (order['items'] as List? ?? []) : order.items;
    for (var item in items) {
      if (item is Map) {
         if (item['itemType'] == 'Service') {
            laundry.add(CartItem(
              item: ClothingItem(id: item['itemId'] ?? '', name: item['name'] ?? '', basePrice: (item['price'] as num?)?.toDouble() ?? 0.0),
              serviceType: ServiceType(id: item['serviceType'] ?? '', name: item['serviceType'] ?? '', priceMultiplier: 1.0),
              quantity: item['quantity'] ?? 1,
            ));
         } else {
            store.add(StoreCartItem(
              product: StoreProduct(id: item['itemId'] ?? '', name: item['name'] ?? '', price: (item['price'] as num?)?.toDouble() ?? 0.0, originalPrice: (item['price'] as num?)?.toDouble() ?? 0.0, description: '', imageUrls: [], category: 'Generic', stockLevel: 0, variants: []),
              quantity: item['quantity'] ?? 1,
            ));
         }
      } else {
        if (item.itemType == 'Service') {
          laundry.add(CartItem(
            item: ClothingItem(id: item.itemId, name: item.name, basePrice: item.price),
            serviceType: ServiceType(id: item.serviceType ?? 'Standard', name: item.serviceType ?? 'Standard'),
            quantity: item.quantity,
          ));
        } else {
          store.add(StoreCartItem(
            product: StoreProduct(id: item.itemId, name: item.name, price: item.price, originalPrice: item.price, description: '', imageUrls: [], category: 'Generic', stockLevel: 0, variants: []),
            quantity: item.quantity,
          ));
        }
      }
    }

    await printReceipt(
      orderNumber: id,
      customerName: name,
      branchName: branch,
      laundryItems: laundry,
      storeItems: store,
      subtotal: order is Map ? (order['subtotal'] as num?)?.toDouble() ?? 0.0 : order.subtotal,
      deliveryFee: order is Map ? (order['deliveryFee'] as num?)?.toDouble() ?? 0.0 : order.deliveryFee,
      total: order is Map ? (order['totalAmount'] as num?)?.toDouble() ?? 0.0 : order.totalAmount,
      paymentMethod: order is Map ? (order['paymentMethod'] ?? 'cash') : (order.paymentMethod ?? 'cash'),
    );
  }
}
