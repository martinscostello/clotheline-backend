import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

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
      // Optional: Show toast if context was available, but we'll leave it to caller or internal print for now.
    }
  }

  static Future<void> sendOrderUpdate({
    required String phone,
    required String orderNumber,
    required double amount,
    required String status,
    String? guestName,
  }) async {
    final String name = guestName ?? "Customer";
    final String shortId = orderNumber.length > 6 
        ? orderNumber.substring(orderNumber.length - 6).toUpperCase() 
        : orderNumber.toUpperCase();

    final String message = 
      "Hello $name\n\n"
      "Your order #$shortId at Clotheline has been recorded.\n"
      "Status: $status\n\n"
      "You can download our mobile app from Google Playstore and Apple App Store\n"
      "\"Clotheline\"\n\n"
      "Thank you for choosing Clotheline";

    await _launchWhatsApp(phone, message);
  }

  static Future<void> contactSupport({
    required String orderNumber,
  }) async {
    const String supportPhone = '2348000000000'; // TODO: Get from dynamic settings?
    final String shortId = orderNumber.length > 6 
        ? orderNumber.substring(orderNumber.length - 6).toUpperCase() 
        : orderNumber.toUpperCase();

    final String message = 
      "Hello Clotheline Support!\n\n"
      "I need help with my order #$shortId.\n\n"
      "Thank you!";

    await _launchWhatsApp(supportPhone, message);
  }
}
