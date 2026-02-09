import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

class WhatsAppService {
  static Future<void> sendOrderUpdate({
    required String phone,
    required String orderNumber,
    required double amount,
    required String status,
    String? guestName,
  }) async {
    // Format phone: remove leading +, ensure country code 234 if starts with 0
    String formattedPhone = phone.replaceAll('+', '').replaceAll(' ', '');
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '234${formattedPhone.substring(1)}';
    }

    final String name = guestName ?? "Customer";
    final String message = Uri.encodeComponent(
      "Hello $name!\n\n"
      "Your order #$orderNumber at Clotheline has been recorded.\n"
      "Total: ₦${amount.toStringAsFixed(0)}\n"
      "Status: $status\n\n"
      "You can track your order here: https://clotheline.ng/track/$orderNumber\n\n"
      "Thank you for choosing Clotheline!"
    );

    final Uri whatsappUrl = Uri.parse("https://wa.me/$formattedPhone?text=$message");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $whatsappUrl';
    }
  }
}
