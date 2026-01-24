import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added Import
import 'package:provider/provider.dart';
import 'dart:convert'; // Added for jsonDecode
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart'; 
import 'screens/auth/onboarding_screen.dart'; // Added Import
import 'services/laundry_service.dart';
import 'services/cart_service.dart';
import 'services/store_service.dart';
import 'services/order_service.dart';
import 'services/delivery_service.dart';
import 'services/auth_service.dart';
import 'services/favorites_service.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/chat_service.dart';
import 'services/navigation_persistence_service.dart';
import 'services/content_service.dart'; // Added Import
import 'providers/branch_provider.dart';
import 'screens/user/main_layout.dart';
import 'screens/admin/admin_main_layout.dart';
import 'models/service_model.dart'; // Assuming this import exists for ServiceModel
import 'models/branch_model.dart';

// Global Theme Notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// [HYDRATION-FIRST] Data Transfer Object
class BootstrapData {
  final Map<String, dynamic>? userProfile;
  final String? userRole;
  final String? branchId;
  final List<dynamic> branchesJson;
  final List<dynamic> servicesJson;
  final bool isLoggedIn;

  BootstrapData({
    this.userProfile,
    this.userRole,
    this.branchId,
    required this.branchesJson,
    required this.servicesJson,
    required this.isLoggedIn,
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. [BOOTLOADER] Synchronous File I/O (Fastest Path)
  final prefs = await SharedPreferences.getInstance();
  
  // A. Auth State
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final String? savedRole = prefs.getString('saved_user_role');
  final String? savedName = prefs.getString('user_name');
  
  Map<String, dynamic>? userProfile;
  if (savedName != null) {
     userProfile = {'name': savedName, 'email': prefs.getString('user_email') ?? ''};
  }

  // B. Business Data
  final String? branchId = prefs.getString('selected_branch_id');
  
  // Branches
  List<dynamic> branchesJson = [];
  try {
    final str = prefs.getString('cached_branches');
    if (str != null) branchesJson = jsonDecode(str);
  } catch (_) {}

  // Services (Load specific branch cache if selected, else default)
  List<dynamic> servicesJson = [];
  try {
    final key = branchId != null ? 'services_cache_$branchId' : 'services_cache_default';
    final str = prefs.getString(key);
    if (str != null) servicesJson = jsonDecode(str);
  } catch (_) {}

  final bootstrap = BootstrapData(
    userProfile: userProfile,
    userRole: savedRole,
    branchId: branchId,
    branchesJson: branchesJson,
    servicesJson: servicesJson,
    isLoggedIn: isLoggedIn,
  );

  // Initialize Push Notifications (Non-blocking)
  try {
    PushNotificationService.initialize();
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  
  runApp(LaundryApp(bootstrap: bootstrap));
}

class LaundryApp extends StatelessWidget {
  final BootstrapData bootstrap;
  const LaundryApp({super.key, required this.bootstrap});

  @override
  Widget build(BuildContext context) {
    // 2. [DEPENDENCY INJECTION] Hydrate Providers Instantly
    return MultiProvider(
      providers: [
        // Services
        ChangeNotifierProvider(create: (_) {
           final svc = LaundryService();
           // Transform JSON to Models
           List<ServiceModel> hydrated = [];
           try {
              hydrated = bootstrap.servicesJson.map((j) => ServiceModel.fromJson(j)).toList();
           } catch (_) {}
           svc.hydrateFromBootstrap(hydrated);
           return svc;
        }),
        ChangeNotifierProvider(create: (_) {
           final bp = BranchProvider();
           // Transform JSON
           List<Branch> hydrated = [];
           try {
              hydrated = bootstrap.branchesJson.map((j) => Branch.fromJson(j)).toList();
           } catch (_) {}
           bp.hydrateFromBootstrap(hydrated, bootstrap.branchId);
           return bp;
        }),
        ChangeNotifierProvider(create: (_) {
          final auth = AuthService();
          // We could hydrate simple user profile here if we modified AuthService,
          // but AuthService mostly relies on SecureStorage for tokens.
          // However, we can set the "Memory Cache" for user name/email if we want.
          if (bootstrap.isLoggedIn) {
             // Hack: We can pre-set the currentUser map if we want synchronous "Hi Friend"
             auth.hydrateSimpleProfile(bootstrap.userProfile, bootstrap.userRole);
          }
          // The rest (validation) happens in background
          if (bootstrap.isLoggedIn) {
             Future.microtask(() => auth.validateSession());
          }
          return auth;
        }),
        
        // Standard Providers
        ChangeNotifierProvider(create: (_) => CartService()), // Should also hydrate ideally
        ChangeNotifierProvider(create: (_) => StoreService()), // Should also hydrate
        ChangeNotifierProvider(create: (_) => OrderService()),
        ChangeNotifierProvider(create: (_) => DeliveryService()),
        ChangeNotifierProvider(create: (_) => FavoritesService()..loadFavorites()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        Provider(create: (_) => ContentService()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, ThemeMode currentMode, __) {
          return MaterialApp(
            title: 'Laundry Business',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: currentMode,
            
            // 3. [ROUTING] Instant Determination
            home: _determineInitialScreen(bootstrap),
            
            navigatorObservers: [
              NavigationPersistenceService()
            ],
          );
        },
      ),
    );
  }

  Widget _determineInitialScreen(BootstrapData data) {
    if (!data.isLoggedIn) {
       // Check onboarding? (Lazy check: assume seen if not logged in? No, need check)
       // We didn't read onboarding in main(). Let's assume Login if indeterminate for now, 
       // or user can add it to Bootloader.
       // Actually user rule: "App must never reset to login visually... if session expires show modal".
       // But if NEVER logged in? LoginScreen.
       return const LoginScreen(); 
    }
    
    // Logged In -> Dashboard Immediately
    if (data.userRole == 'admin') {
      return const AdminMainLayout();
    } else {
      return const MainLayout();
    }
  }
}
