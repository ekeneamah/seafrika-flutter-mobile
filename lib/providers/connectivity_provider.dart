import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';

/// Provider for connectivity service singleton
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();

  // Initialize on first access
  service.initialize();

  // Register callback to process queue when device goes online
  service.onOnline(() {
    _processQueueOnOnline(ref);
  });

  // Cleanup on dispose
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Provider for current connectivity status stream
final connectivityStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectivityStream;
});

/// Provider for current connectivity status (synchronous)
final isOnlineProvider = Provider<bool>((ref) {
  final asyncStatus = ref.watch(connectivityStatusProvider);
  return asyncStatus.value ?? true; // Assume online by default
});

/// Process queued messages when device goes online
Future<void> _processQueueOnOnline(ProviderRef ref) async {
  try {
    // Backend scheduler automatically processes the queue every 5 minutes
    // No need for manual processing here - just log the event
    print('🟢 Device online - backend will process queue automatically');

    // Optional future enhancement: Trigger immediate queue processing
    // This would require a new endpoint like POST /api/messages/queue/process-now
    // Example:
    // final queueApiService = QueueApiService();
    // await queueApiService.triggerQueueProcessing();
  } catch (e) {
    print('❌ Error in online callback: $e');
  }
}
