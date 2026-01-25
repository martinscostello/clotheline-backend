import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  // Singleton
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();
  
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _controller.stream;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void initialize() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _updateStatus(result);
    });
    // Check initial
    _connectivity.checkConnectivity().then((result) => _updateStatus(result));
  }

  void _updateStatus(ConnectivityResult result) {
    bool hasConnection = result != ConnectivityResult.none;
    
    if (_isOnline != hasConnection) {
      _isOnline = hasConnection;
      _controller.add(_isOnline);
      debugPrint("Network Status Changed: ${_isOnline ? "ONLINE" : "OFFLINE"}");
    }
  }

  void dispose() {
    _controller.close();
  }
}
