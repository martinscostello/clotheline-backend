import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationPersistenceService extends NavigatorObserver {
  static final NavigationPersistenceService _instance = NavigationPersistenceService._internal();
  factory NavigationPersistenceService() => _instance;
  NavigationPersistenceService._internal();

  /// Map of Route Names -> Safe Fallbacks
  /// If the app crashes on Key, restore Value.
  /// If Value is same as Key, it's safe to restore directly.
  final Map<String, String> _safeFallbacks = {
    '/': '/',
    '/login': '/',
    '/dashboard': '/dashboard',
    '/products': '/products', 
    // Risky screens fallback to safe parents
    '/checkout': '/cart',
    '/payment': '/orders', 
    '/chat_detail': '/chats',
    '/order_detail': '/orders',
    '/add_product': '/dashboard', // Admin fallback
  };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _saveRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _saveRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _saveRoute(previousRoute);
  }

  Future<void> _saveRoute(Route<dynamic> route) async {
    if (route.settings.name == null) return;
    
    final name = route.settings.name!;
    // Filter out internal flutter routes or dialogs if needed
    if (name == 'null' || name.startsWith('/_')) return;

    // Use fire-and-forget for speed, but `await` is safer for reliability.
    // Given usage in didPush, async is fine.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_active_route', name);
      // We could also save arguments if we serialize them, 
      // but for "Crash Recovery", simple route name + fallback is usually enough.
      // Arguments restoration requires complex serialization.
      // For now, we rely on the implementation plan's scope: "Safe Fallback".
    } catch (e) {
      print("Error saving route: $e");
    }
  }

  Future<String?> getRestorableRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastRoute = prefs.getString('last_active_route');
      
      if (lastRoute == null) return null;

      // Check Fallback Map
      // If it's a known route, return its safe fallback (or itself).
      // If unknown, return null (default to Home).
      
      // Simple lookup
      if (_safeFallbacks.containsKey(lastRoute)) {
        return _safeFallbacks[lastRoute];
      }
      
      // Normalize: remove args if path based? (Not applicable for named routes usually)
      return null; 
    } catch (e) {
      return null;
    }
  }
}
