import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'dart:async';

class ChatService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _messages = [];
  List<dynamic> get messages => _messages;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Timer? _pollTimer;

  void startPolling() {
    fetchMessages();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => fetchMessages());
  }

  void stopPolling() {
    _pollTimer?.cancel();
  }

  Future<void> fetchMessages() async {
    try {
      final response = await _apiService.client.get('/chat');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null && data['messages'] != null) {
          _messages = List<dynamic>.from(data['messages']);
          notifyListeners();
        }
      }
    } catch (e) {
       // Silent fail on poll
       if (_messages.isEmpty) print("Chat fetch error: $e");
    }
  }

  Future<void> sendMessage(String text) async {
    // Optimistic Append
    _messages.add({
      'sender': 'user',
      'text': text,
      'timestamp': DateTime.now().toIso8601String()
    });
    notifyListeners();

    try {
      await _apiService.client.post('/chat', data: {'text': text});
      // create/update happens on server, next poll will sync
      fetchMessages(); 
    } catch (e) {
      print("Send error: $e");
      // Could remove optimistic msg here if failed
    }
  }
  
  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
