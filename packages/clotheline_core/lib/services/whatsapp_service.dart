import 'package:url_launcher/url_launcher.dart';
import 'package:clotheline_core/clotheline_core.dart';

class WhatsAppService {
  static Future<void> _launchWhatsApp(String phone, String message) async {
    // Format phone: remove leading +, ensure country code 234 if starts with 0
    String formattedPhone = phone.replaceAll('+', '').replaceAll(' ', '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '234${formattedPhone.substring(1)}';
    }

    final String encodedMsg = Uri.encodeComponent(message);
    
    // Try native scheme first (often more reliable on iOS if app is installed)
    final Uri nativeUrl = Uri.parse("whatsapp://send?phone=$formattedPhone&text=$encodedMsg");
    final Uri httpsUrl = Uri.parse("https://wa.me/$formattedPhone?text=$encodedMsg");

    try {
      if (await canLaunchUrl(nativeUrl)) {
        await launchUrl(nativeUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(httpsUrl)) {
        await launchUrl(httpsUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for web or if canLaunchUrl is being strict
        await launchUrl(httpsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print("Error launching WhatsApp: $e");
    }
  }

  static String _getBrandedName(String? branchName) {
    if (branchName == null) return 'Clotheline';
    if (branchName.toLowerCase().contains('abuja')) return 'Brimarck';
    return 'Clotheline';
  }

  static String _getDownloadLink() {
    // Shorter link for WhatsApp convenience
    return "https://www.brimarcglobal.com/clotheline-download.html";
  }

  static Future<void> sendOrderUpdate({
    required String phone,
    required String orderNumber,
    required double amount,
    required String status,
    String? guestName,
    String? branchName,
    String? logisticsType, // 'delivery' or 'pickup'
  }) async {
    final String name = guestName ?? "Customer";
    final String brand = _getBrandedName(branchName);
    final String shortId = orderNumber.length > 6 
        ? orderNumber.substring(orderNumber.length - 6).toUpperCase() 
        : orderNumber.toUpperCase();

    final String formattedAmount = CurrencyFormatter.format(amount);
    final String downloadUrl = _getDownloadLink();
    
    String message = "";
    final String normalizedStatus = status.toLowerCase();

    if (normalizedStatus == 'new' || normalizedStatus == 'pending') {
      message = 
        "Hello $name\n\n"
        "Your order $shortId at $brand has been recorded.\n"
        "Total: $formattedAmount\n"
        "Status: NEW\n\n"
        "Download our app: $downloadUrl\n\n"
        "Thank you for choosing $brand!";
    } else if (normalizedStatus == 'inprogress') {
      message = 
        "Hello $name\n\n"
        "Your order $shortId at $brand has been Updated.\n"
        "Status: InProgress\n\n"
        "Download our app: $downloadUrl\n\n"
        "Thank you for choosing $brand!";
    } else if (normalizedStatus == 'ready') {
      final String logisticsSuffix = (logisticsType?.toLowerCase() == 'delivery') ? "delivery" : "Pick up";
      message = 
        "Hello $name\n\n"
        "Your order $shortId Is now Ready for $logisticsSuffix\n\n"
        "Download our app: $downloadUrl\n\n"
        "Thank you for choosing $brand!";
    } else if (normalizedStatus == 'completed') {
       final String logisticsDone = (logisticsType?.toLowerCase() == 'delivery') ? "delivered" : "Picked up";
       message = 
        "Hello $name\n\n"
        "Your order $shortId has been $logisticsDone\n\n"
        "Download our app: $downloadUrl\n\n"
        "Thank you for choosing $brand!";
    } else if (normalizedStatus == 'cancelled') {
        message = 
        "Hello $name\n\n"
        "Your order $shortId has been cancelled\n\n"
        "Download our app: $downloadUrl\n\n"
        "Thank you for choosing $brand!";
    } else {
      // Fallback for any other status
      message = 
        "Hello $name\n\n"
        "Your order $shortId at $brand has been updated.\n"
        "Status: ${status.toUpperCase()}\n\n"
        "Download our app: $downloadUrl\n\n"
        "Thank you for choosing $brand!";
    }

    await _launchWhatsApp(phone, message);
  }

  static Future<void> contactSupport({
    required String orderNumber,
    String? branchName,
  }) async {
    const String supportPhone = '2348000000000'; 
    final String brand = _getBrandedName(branchName);
    final String shortId = orderNumber.length > 6 
        ? orderNumber.substring(orderNumber.length - 6).toUpperCase() 
        : orderNumber.toUpperCase();

    final String message = 
      "Hello $brand Support!\n\n"
      "I need help with my order #$shortId.\n\n"
      "Thank you!";

    await _launchWhatsApp(supportPhone, message);
  }

  static Future<void> sendProbationAnnouncement({
    required String phone,
    required String staffName,
    required String branchName,
  }) async {
    final String brand = _getBrandedName(branchName);
    final String message = 
      "Hello $staffName!\n\n"
      "Welcome to the $brand team!\n\n"
      "Your 3-month probation period has officially begun. We encourage you to be at your best performance during this time, as it will determine your permanent stay with the company.\n\n"
      "Your performance will be closely monitored, and we look forward to a great working relationship.\n\n"
      "Best of luck!";

    await _launchWhatsApp(phone, message);
  }

  static Future<void> sendStaffDocument({
    required String phone,
    required String staffName,
    required String documentType, // 'Pay Slip', 'ID Card', 'Agreement'
    required String branchName,
  }) async {
    final String brand = _getBrandedName(branchName);
    final String message = 
      "Hello $staffName,\n\n"
      "Attached is your $documentType from $brand.\n\n"
      "Please let us know if you have any questions.\n\n"
      "Thank you!";

    await _launchWhatsApp(phone, message);
  }

  static Future<void> sendTextReceipt({
    required String phone,
    required dynamic order,
    required String branchName,
  }) async {
    // resolve data
    String id = order is Map ? (order['_id'] ?? 'N/A') : order.id;
    String name = order is Map ? (order['guestInfo']?['name'] ?? 'Guest') : (order.guestName ?? (order.userName ?? 'Customer'));
    
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

    double subtotal = order is Map ? (order['subtotal'] as num?)?.toDouble() ?? 0.0 : order.subtotal;
    double deliveryFee = order is Map ? (order['deliveryFee'] as num?)?.toDouble() ?? 0.0 : order.deliveryFee;
    double total = order is Map ? (order['totalAmount'] as num?)?.toDouble() ?? 0.0 : order.totalAmount;
    String paymentMethod = order is Map ? (order['paymentMethod'] ?? 'cash') : (order.paymentMethod ?? 'cash');

    final String brand = _getBrandedName(branchName);
    final String shortId = id.length > 6 ? id.substring(id.length - 6).toUpperCase() : id.toUpperCase();
    
    String message = "*${brand.toUpperCase()}*\n";
    message += "Order #: $shortId\n";
    message += "Customer: $name\n";
    message += "Date: ${DateTime.now().toString().substring(0, 16)}\n";
    message += "------------------------\n\n";

    if (laundry.isNotEmpty) {
      message += "*LAUNDRY SERVICES*\n";
      for (var i in laundry) {
        message += "• ${i.item.name} (${i.serviceType?.name ?? 'Generic'}) x${i.quantity}\n";
        message += "  ${CurrencyFormatter.format(i.totalPrice)}\n";
      }
      message += "\n";
    }

    if (store.isNotEmpty) {
      message += "*STORE PRODUCTS*\n";
      for (var i in store) {
        message += "• ${i.product.name} x${i.quantity}\n";
        message += "  ${CurrencyFormatter.format(i.totalPrice)}\n";
      }
      message += "\n";
    }

    message += "------------------------\n";
    message += "Subtotal: ${CurrencyFormatter.format(subtotal)}\n";
    message += "Delivery Fee: ${CurrencyFormatter.format(deliveryFee)}\n";
    message += "*TOTAL: ${CurrencyFormatter.format(total)}*\n";
    message += "------------------------\n";
    message += "Payment: ${paymentMethod.toUpperCase()}\n\n";
    message += "Thank you for your patronage!";

    await _launchWhatsApp(phone, message);
  }
}
