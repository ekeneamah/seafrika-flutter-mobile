import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor network connectivity and trigger queue processing
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;

  // Callbacks for connectivity changes
  final List<VoidCallback> _onOnlineCallbacks = [];
  final List<VoidCallback> _onOfflineCallbacks = [];

  bool _isOnline = true;
  bool _initialized = false;

  /// Get current online status
  bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _updateConnectivity(result);

      // Listen to connectivity changes
      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectivity,
        onError: (error) {
          debugPrint('❌ Connectivity listener error: $error');
        },
      );

      _initialized = true;
      debugPrint('✅ Connectivity service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing connectivity service: $e');
    }
  }

  /// Update connectivity status
  void _updateConnectivity(ConnectivityResult result) {
    final wasOnline = _isOnline;

    // Check if connection type is available
    _isOnline = result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn;

    // Log connectivity change
    if (wasOnline != _isOnline) {
      if (_isOnline) {
        debugPrint('🟢 Device is ONLINE ($result)');
        _notifyOnline();
      } else {
        debugPrint('🔴 Device is OFFLINE');
        _notifyOffline();
      }
    }
  }

  /// Register callback for when device goes online
  void onOnline(VoidCallback callback) {
    _onOnlineCallbacks.add(callback);
  }

  /// Register callback for when device goes offline
  void onOffline(VoidCallback callback) {
    _onOfflineCallbacks.add(callback);
  }

  /// Remove online callback
  void removeOnlineCallback(VoidCallback callback) {
    _onOnlineCallbacks.remove(callback);
  }

  /// Remove offline callback
  void removeOfflineCallback(VoidCallback callback) {
    _onOfflineCallbacks.remove(callback);
  }

  /// Notify all online callbacks
  void _notifyOnline() {
    for (final callback in _onOnlineCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ Error in online callback: $e');
      }
    }
  }

  /// Notify all offline callbacks
  void _notifyOffline() {
    for (final callback in _onOfflineCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ Error in offline callback: $e');
      }
    }
  }

  /// Check if device is currently online
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      return false;
    }
  }

  /// Get connectivity stream
  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map((result) {
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn;
    });
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _onOnlineCallbacks.clear();
    _onOfflineCallbacks.clear();
    _initialized = false;
    debugPrint('🗑️ Connectivity service disposed');
  }
}
