import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'push_notification_service.dart'; // [NEW]
import 'package:flutter/material.dart';

class NotificationService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  List<dynamic> _notifications = [];
  List<dynamic> get notifications => _notifications;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  Timer? _pollingTimer;

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
     // Fetch immediately (No Alerts on Launch)
     fetchNotifications(silent: true, alert: false);
     // Poll every 5 seconds (Quick Notifications)
     _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        fetchNotifications(silent: true, alert: true);
     });
  }

  // ...

  Future<void> fetchNotifications({bool silent = false, bool alert = true}) async {
    if (!silent) {
       _isLoading = true;
       notifyListeners();
    }
    
    try {
      final response = await _apiService.client.get('/notifications');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _notifications = data; 

        if (alert) {
           _checkForAlerts();
        } else {
           _syncLastAlert();
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
        notifyListeners();
      }
    }
  }

  // [NEW] Mark All Read By Type
  Future<void> markAllReadByType(String type) async {
    // Optimistic
    bool changed = false;
    for (var n in _notifications) {
      if (n['isRead'] == false && n['type'] == type) {
           n['isRead'] = true;
           changed = true;
      }
    }
    if (changed) notifyListeners();

    try {
      await _apiService.client.post('/notifications/mark-entity-read', data: {
        'type': type
      });
    } catch (e) {
      print("Error marking type read: $e");
    }
  }

  String? _lastAlertedId; // Reset on App Launch, so we need logic to prevent re-alerting OLD items if alert=true passed later.
  // Actually, standard behavior: If I launch app, I don't want sound. 
  // If I leave app open and new one comes, I want sound. 
  // If I restart app, I don't want sound for old unread.
  // The 'alert: false' on first run handles the "Loop on Restart" if logic relies on incoming diff.
  // But _checkForAlerts checks _notifications.first['isRead'] == false.
  // If we don't mark it read, next poll (alert=true) will see it as unread and trigger!
  // FIX: We need to initialize _lastAlertedId with the top unread ID on the first "silent" fetch so we know "we've seen this".

  void _checkForAlerts() {
     if (_notifications.isEmpty) return;
     
     // [FIX] If app is in foreground and active, skip polling alerts. 
     // FCM (PushNotificationService) handles real-time foreground alerts.
     // Polling is mainly for updating the UI badges and catching missed items.
     if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _syncLastAlert();
        return;
     }

     // Filter only unread
     final unread = _notifications.where((n) => n['isRead'] == false).toList();
     if (unread.isEmpty) return;

     final latest = unread.first;
     
     if (latest['_id'] != _lastAlertedId) {
        _lastAlertedId = latest['_id'];
        _showLocalNotification(latest['title'], latest['message']);
     }
  }
  
  // Method to sync ID without alerting (called on init)
  void _syncLastAlert() {
     if (_notifications.isEmpty) return;
     final unread = _notifications.where((n) => n['isRead'] == false).toList();
     if (unread.isNotEmpty) {
       _lastAlertedId = unread.first['_id'];
     }
  }
  
  // Override fetchNotifications logic slightly above to call _syncLastAlert() if alert is false
  
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (details) {
// This should be handled by a deep link handler or via the navigatorKey without hardcoded screens
         // If we are in the core, we can't know about MainLayout.
         // For now, we use a generic deep link logic or just notify listeners.
         // Actually, most apps handle this in the UI layer by listening to the service.
         // But to keep it working as is, we can use the navigatorKey and push by Name or just leave it for the app to handle.
         debugPrint("Notification tapped - app should navigate to orders");
      }
    );
    
    final platform = _localNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await platform?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _showLocalNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'clotheline_alerts', 'Clotheline Alerts',
      importance: Importance.max, priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _localNotifications.show(id: 0, title: title, body: body, notificationDetails: details);
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

  Future<void> markAsRead(String id) async {
    // Optimistic Update
    final index = _notifications.indexWhere((n) => n['_id'] == id);
    if (index != -1) {
      _notifications[index]['isRead'] = true;
      notifyListeners();
    }
    
    try {
      await _apiService.client.post('/notifications/$id/read');
    } catch (e) {
      print("Error marking read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.client.post('/notifications/mark-read');
      for (var n in _notifications) {
        n['isRead'] = true;
      }
      notifyListeners();
    } catch (e) {
      print("Error marking read: $e");
    }
  }

  // [NEW] Mark Read By Entity
  Future<void> markReadByEntity(String entityId, {String? type}) async {
    // Optimistic
    bool changed = false;
    for (var n in _notifications) {
      if (n['isRead'] == false && n['metadata'] != null) {
        if (n['metadata']['orderId'] == entityId) { // Check Order ID
           n['isRead'] = true;
           changed = true;
        }
      }
    }
    if (changed) notifyListeners();

    try {
      await _apiService.client.post('/notifications/mark-entity-read', data: {
        'entityId': entityId,
        'type': type
      });
    } catch (e) {
      print("Error marking entity read: $e");
    }
  }
}
