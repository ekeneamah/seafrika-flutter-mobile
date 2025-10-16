import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';
import '../services/messages_api_service.dart';
import 'business_context_provider.dart';

// Message filters state
class MessageFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final Set<MessageType> messageTypes;
  final Set<MessagePriority> priorities;
  final bool showRead;
  final bool showUnread;
  final String? searchQuery;

  MessageFilters({
    this.startDate,
    this.endDate,
    this.messageTypes = const {},
    this.priorities = const {},
    this.showRead = true,
    this.showUnread = true,
    this.searchQuery,
  });

  bool get hasActiveFilters =>
      startDate != null ||
      endDate != null ||
      messageTypes.isNotEmpty ||
      priorities.isNotEmpty ||
      !showRead ||
      !showUnread ||
      (searchQuery?.isNotEmpty ?? false);

  MessageFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    Set<MessageType>? messageTypes,
    Set<MessagePriority>? priorities,
    bool? showRead,
    bool? showUnread,
    String? searchQuery,
  }) {
    return MessageFilters(
      startDate: startDate,
      endDate: endDate,
      messageTypes: messageTypes ?? this.messageTypes,
      priorities: priorities ?? this.priorities,
      showRead: showRead ?? this.showRead,
      showUnread: showUnread ?? this.showUnread,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// Message filters notifier
class MessageFiltersNotifier extends StateNotifier<MessageFilters> {
  MessageFiltersNotifier() : super(MessageFilters());

  void setStartDate(DateTime? date) {
    state = state.copyWith(startDate: date);
  }

  void setEndDate(DateTime? date) {
    state = state.copyWith(endDate: date);
  }

  void toggleMessageType(MessageType type) {
    final types = Set<MessageType>.from(state.messageTypes);
    if (types.contains(type)) {
      types.remove(type);
    } else {
      types.add(type);
    }
    state = state.copyWith(messageTypes: types);
  }

  void togglePriority(MessagePriority priority) {
    final priorities = Set<MessagePriority>.from(state.priorities);
    if (priorities.contains(priority)) {
      priorities.remove(priority);
    } else {
      priorities.add(priority);
    }
    state = state.copyWith(priorities: priorities);
  }

  void setShowRead(bool show) {
    state = state.copyWith(showRead: show);
  }

  void setShowUnread(bool show) {
    state = state.copyWith(showUnread: show);
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearFilters() {
    state = MessageFilters();
  }
}

// Selected platforms notifier
class SelectedPlatformsNotifier extends StateNotifier<Set<MessagePlatform>> {
  SelectedPlatformsNotifier() : super({});

  void togglePlatform(MessagePlatform platform) {
    final platforms = Set<MessagePlatform>.from(state);
    if (platforms.contains(platform)) {
      platforms.remove(platform);
    } else {
      platforms.add(platform);
    }
    state = platforms;
  }

  void selectAll() {
    state = Set<MessagePlatform>.from(MessagePlatform.values);
  }

  void selectNone() {
    state = {};
  }

  void selectPlatforms(Set<MessagePlatform> platforms) {
    state = platforms;
  }
}

// Messages service - 3-tier flat structure
class MessagesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tier 1: Get integrations for a business (primary source of truth)
  Stream<List<Map<String, dynamic>>> getIntegrationsForBusiness(
      String businessId) {
    return _firestore
        .collection('integrations')
        .where('businessId', isEqualTo: businessId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Tier 2: Get conversations for a specific integration (no businessId needed)
  Stream<List<Conversation>> getConversationsByIntegration(
      String integrationId) {
    return _firestore
        .collection('conversations')
        .where('integrationId', isEqualTo: integrationId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Conversation.fromMap({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  // Helper: Get all conversations for a business (via integrations)
  Stream<List<Conversation>> getConversations(String businessId) {
    return getIntegrationsForBusiness(businessId)
        .asyncMap((integrations) async {
      List<Conversation> allConversations = [];

      for (var integration in integrations) {
        final conversationsQuery = await _firestore
            .collection('conversations')
            .where('integrationId', isEqualTo: integration['id'])
            .orderBy('lastMessageAt', descending: true)
            .get();

        final conversations = conversationsQuery.docs
            .map((doc) => Conversation.fromMap({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList();

        allConversations.addAll(conversations);
      }

      // Sort all conversations by lastMessageAt
      allConversations
          .sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return allConversations;
    });
  }

  // Tier 3: Get messages for a conversation (no businessId needed)
  Stream<List<Message>> getMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Message.fromMap({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }

  // Get messages with pagination
  Stream<List<Message>> getMessagesPaginated(
    String conversationId, {
    int limit = 50,
    Message? startAfter,
  }) {
    Query query = _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('createdAt', descending: true);

    // Apply pagination cursor if provided
    if (startAfter != null) {
      query = query.startAfter([Timestamp.fromDate(startAfter.createdAt)]);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Message.fromMap({
            'id': doc.id,
            ...data,
          });
        }).toList());
  }

  // Get conversation by ID (flat structure)
  Future<Conversation?> getConversation(String conversationId) async {
    final doc =
        await _firestore.collection('conversations').doc(conversationId).get();

    if (!doc.exists) return null;

    return Conversation.fromMap({
      'id': doc.id,
      ...doc.data()!,
    });
  }

  // Mark conversation as read (flat structure)
  Future<void> markConversationAsRead(String conversationId) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'unreadCount': 0,
      'isRead': true,
      'readAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Pin/unpin conversation (flat structure)
  Future<void> toggleConversationPin(
      String conversationId, bool isPinned) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({'isPinned': isPinned});
  }

  // Archive/unarchive conversation (flat structure)
  Future<void> toggleConversationArchive(
      String conversationId, bool isArchived) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({'isArchived': isArchived});
  }

  // Send message (3-tier flat structure with backend API call)
  Future<void> sendMessage(
    Message message, {
    required MessagesApiService apiService,
  }) async {
    // Get conversation to find integrationId and recipientId
    final conversationRef =
        _firestore.collection('conversations').doc(message.conversationId);
    final conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      throw Exception('Conversation not found: ${message.conversationId}');
    }

    final conversationData = conversationDoc.data()!;
    final integrationId = conversationData['integrationId'] as String?;
    final recipientId = conversationData['recipientId'] as String?;
    final platform = conversationData['platform'] as String?;

    if (integrationId == null || recipientId == null || platform == null) {
      throw Exception(
          'Missing required conversation data: integrationId=$integrationId, recipientId=$recipientId, platform=$platform');
    }

    // Create message document ID
    final messageRef = _firestore.collection('messages').doc();
    final messageId = messageRef.id;

    // Step 1: Write message to Firestore with status='sending'
    final batch = _firestore.batch();
    final messageData = message
        .copyWith(
          id: messageId,
          metadata: message.metadata.copyWith(status: MessageStatus.sending),
        )
        .toMap();
    batch.set(messageRef, messageData);

    // Update conversation in flat conversations collection
    batch.update(conversationRef, {
      'lastMessageAt': Timestamp.fromDate(message.createdAt),
      'lastMessageId': messageId,
      'lastMessagePreview': message.content.text ?? 'Media message',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'unreadCount': FieldValue.increment(1),
    });

    // Update integration messaging stats
    final integrationRef =
        _firestore.collection('integrations').doc(integrationId);
    batch.update(integrationRef, {
      'messagingStats.totalNewMessages': FieldValue.increment(1),
      'messagingStats.totalMessageCount': FieldValue.increment(1),
      'messagingStats.lastMessageDate': Timestamp.fromDate(message.createdAt),
      'messagingStats.lastMessageId': messageId,
      'messagingStats.lastMessagePreview':
          message.content.text ?? 'Media message',
    });

    await batch.commit();

    // Step 2: Call backend API to send message
    try {
      // Get first attachment URL if available (API supports single attachment)
      final attachmentUrl = message.content.attachments.isNotEmpty
          ? message.content.attachments.first.url
          : null;

      final response = await apiService.sendMessage(
        platform: platform.toLowerCase(),
        integrationId: integrationId,
        messageId: messageId,
        conversationId: message.conversationId,
        recipientId: recipientId,
        message: message.content.text ?? '',
        attachmentUrl: attachmentUrl,
      );

      // Backend will update message status to 'sent' in Firestore
      // Real-time listeners will automatically pick up this change
      debugPrint('✅ Message sent via backend API: $response');
    } catch (e) {
      // If API call fails, update status to 'failed' in Firestore
      debugPrint('❌ Backend API call failed: $e');
      await messageRef.update({
        'metadata.status': 'failed',
        'metadata.error': e.toString(),
        'updatedAt': Timestamp.now(),
      });
      rethrow;
    }
  }

  // Get message statistics (3-tier structure - get from integrations)
  Future<Map<String, int>> getMessageStats(String businessId) async {
    try {
      // Get all integrations for business and sum up their messaging stats
      final integrationsSnapshot = await _firestore
          .collection('integrations')
          .where('businessId', isEqualTo: businessId)
          .get();

      int totalConversations = 0;
      int unreadConversations = 0;
      int totalMessages = 0;
      int totalNewMessages = 0;

      for (final doc in integrationsSnapshot.docs) {
        final messagingStats =
            doc.data()['messagingStats'] as Map<String, dynamic>?;
        if (messagingStats != null) {
          totalConversations +=
              (messagingStats['totalConversations'] as int? ?? 0);
          totalMessages += (messagingStats['totalMessageCount'] as int? ?? 0);
          totalNewMessages += (messagingStats['totalNewMessages'] as int? ?? 0);
        }
      }

      // Get unread conversations count
      final unreadConversationsSnapshot = await _firestore
          .collection('conversations')
          .where('businessId', isEqualTo: businessId)
          .where('unreadCount', isGreaterThan: 0)
          .get();

      unreadConversations = unreadConversationsSnapshot.docs.length;

      return {
        'total': totalConversations,
        'unread': unreadConversations,
        'messages': totalMessages,
        'newMessages': totalNewMessages,
      };
    } catch (e) {
      return {
        'total': 0,
        'unread': 0,
        'pinned': 0,
        'archived': 0,
      };
    }
  }
}

// Providers
final messagesServiceProvider =
    Provider<MessagesService>((ref) => MessagesService());

final messagesApiServiceProvider =
    Provider<MessagesApiService>((ref) => MessagesApiService());

final messageFiltersProvider =
    StateNotifierProvider<MessageFiltersNotifier, MessageFilters>(
  (ref) => MessageFiltersNotifier(),
);

final selectedPlatformsProvider =
    StateNotifierProvider<SelectedPlatformsNotifier, Set<MessagePlatform>>(
  (ref) => SelectedPlatformsNotifier(),
);

// Current business provider using the proper business context
final currentBusinessProvider = Provider<String?>((ref) {
  return ref.watch(selectedBusinessIdProvider);
});

final messagesProvider = StreamProvider<List<Conversation>>((ref) {
  final businessId = ref.watch(currentBusinessProvider);
  if (businessId == null) {
    return Stream.value([]); // Return empty list if no business selected
  }
  final messagesService = ref.watch(messagesServiceProvider);
  return messagesService.getConversations(businessId);
});

final messagesProviderFiltered =
    StreamProvider.family<List<Conversation>, String?>((ref, integrationId) {
  final businessId = ref.watch(currentBusinessProvider);
  if (businessId == null) {
    return Stream.value([]); // Return empty list if no business selected
  }
  final messagesService = ref.watch(messagesServiceProvider);

  if (integrationId != null) {
    return messagesService.getConversationsByIntegration(integrationId);
  } else {
    return messagesService.getConversations(businessId);
  }
});

final conversationMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final messagesService = ref.watch(messagesServiceProvider);
  return messagesService.getMessages(conversationId);
});

final messageStatsProvider = FutureProvider<Map<String, int>>((ref) {
  final businessId = ref.watch(currentBusinessProvider);
  if (businessId == null) {
    return Future.value({}); // Return empty stats if no business selected
  }
  final messagesService = ref.watch(messagesServiceProvider);
  return messagesService.getMessageStats(businessId);
});

final conversationProvider =
    FutureProvider.family<Conversation?, String>((ref, conversationId) {
  final messagesService = ref.watch(messagesServiceProvider);
  return messagesService.getConversation(conversationId);
});
