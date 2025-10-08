import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../providers/messages_provider.dart';

// Social media stats model
class SocialMediaStats {
  final Map<MessagePlatform, int> unreadCounts;
  final Map<MessagePlatform, int> totalCounts;
  final int totalUnread;
  final int totalMessages;
  final MessagePlatform? mostActiveplatform;

  SocialMediaStats({
    required this.unreadCounts,
    required this.totalCounts,
    required this.totalUnread,
    required this.totalMessages,
    this.mostActiveplatform,
  });

  static SocialMediaStats empty() {
    return SocialMediaStats(
      unreadCounts: {},
      totalCounts: {},
      totalUnread: 0,
      totalMessages: 0,
    );
  }
}

// Provider for social media stats
final socialMediaStatsProvider = FutureProvider<SocialMediaStats>((ref) async {
  try {
    final businessId = ref.watch(currentBusinessProvider);

    if (businessId == null) {
      // Return empty stats if no business selected
      return SocialMediaStats.empty();
    }

    final messagesService = ref.watch(messagesServiceProvider);

    // Get basic message stats
    final basicStats = await messagesService.getMessageStats(businessId);

    // Get platform-specific stats
    final platformStats = await messagesService.getPlatformStats(businessId);

    return SocialMediaStats(
      unreadCounts: platformStats['unreadCounts'] ?? {},
      totalCounts: platformStats['totalCounts'] ?? {},
      totalUnread: basicStats['unread'] ?? 0,
      totalMessages: basicStats['total'] ?? 0,
      mostActiveplatform: platformStats['mostActive'],
    );
  } catch (e) {
    return SocialMediaStats.empty();
  }
});

// Extension to MessagesService for platform stats
extension MessagesServiceExtension on MessagesService {
  Future<Map<String, dynamic>> getPlatformStats(String businessId) async {
    try {
      final conversations = await getConversationsOnce(businessId);

      final Map<MessagePlatform, int> unreadCounts = {};
      final Map<MessagePlatform, int> totalCounts = {};

      for (final conversation in conversations) {
        final platform = conversation.platform;

        // Count total conversations per platform
        totalCounts[platform] = (totalCounts[platform] ?? 0) + 1;

        // Count unread conversations per platform
        if (conversation.unreadCount > 0) {
          unreadCounts[platform] = (unreadCounts[platform] ?? 0) + 1;
        }
      }

      // Find most active platform
      MessagePlatform? mostActive;
      int maxCount = 0;
      for (final entry in totalCounts.entries) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
          mostActive = entry.key;
        }
      }

      return {
        'unreadCounts': unreadCounts,
        'totalCounts': totalCounts,
        'mostActive': mostActive,
      };
    } catch (e) {
      return {
        'unreadCounts': <MessagePlatform, int>{},
        'totalCounts': <MessagePlatform, int>{},
        'mostActive': null,
      };
    }
  }

  Future<List<Conversation>> getConversationsOnce(String businessId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('conversations')
        .get();

    return snapshot.docs
        .map((doc) => Conversation.fromMap({
              'id': doc.id,
              ...doc.data(),
            }))
        .toList();
  }
}
