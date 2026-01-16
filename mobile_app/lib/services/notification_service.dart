import 'package:flutter/foundation.dart';
import 'api_service.dart';

class NotificationService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<dynamic> _notifications = [];
  List<dynamic> get notifications => _notifications;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int get unreadCount => _notifications.where((n) => n['isRead'] == false).length;



  Map<String, dynamic> _preferences = {
    'email': true,
    'push': true,
    'orderUpdates': true,
    'chatMessages': true,
    'adminBroadcasts': true,
    'bucketUpdates': true,
  };
  Map<String, dynamic> get preferences => _preferences;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _apiService.client.get('/notifications');
      if (response.statusCode == 200) {
         // Sort by date desc locally if needed, though backend does it
        _notifications = response.data as List<dynamic>;
      }
      
      // Also fetch preferences
      await fetchPreferences();

    } catch (e) {
      print("Error fetching notifications: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPreferences() async {
    try {
      final response = await _apiService.client.get('/notifications/preferences');
      if (response.statusCode == 200) {
        _preferences = response.data;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching prefs: $e");
    }
  }

  Future<void> updatePreference(String key, bool value) async {
    // Optimistic update
    _preferences[key] = value;
    notifyListeners();

    try {
      await _apiService.client.put('/notifications/preferences', data: {
         key: value
      });
    } catch (e) {
      print("Error updating pref: $e");
      // Revert if failed? For now, keep optimistic.
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.client.post('/notifications/mark-read');
      // Optimistic update
      for (var n in _notifications) {
        n['isRead'] = true;
      }
      notifyListeners();
      // Re-fetch to be sure
      fetchNotifications();
    } catch (e) {
      print("Error marking read: $e");
    }
  }
}
