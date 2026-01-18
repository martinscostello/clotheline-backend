import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'dart:async';

class ChatService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _currentThread;
  Map<String, dynamic>? get currentThread => _currentThread;

  List<dynamic> _messages = [];
  List<dynamic> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Timer? _pollTimer;

  void startPolling(String branchId) {
    _initThread(branchId);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sync());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _currentThread = null;
    _messages = [];
  }

  Future<void> _initThread(String branchId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.client.get('/chat', queryParameters: {'branchId': branchId});
      if (response.statusCode == 200) {
        _currentThread = response.data;
        await _fetchMessages();
      }
    } catch (e) {
      print("Thread init error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _sync() async {
    if (_currentThread == null) return;
    await _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    if (_currentThread == null) return;
    try {
      final response = await _apiService.client.get('/chat/messages/${_currentThread!['_id']}');
      if (response.statusCode == 200) {
        _messages = List<dynamic>.from(response.data);
        notifyListeners();
      }
    } catch (e) {
      // Silent fail on poll
    }
  }

  Future<void> sendMessage(String text) async {
    if (_currentThread == null) return;
    try {
      final response = await _apiService.client.post('/chat/send', data: {
        'threadId': _currentThread!['_id'],
        'messageText': text
      });
      if (response.statusCode == 200) {
         _messages.add(response.data);
         notifyListeners();
      }
    } catch (e) {
      print("Send error: $e");
    }
  }

  // --- ADMIN METHODS ---
  List<dynamic> _threads = [];
  List<dynamic> get threads => _threads;

  Future<void> fetchThreads(String branchId, String status) async {
    try {
      final response = await _apiService.client.get('/chat/admin/threads', queryParameters: {
        'branchId': branchId,
        'status': status
      });
      if (response.statusCode == 200) {
        _threads = List<dynamic>.from(response.data);
        notifyListeners();
      }
    } catch (e) {
      print("Fetch threads error: $e");
    }
  }

  Future<void> selectThread(String threadId) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Find thread in our list
      _currentThread = _threads.firstWhere((t) => t['_id'] == threadId);
      await _fetchMessages();
    } catch (e) {
       print("Select thread error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateThreadStatus(String threadId, String status) async {
    try {
      final response = await _apiService.client.put('/chat/admin/status/$threadId', data: {'status': status});
      if (response.statusCode == 200) {
        if (_currentThread != null && _currentThread!['_id'] == threadId) {
          _currentThread!['status'] = status;
        }
        // Update in list too
        final idx = _threads.indexWhere((t) => t['_id'] == threadId);
        if (idx != -1) _threads[idx]['status'] = status;
        notifyListeners();
      }
    } catch (e) {
       print("Update status error: $e");
    }
  }
  
  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
