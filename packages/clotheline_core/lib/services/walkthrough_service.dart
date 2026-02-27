import 'package:shared_preferences/shared_preferences.dart';

class WalkthroughService {
  static final WalkthroughService _instance = WalkthroughService._internal();
  factory WalkthroughService() => _instance;
  WalkthroughService._internal();

  // Keys
  static const String keyDashboard = 'walkthrough_seen_dashboard';
  static const String keyStore = 'walkthrough_seen_store';
  static const String keyCheckout = 'walkthrough_seen_checkout';

  Future<bool> hasSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  Future<void> markAsSeen(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyDashboard);
    await prefs.remove(keyStore);
    await prefs.remove(keyCheckout);
  }
}
