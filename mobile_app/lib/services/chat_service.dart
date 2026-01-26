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
  int _pollIntervalSeconds = 5;
  bool _isAppActive = true;

  void setAppState(bool active) {
    _isAppActive = active;
    _adjustPollingSpeed();
  }

  void _adjustPollingSpeed() {
    if (!_isAppActive) {
      _pollIntervalSeconds = 30; // Slow down when backgrounded
    } else {
      _pollIntervalSeconds = 5;
    }
    
    if (_pollTimer != null && _pollTimer!.isActive) {
       final branchId = _currentThread?['branchId'];
       if (branchId != null) startPolling(branchId);
    }
  }

  void startPolling(String branchId) {
    _initThread(branchId);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: _pollIntervalSeconds), (_) => _sync());
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

  Future<void> sendMessage(String text, {String? orderId}) async {
    if (_currentThread == null) return;
    
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMessage = {
      '_id': 'temp_$tempId',
      'threadId': _currentThread!['_id'],
      'senderType': 'user', 
      'senderId': 'current_user', 
      'messageText': text,
      'orderId': orderId,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'sending' 
    };

    _messages.add(optimisticMessage);
    notifyListeners();

    try {
      final response = await _apiService.client.post('/chat/send', data: {
        'threadId': _currentThread!['_id'],
        'messageText': text,
        'orderId': orderId,
        'clientMessageId': tempId
      });
      
      if (response.statusCode == 200) {
         final idx = _messages.indexWhere((m) => m['_id'] == 'temp_$tempId');
         if (idx != -1) {
           _messages[idx] = response.data;
           _messages[idx]['status'] = 'sent';
         }
         notifyListeners();
      }
    } catch (e) {
      print("Send error: $e");
      final idx = _messages.indexWhere((m) => m['_id'] == 'temp_$tempId');
      if (idx != -1) {
        _messages[idx]['status'] = 'failed';
        notifyListeners();
      }
    }
  }

  Future<void> resendMessage(String tempId) async {
    final idx = _messages.indexWhere((m) => m['_id'] == tempId);
    if (idx == -1) return;

    final msg = _messages[idx];
    _messages[idx]['status'] = 'sending';
    notifyListeners();

    try {
      final response = await _apiService.client.post('/chat/send', data: {
        'threadId': _currentThread!['_id'],
        'messageText': msg['messageText'],
        'orderId': msg['orderId'],
        'clientMessageId': tempId.replaceFirst('temp_', '')
      });
      
      if (response.statusCode == 200) {
         _messages[idx] = response.data;
         _messages[idx]['status'] = 'sent';
         notifyListeners();
      }
    } catch (e) {
      _messages[idx]['status'] = 'failed';
      notifyListeners();
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

  Future<String?> getAdminThreadForUser(String userId, String branchId) async {
    try {
      final response = await _apiService.client.get(
        '/chat/admin/thread-for-user', 
        queryParameters: {'userId': userId, 'branchId': branchId}
      );
      
      if (response.statusCode == 200) {
        return response.data['_id'];
      }
      return null;
    } catch (e) {
      print("Error getting thread for user: $e");
      return null;
    }
  }

  Future<void> selectThread(String threadId) async {
    _isLoading = true;
    notifyListeners();
    try {
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
        final idx = _threads.indexWhere((t) => t['_id'] == threadId);
        if (idx != -1) _threads[idx]['status'] = status;
        notifyListeners();
      }
    } catch (e) {
       print("Update status error: $e");
    }
  }

  Future<void> sendBroadcast({
    required String branchId,
    required String messageText,
    required String audienceType,
    List<String>? targetUserIds,
  }) async {
    try {
      final response = await _apiService.client.post('/chat/admin/broadcast', data: {
        'branchId': branchId,
        'messageText': messageText,
        'audienceType': audienceType,
        'targetUserIds': targetUserIds
      });
      if (response.statusCode == 200) {
        notifyListeners();
      }
    } catch (e) {
      print("Broadcast error: $e");
      rethrow;
    }
  }

  Future<void> deleteThread(String threadId) async {
    try {
      final response = await _apiService.client.delete('/chat/admin/thread/$threadId');
      if (response.statusCode == 200) {
        _threads.removeWhere((t) => t['_id'] == threadId);
        if (_currentThread != null && _currentThread!['_id'] == threadId) {
          _currentThread = null;
          _messages = [];
        }
        notifyListeners();
      }
    } catch (e) {
      print("Delete thread error: $e");
    }
  }
  
  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
