import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart'; // [FIX] Added import
import 'package:clotheline_core/clotheline_core.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  final ApiService _api = ApiService();
  
  // 1. Initialize Payment (Returns URL and Reference)
  Future<Map<String, dynamic>?> initializePayment(Map<String, dynamic> orderData) async {
    try {
      final response = await _api.client.post('/payments/initialize', data: orderData);
      
      if (response.data['authorization_url'] != null) {
        return {
          'authorization_url': response.data['authorization_url'],
          'reference': response.data['reference']
        };
      }
      return null;
    } catch (e) {
      if (e is DioException) {
         final msg = e.response?.data is Map ? e.response?.data['msg'] : null;
         if (msg != null) throw msg; // Throw just the message string
      }
      print("Payment Init Error: $e");
      throw e.toString().replaceAll("Exception:", ""); // Fallback clean string
    }
  }

  // 2. Verify Payment & Create Order
  Future<Map<String, dynamic>?> verifyAndCreateOrder(String reference) async {
    try {
      final response = await _api.client.post('/payments/verify', data: {
        'reference': reference
      });
      
      if (response.data['status'] == 'success') {
         // Return the created order
         return response.data; // contains { status: 'success', order: ... }
      }
      return null;
    } catch (e) {
      print("Verification Error: $e");
      return null;
    }
  }

  // Helper: Open WebView
  Future<bool> openPaymentWebView(BuildContext context, String url, String reference) async {
    bool isCompleted = false;
    
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
                isCompleted = success;
                Navigator.pop(context); // Close WebView
             },
           ),
         ),
       );
    }));

    return isCompleted;
  }
}

class _PaymentWebView extends StatefulWidget {
  final String initialUrl;
  final String reference;
  final Function(bool) onComplete;

  const _PaymentWebView({
    required this.initialUrl,
    required this.reference,
    required this.onComplete,
  });

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
                (request.url.contains('paystack.com') && request.url.contains('reference=${widget.reference}'))) { 
               widget.onComplete(true); 
               return NavigationDecision.prevent;
            }

            // [NEW] Deep Linking Support (OPay, PalmPay, WhatsApp, etc)
            if (!request.url.startsWith('http://') && !request.url.startsWith('https://')) {
              try {
                final Uri uri = Uri.parse(request.url);
                launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              } catch (e) {
                print("Could not launch deep link: ${request.url}");
              }
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
