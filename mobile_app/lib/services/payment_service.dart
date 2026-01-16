import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'api_service.dart';

class PaymentService {
  final ApiService _api = ApiService();
  
  // Ideally get this from backend init
  String publicKey = "pk_test_xxxxxxxxxxxxxxxxxxxxxxxx"; 

  // initialize method not needed for flutter_paystack_plus as it's static call
  Future<void> initialize(String key) async {
    publicKey = key;
  }

  Future<bool> processPayment(BuildContext context, {
    required String orderId, 
    required String email
  }) async {
    try {
      // 1. Initialize on Backend (Securely)
      final initResponse = await _api.client.post('/payments/initialize', data: {
        'orderId': orderId,
        'provider': 'paystack'
      });

      final data = initResponse.data;
      final String authorizationUrl = data['authorization_url'];
      final String reference = data['reference'];

      if (authorizationUrl.isEmpty) {
        throw Exception("Failed to get authorization URL");
      }

      // 2. Open WebView for Payment (Standard Checkout)
      final bool success = await _openPaymentWebView(context, authorizationUrl, reference);
      
      // 3. Verify on Backend (Always verify server side)
      if (success) {
        // Double check verification on backend just in case
        return await _verifyPayment(reference);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Cancelled or Failed")));
         return false;
      }

    } catch (e) {
      print("Payment Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment Error: $e")));
      return false;
    }
  }

  Future<bool> _openPaymentWebView(BuildContext context, String url, String reference) async {
    bool isVerified = false;
    
    await Navigator.of(context).push(MaterialPageRoute(builder: (context) {
       return SafeArea(
         child: Scaffold(
           appBar: AppBar(
             title: const Text("Paystack Checkout"),
             leading: IconButton(
               icon: const Icon(Icons.close),
               onPressed: () => Navigator.pop(context),
             ),
           ),
           body: _PaymentWebView(
             initialUrl: url,
             reference: reference,
             onComplete: (success) {
                isVerified = success;
                Navigator.pop(context); // Close WebView
             },
           ),
         ),
       );
    }));

    return isVerified;
  }

  Future<bool> _verifyPayment(String reference) async {
    try {
      final response = await _api.client.post('/payments/verify', data: {
        'reference': reference
      });
      
      if (response.data['status'] == 'success') {
        return true; 
      }
      return false;
    } catch (e) {
      print("Verification Error: $e");
      return false;
    }
  }
}

class _PaymentWebView extends StatefulWidget {
  final String initialUrl;
  final String reference;
  final Function(bool) onComplete;

  const _PaymentWebView({
    Key? key,
    required this.initialUrl,
    required this.reference,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<_PaymentWebView> createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<_PaymentWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
             setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
             setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            // Check for success redirect
            if (request.url.contains('standard.paystack.co/close') || 
                request.url.contains('paystack.com') && request.url.contains('reference=${widget.reference}')) { // Fallback checks
               // We can assume completed, but verification is best done by checking backend.
               // Paystack redirects to callback_url on success.
               widget.onComplete(true); 
               return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
