import 'package:url_launcher/url_launcher.dart';
import '../utils/currency_formatter.dart';

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
}
