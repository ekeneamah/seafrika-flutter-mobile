import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/offline_message_queue.dart';

/// Provider for queue count stream
final queueCountProvider =
    StreamProvider.family<int, String>((ref, businessId) {
  final queue = OfflineMessageQueue();
  return queue.watchQueueCount(businessId);
});

/// Badge to show number of queued messages
class QueueCountBadge extends ConsumerWidget {
  final String businessId;
  final VoidCallback? onTap;

  const QueueCountBadge({
    super.key,
    required this.businessId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueCountAsync = ref.watch(queueCountProvider(businessId));

    return queueCountAsync.when(
      data: (count) {
        if (count == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.shade700.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$count queued',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Small badge for showing queue count in app bar
class CompactQueueCountBadge extends ConsumerWidget {
  final String businessId;

  const CompactQueueCountBadge({
    super.key,
    required this.businessId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueCountAsync = ref.watch(queueCountProvider(businessId));

    return queueCountAsync.when(
      data: (count) {
        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: const BoxConstraints(
            minWidth: 20,
            minHeight: 20,
          ),
          child: Center(
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
