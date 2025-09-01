/// Enum representing different loading states for async operations
enum LoadingState {
  /// Initial state - no operation has started
  initial,
  
  /// Loading state - operation is in progress
  loading,
  
  /// Success state - operation completed successfully
  success,
  
  /// Error state - operation failed
  error,
  
  /// Empty state - operation succeeded but returned no data
  empty,
  
  /// Timeout state - operation timed out
  timeout,
  
  /// Network error state - network connectivity issues
  networkError,
}

/// Extension to provide convenient state checks
extension LoadingStateExtension on LoadingState {
  /// Whether the operation is currently loading
  bool get isLoading => this == LoadingState.loading;
  
  /// Whether the operation completed successfully
  bool get isSuccess => this == LoadingState.success;
  
  /// Whether the operation failed
  bool get isError => this == LoadingState.error;
  
  /// Whether the operation is in initial state
  bool get isInitial => this == LoadingState.initial;
  
  /// Whether the operation resulted in empty data
  bool get isEmpty => this == LoadingState.empty;
  
  /// Whether the operation timed out
  bool get isTimeout => this == LoadingState.timeout;
  
  /// Whether there's a network error
  bool get isNetworkError => this == LoadingState.networkError;
  
  /// Whether the state indicates an error condition
  bool get hasError => isError || isTimeout || isNetworkError;
  
  /// Whether the operation has completed (success, error, or empty)
  bool get isCompleted => isSuccess || isEmpty || hasError;
}
