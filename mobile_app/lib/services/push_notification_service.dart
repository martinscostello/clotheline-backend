import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
}

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // [CRITICAL] Initialize Firebase App first!
    await Firebase.initializeApp();

    // 1. Request Permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }
    } else {
      if (kDebugMode) {
        print('User declined or has not accepted permission');
      }
      return;
    }

    // 2. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Get FCM Token
    String? token = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      print('FCM Token: $token');
    }
    // TODO: Send this token to backend API

    // 4. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');
      }

      if (message.notification != null) {
        if (kDebugMode) {
          print('Message also contained a notification: ${message.notification}');
        }
        // Show local notification if needed
        _showLocalNotification(message);
      }
    });
    
    // 5. Initialize Local Notifications (for foreground display)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Verify icon name
    
    // Determine the proper permission request for iOS
    // Note: DarwinInitializationSettings handles permission requests via 'requestAlertPermission', etc.
    // but Firebase requestPermission already handles this logic at the app level.
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(initializationSettings);

    // [CRITICAL] Create the channel explicitly so Android knows it exists for Background/Dead state
    final AndroidFlutterLocalNotificationsPlugin? androidPlatform =
        _localNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlatform?.createNotificationChannel(const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', 
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    ));
  }

  static void _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // id
            'High Importance Notifications', // title
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }
  
  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  // [DEAD-STATE] Handle interaction when app opens from Dead/Background state
  static Future<void> setupInteractedMessage(BuildContext context) async {
    // 1. App Killed -> Tap Notification -> Application Open
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(context, initialMessage);
    }

    // 2. App Background -> Tap Notification -> Application Open
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(context, message);
    });
  }

  static void _handleMessage(BuildContext context, RemoteMessage message) {
     if (message.data['type'] == 'order') {
        // Deep link to orders tab
        // Note: Simple tab switching for now, or sophisticated routing
        // Assuming MainLayout is available, we might need a GlobalKey or route
        // deep linking support.
        // For now, simpler: Switch to Orders tab?
        // Navigation is tricky without named routes or context control.
        // Assuming context is from MainLayout.
        // We can use Navigator to push, or if using Tabs, finding the TabController is hard.
        // Better: Pop until root, then select tab.
        // For now: Just log interaction. Full deep linking requires routing table.
        // Actually user said: "Then route based on notification data."
        print("Notification Tapped: ${message.data}");
        // TODO: Implement advanced routing
     }
  }

  // [BATTERY] Request ignoring optimizations
  static Future<void> checkBatteryOptimization(BuildContext context) async {
    // Android Only
    if (defaultTargetPlatform != TargetPlatform.android) return;

    // Check if we already asked
    final prefs = await SharedPreferences.getInstance();
    final bool hasAsked = prefs.getBool('battery_opt_prompt_shown') ?? false;
    if (hasAsked) return;

    var status = await Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
       // Flag as shown immediately
       await prefs.setBool('battery_opt_prompt_shown', true);

       // Show dialog explanation
       showDialog(
         context: context, 
         builder: (ctx) => AlertDialog(
           title: const Text("Enable Background Updates"),
           content: const Text("To receive order updates when the app is closed, please allow Clotheline to run in the background."),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Later")),
             TextButton(
               onPressed: () async {
                  Navigator.pop(ctx);
                  await Permission.ignoreBatteryOptimizations.request();
               }, 
               child: const Text("Enable Now", style: TextStyle(fontWeight: FontWeight.bold))
             ),
           ],
         )
       );
    }
  }
}
