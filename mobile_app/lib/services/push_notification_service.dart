import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/user/main_layout.dart';
import '../screens/admin/admin_main_layout.dart'; // [NEW]
import '../screens/user/products/submit_review_screen.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyB_mF4xxgOSzrSoMXpIpr48ZIFZKN7xpSc",
        authDomain: "clotheline.firebaseapp.com",
        projectId: "clotheline",
        storageBucket: "clotheline.firebasestorage.app",
        messagingSenderId: "641268154673",
        appId: "1:641268154673:web:28a5bd63af3cd58528f010",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
}

class PushNotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // [CRITICAL] Initialize Firebase App first!
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyB_mF4xxgOSzrSoMXpIpr48ZIFZKN7xpSc",
          authDomain: "clotheline.firebaseapp.com",
          projectId: "clotheline",
          storageBucket: "clotheline.firebasestorage.app",
          messagingSenderId: "641268154673",
          appId: "1:641268154673:web:28a5bd63af3cd58528f010",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }

    // 1. Request Permission (Wrapped in try-catch for Web Safari constraints)
    NotificationSettings? settings;
    try {
      settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      if (kDebugMode) print('Permission request failed/blocked (likely Web/Safari constraints): $e');
    }

    if (settings?.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('User granted permission');
      }
    } else {
      if (kDebugMode) {
        print('User declined or has not accepted permission (or blocked by browser)');
      }
      return;
    }

    // 2. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Get FCM Token & Subscribe to Broadcasts
    String? token;
    try {
      if (kIsWeb) {
        token = await _firebaseMessaging.getToken(
          vapidKey: "BAfn05dkd4-avpPSrXZy1u04Q5JmA9Ft15vib_FOph9kD40IHGg6oNuVGIRIY2nK3vPzKxhmXMBWzeg_N5hysTk",
        );
      } else {
        token = await _firebaseMessaging.getToken();
      }
      if (kDebugMode) {
        print('FCM Token: $token');
      }
    } catch (e) {
      if (kDebugMode) print('Failed to get FCM Token: $e');
    }
    
    // [NEW] Subscribe to global broadcast topic so Guests receive promotions
    try {
      await _firebaseMessaging.subscribeToTopic('all_users');
      if (kDebugMode) print('Subscribed to all_users topic');
    } catch (e) {
      if (kDebugMode) print('Failed to subscribe to topic: $e');
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

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload;
        if (payload != null) {
          // Handle Local Notification Tap
        }
        
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('saved_user_role') ?? 'user';

        if (role == 'admin') {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AdminMainLayout(initialIndex: 1)),
            (route) => false,
          );
        } else {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainLayout(initialIndex: 2)),
            (route) => false,
          );
        }
      },
    );

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
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
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
    try {
      if (kIsWeb) {
        return await _firebaseMessaging.getToken(
          vapidKey: "BAfn05dkd4-avpPSrXZy1u04Q5JmA9Ft15vib_FOph9kD40IHGg6oNuVGIRIY2nK3vPzKxhmXMBWzeg_N5hysTk",
        );
      }
      return await _firebaseMessaging.getToken();
    } catch (e) {
      if (kDebugMode) print('Failed to get FCM Token: $e');
      return null;
    }
  }

  // [NEW] Manual request to bypass Web DOMExceptions when not booted from user interaction
  static Future<void> requestWebPermission() async {
    if (!kIsWeb) return;
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await getToken();
        if (kDebugMode) print("FCM Token retrieved after manual interaction: $token");
      }
    } catch (e) {
      if (kDebugMode) print("Manual web permission request failed (Still rejected): $e");
    }
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

  static Future<void> _handleMessage(BuildContext context, RemoteMessage message) async {
     if (message.data['type'] == 'order') {
        // Deep link to orders tab
        print("Notification Tapped: ${message.data}");
        
        int tabIndex = 1; // Default: New
        String status = message.data['status'] ?? '';
        
        // Map Status to Tab Index
        if (status == 'InProgress' || status == 'Processing') tabIndex = 2;
        if (status == 'Ready') tabIndex = 3;
        if (status == 'Completed') tabIndex = 4;
        if (status == 'Cancelled' || status == 'Refunded') tabIndex = 5;

        try {
          final prefs = await SharedPreferences.getInstance();
          final role = prefs.getString('saved_user_role') ?? 'user';

          if (role == 'admin') {
             // For Admin, map status to AdminOrdersScreen Tab Index
             // _tabs = ['New', 'PendingUserConfirmation', 'InProgress', 'Ready', 'Completed', 'Cancelled', 'Refunded']
             int adminTabIndex = 0;
             if (status == 'PendingUserConfirmation') adminTabIndex = 1;
             if (status == 'InProgress' || status == 'Processing') adminTabIndex = 2;
             if (status == 'Ready') adminTabIndex = 3;
             if (status == 'Completed') adminTabIndex = 4;
             if (status == 'Cancelled') adminTabIndex = 5;
             if (status == 'Refunded') adminTabIndex = 6;

             Navigator.of(context).pushAndRemoveUntil(
               MaterialPageRoute(builder: (_) => AdminMainLayout(
                 initialIndex: 1, // Orders
                 initialOrderTabIndex: adminTabIndex
               )),
               (route) => false
             );
          } else {
             Navigator.of(context).pushAndRemoveUntil(
               MaterialPageRoute(builder: (_) => MainLayout(
                 initialIndex: 2, 
                 initialOrderTabIndex: tabIndex
               )),
               (route) => false
             );
          }
        } catch (e) {
          print("Deep link navigation error: $e");
        }
     } else if (message.data['type'] == 'review_reminder') {
        // Deep link to Review Submission
        final productId = message.data['productId'];
        final productName = message.data['productName'] ?? 'Product';
        final orderId = message.data['orderId'];

        if (productId != null && orderId != null) {
          try {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubmitReviewScreen(
                  productId: productId,
                  productName: productName,
                  orderId: orderId,
                ),
              ),
            );
          } catch (e) {
            print("Review reminder deep link error: $e");
          }
        }
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
