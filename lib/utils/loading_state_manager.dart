import 'dart:async';
import 'package:flutter/material.dart';
import 'loading_state.dart';

/// Manages loading states for async operations with timeout and error handling
class LoadingStateManager extends ChangeNotifier {
  LoadingState _state = LoadingState.initial;
  String? _error;
  Timer? _timeoutTimer;
  final Duration timeoutDuration;

  LoadingStateManager({
    this.timeoutDuration = const Duration(seconds: 15),
  });

  // Getters
  LoadingState get state => _state;
  String? get error => _error;
  bool get hasError => _state.hasError;
  bool get isLoading => _state.isLoading;
  bool get hasInitialized => _state != LoadingState.initial;
  bool get isSuccess => _state.isSuccess;
  bool get isEmpty => _state.isEmpty;
  bool get isCompleted => _state.isCompleted;
  bool get isNetworkError => _state == LoadingState.networkError;
  bool get isTimeoutError => _state == LoadingState.timeout;

  /// Start loading with automatic timeout
  void startLoading() {
    _state = LoadingState.loading;
    _error = null;
    _startTimeout();
    notifyListeners();
  }

  /// Stop loading successfully
  void stopLoading() {
    _state = LoadingState.success;
    _error = null;
    _cancelTimeout();
    notifyListeners();
  }

  /// Stop loading with error
  void setError(String error) {
    _error = error;
    final lower = error.toLowerCase();
    if (lower.contains('timeout')) {
      _state = LoadingState.timeout;
    } else if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('resolve') ||
        lower.contains('host') ||
        lower.contains('unavailable') ||
        lower.contains('dns') ||
        lower.contains('unreachable')) {
      _state = LoadingState.networkError;
    } else {
      _state = LoadingState.error;
    }
    _cancelTimeout();
    notifyListeners();
  }

  /// Mark as empty (successful but no data)
  void setEmpty() {
    _state = LoadingState.empty;
    _error = null;
    _cancelTimeout();
    notifyListeners();
  }

  /// Reset state for retry
  void reset() {
    _state = LoadingState.initial;
    _error = null;
    _cancelTimeout();
    notifyListeners();
  }

  /// Start timeout timer
  void _startTimeout() {
    _cancelTimeout();
    _timeoutTimer = Timer(timeoutDuration, () {
      if (_state.isLoading) {
        _error = 'Connection timeout. Please check your internet connection.';
        _state = LoadingState.timeout;
        notifyListeners();
      }
    });
  }

  /// Cancel timeout timer
  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Dispose resources
  @override
  void dispose() {
    _cancelTimeout();
    super.dispose();
  }
}

/// Extension to add common error messages
extension LoadingStateManagerExtensions on LoadingStateManager {
  String get errorTitle {
    if (isTimeoutError) return 'Connection Timeout';
    if (isNetworkError) return 'Connection Problem';
    return 'Error';
  }

  String get errorMessage {
    if (isTimeoutError) {
      return 'The request took too long. Please check your connection and try again.';
    }
    if (isNetworkError) {
      return 'Please check your internet connection and try again.';
    }
    return error ?? 'An unexpected error occurred.';
  }

  IconData get errorIcon {
    if (isNetworkError) return Icons.cloud_off_outlined;
    return Icons.error_outline;
  }
}
