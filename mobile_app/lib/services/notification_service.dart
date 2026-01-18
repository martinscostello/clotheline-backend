import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

class NotificationService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  List<dynamic> _notifications = [];
  List<dynamic> get notifications => _notifications;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  Timer? _pollingTimer;

  int get unreadCount => _notifications.where((n) => n['isRead'] == false).length;

  // Track known IDs to detect NEW ones
  Set<String> _knownNotificationIds = {};

  Map<String, dynamic> _preferences = {
    'email': true,
    'push': true, 
    'orderUpdates': true,
    'chatMessages': true,
    'adminBroadcasts': true,
    'bucketUpdates': true,
  };
  Map<String, dynamic> get preferences => _preferences;

  NotificationService() {
    _initLocalNotifications();
    // Start polling automatically
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
     // Fetch immediately
     fetchNotifications(silent: true);
     // Poll every 15 seconds
     _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        fetchNotifications(silent: true);
     });
  }

  Future<void> _initLocalNotifications() async {
     const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
     const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
     const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
     
     await _localNotifications.initialize(settings);
     
     // Request Permissions Explicitly (Required for iOS)
     final platform = _localNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
     await platform?.requestPermissions(
       alert: true,
       badge: true,
       sound: true,
     );
  }

  Future<void> fetchNotifications({bool silent = false}) async {
    if (!silent) {
       _isLoading = true;
       notifyListeners();
    }
    
    try {
      final response = await _apiService.client.get('/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _notifications = data; // Already sorted by backend

        // Check for NEW notifications
        for (var n in data) {
           final id = n['_id'];
           if (!_knownNotificationIds.contains(id)) {
              _knownNotificationIds.add(id);
              // Only alert if isRead is false AND it's not the initial load (heuristic)
              // Actually, simply checking known IDs handles "New" items effectively.
              // To avoid spam on first load, maybe check if we already have a set?
              if (_knownNotificationIds.length > data.length) { 
                 // This means we just added one. (On first load size is 0 -> length, so condition fails)
                 // But wait, if _known is empty, we add all. logic:
              }
           }
        }
        
        // Simpler Logic: Store last check time? Or just Count diff?
        // Let's use isRead. If we find an item where isRead=false AND we haven't alerted it?
        // Let's use a simpler heuristic for now: IF unread count increases? 
        // Best: Check strictly for ID in difference set.
        
        // ALERT LOGIC:
        if (silent) {
           _checkForAlerts();
        }
      }
      
      if (!silent) await fetchPreferences();

    } catch (e) {
      print("Error fetching notifications: $e");
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      } else {
        // Even silent updates need listener notification to update Badge
        notifyListeners();
      }
    }
  }

  String? _lastAlertedId;

  // Call this inside fetch loop
  void _checkForAlerts() {
     if (_notifications.isEmpty) return;
     final latest = _notifications.first;
     
     if (latest['isRead'] == false && latest['_id'] != _lastAlertedId) {
        // It's a new unread item!
        _lastAlertedId = latest['_id'];
        _showLocalNotification(latest['title'], latest['message']);
     }
  }

  Future<void> _showLocalNotification(String? title, String? body) async {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'clotheline_alerts', 'Clotheline Alerts',
        importance: Importance.max, priority: Priority.high,
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
      await _localNotifications.show(0, title, body, details);
  }
  
  // ... Rest of methods (fetchPreferences, updatePreference, markAllAsRead) ...
  // [Insert keeping existing methods here]
  
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
    _preferences[key] = value;
    notifyListeners();
    try {
      await _apiService.client.put('/notifications/preferences', data: { key: value });
    } catch (e) {
      print("Error updating pref: $e");
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.client.post('/notifications/mark-read');
      for (var n in _notifications) {
        n['isRead'] = true;
      }
      notifyListeners();
      fetchNotifications(silent: true);
    } catch (e) {
      print("Error marking read: $e");
    }
  }
}
