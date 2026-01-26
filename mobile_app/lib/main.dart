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
import 'services/navigation_persistence_service.dart';
import 'services/content_service.dart'; 
import 'services/analytics_service.dart';
import 'services/promotion_service.dart'; // Added // Added
import 'services/review_service.dart';
import 'providers/branch_provider.dart';
import 'screens/user/main_layout.dart';
import 'screens/admin/admin_main_layout.dart';
import 'models/service_model.dart'; // Assuming this import exists for ServiceModel
import 'models/branch_model.dart';
import 'widgets/global_error_boundary.dart'; // Added
import 'services/network_service.dart'; // Added

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
  // Initialize Push Notifications (Non-blocking)
  try {
    PushNotificationService.initialize();
    NetworkService().initialize(); 
  } catch (_) {}

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black, // Block mode
    systemNavigationBarIconBrightness: Brightness.light,
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
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => AnalyticsService()),
        ChangeNotifierProvider(create: (_) => PromotionService()), // Added
        ChangeNotifierProvider(create: (_) => ReviewService()), // Added
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
            
            builder: (context, child) {
              // Wrap with Error Boundary
              return GlobalErrorBoundary(
                child: Overlay( // Required for Banner? No, Material App provides Overlay.
                  initialEntries: [
                    OverlayEntry(
                      builder: (ctx) => Stack(
                        children: [
                          if (child != null) child,
                          // Network Banner Overlay
                          const _NetworkBanner(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              // Wait, simpler approach for builder:
              // return GlobalErrorBoundary(
              //   child: Stack(
              //     children: [
              //       if (child != null) child,
              //       const _NetworkBanner(),
              //     ],
              //   ),
              // );
              // BUT ErrorBoundary relies on ErrorWidget.builder which is global.
              // The widget wrapper captures build errors.
            },

            navigatorObservers: [
              NavigationPersistenceService()
            ],
          );
        },
      ),
    );
  }

  // ... _determineInitialScreen ...
  Widget _determineInitialScreen(BootstrapData data) {
    if (!data.isLoggedIn) {
       return const LoginScreen(); 
    }
    if (data.userRole == 'admin') {
      return const AdminMainLayout();
    } else {
      return const MainLayout();
    }
  }
}

// [SMALL WIDGET] Network Banner
class _NetworkBanner extends StatefulWidget {
  const _NetworkBanner();

  @override
  State<_NetworkBanner> createState() => _NetworkBannerState();
}

class _NetworkBannerState extends State<_NetworkBanner> {
  bool isOffline = false;

  @override
  void initState() {
    super.initState();
    NetworkService().connectionStream.listen((online) {
       if (mounted) setState(() => isOffline = !online);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Material(
        color: Colors.redAccent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_off, color: Colors.white, size: 14),
              SizedBox(width: 8),
              Text("No Internet Connection", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
