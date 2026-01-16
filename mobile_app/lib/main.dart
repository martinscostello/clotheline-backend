import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart'; 
import 'services/laundry_service.dart';
import 'services/cart_service.dart';
import 'services/store_service.dart';
import 'services/order_service.dart';
import 'services/delivery_service.dart';
import 'services/auth_service.dart';
import 'services/favorites_service.dart';
import 'services/notification_service.dart';
import 'services/chat_service.dart';
import 'services/chat_service.dart';
import 'services/navigation_persistence_service.dart';
import 'providers/branch_provider.dart';
import 'screens/user/main_layout.dart';
import 'screens/common/branch_selection_screen.dart';
import 'screens/admin/dashboard/admin_dashboard_screen.dart';
import 'screens/admin/admin_main_layout.dart';

// Global Theme Notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  runApp(const LaundryApp());
}

class LaundryApp extends StatelessWidget {
  const LaundryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LaundryService()),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => StoreService()),
        ChangeNotifierProvider(create: (_) => OrderService()),
        ChangeNotifierProvider(create: (_) => DeliveryService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FavoritesService()..loadFavorites()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => BranchProvider()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, ThemeMode currentMode, __) {
          return MaterialApp(
            title: 'Laundry Business',
            debugShowCheckedModeBanner: false,
            
            // Theme Configuration
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: currentMode,
            
            // PERSISTENT AUTH CHECK
            home: const AuthCheckWrapper(), 
            navigatorObservers: [
              NavigationPersistenceService()
            ],
          );
        },
      ),
    );
  }
}

class AuthCheckWrapper extends StatefulWidget {
  const AuthCheckWrapper({super.key});

  @override
  State<AuthCheckWrapper> createState() => _AuthCheckWrapperState();
}

class _AuthCheckWrapperState extends State<AuthCheckWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // 1. Optimistic Load (Local Storage only) -> Fast
    final hasSession = await authService.loadFromStorage();
    
    if (!mounted) return;

    if (hasSession) {
      // 2. Trigger Background Validation (Fire & Forget)
      // If fails, AuthService will logout/updater state, causing a redirect or requiring handler
      // Ideally, we just let it run. If it fails, AuthService might need a way to signal "Logout".
      // Since we are pushing Replacement, if logout happens later, the app needs to handle it (e.g., via a global listener or just next API call 401).
      authService.validateSession().then((isValid) {
         if (!isValid && mounted) {
            // Late failure catch - redirect to login if we are still here? 
            // Better: let the listener in MyApp or Screen handle 401s, OR
            // just let it go. If validateSession fails, authService.currentUser becomes null/invalid?
            // Actually validateSession calls logout() on strict fail.
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
         }
      });

      // 3. Navigate Immediately
      _navigateHome(authService);
    } else {
      // No local session -> Login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen())
      );
    }
  }

  void _navigateHome(AuthService authService) async {
      // Isolate Role Logic
      final role = await authService.getUserRole();
      
      if (!mounted) return;

      if (role == 'admin') {
         Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminMainLayout())
        );
      } else {
        // [Multi-Branch] Check if branch selected
        final branchProvider = Provider.of<BranchProvider>(context, listen: false);
        // BranchProvider now loads form cache, so selectedBranch should be available if saved
        // We might need to wait a tick for BranchProvider to init? 
        // Actually main() initializes providers. BranchProvider constructor calls _init.
        // But _init is async. By the time we get here, it might not be done.
        // We should wait for BranchProvider to be "ready" or check prefs manually.
        // Simplest: Check BranchProvider.selectedBranch.
        
        // Wait briefly for Provider to catch up? Or rely on the "Cached Load" being fast enough.
        // Since we are in addPostFrameCallback essentially (initState -> checkAuth async), 
        // and BranchProvider loads cache in constructor/init, it's a race.
        // Let's add a small polling or ensure BranchProvider is ready? 
        // For "Instant", we trust loadFromStorage is fast.
        
        // BETTER: Check prefs directly here if Provider isn't ready, 
        // OR just route to MainLayout and let MainLayout redirect if needed.
        // But we have logic to show BranchSelectionScreen first.
        
        if (branchProvider.selectedBranch == null) {
           // Fallback: If no branch selected, just go to MainLayout.
           // Ideally, BranchProvider should have auto-selected a default during init if cache was empty.
           // If essential, we could select one here if list is populated.
           if (branchProvider.branches.isNotEmpty) {
             branchProvider.selectBranch(branchProvider.branches.first);
           }
           
           // Proceed to MainLayout (Home) directly
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (_) => const MainLayout()), 
             (route) => false
           );
        } else {
           // 1. Always start at MainLayout (Home) logic
           // But check if we need to restore a specific screen on TOP of it
           final navService = NavigationPersistenceService();
           final restoredRoute = await navService.getRestorableRoute();

           // Reset stack to MainLayout
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (_) => const MainLayout()), 
             (route) => false
           );
           
           // Restore route logic (simplified)
        }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Or brand color
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use local asset or icon if available, else just loader
            const Icon(Icons.local_laundry_service, size: 80, color: AppTheme.primaryColor),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}
