import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/attachment_cache_service.dart';
import 'messages_provider.dart';
import 'business_context_provider.dart';

// Provider for attachment cache service (singleton)
final attachmentCacheServiceProvider = Provider<AttachmentCacheService>((ref) {
  return AttachmentCacheService();
});

// Provider for messages in a specific conversation
final messagesProvider =
    FutureProvider.family<List<Message>, String>((ref, conversationId) async {
  final messagesService = ref.watch(messagesServiceProvider);
  final businessContext = ref.watch(businessContextProvider);

  if (businessContext == null) {
    throw Exception('Business context not available');
  }

  return await messagesService.getMessages(conversationId).first;
});

// Provider for real-time messages stream
final messagesStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final messagesService = ref.watch(messagesServiceProvider);
  final businessContext = ref.watch(businessContextProvider);

  if (businessContext == null) {
    throw Exception('Business context not available');
  }

  return messagesService.getMessages(conversationId);
});

// Provider for conversations using existing messagesProvider from messages_provider.dart
final conversationsProvider = messagesProvider;

// Provider for sending messages
final sendMessageProvider =
    Provider<Future<void> Function(String conversationId, String content)>(
        (ref) {
  return (String conversationId, String content) async {
    final messagesService = ref.read(messagesServiceProvider);
    final messagesApiService = ref.read(messagesApiServiceProvider);
    final businessContext = ref.read(businessContextProvider);

    if (businessContext == null) {
      throw Exception('Business context not available');
    }

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      businessId: businessContext.id,
      integrationId: '', // TODO: Get from conversation
      conversationId: conversationId,
      platform: MessagePlatform.website, // TODO: Get from conversation
      type: MessageType.text,
      content: MessageContent(text: content),
      sender: MessageSender(
        id: 'current_user', // TODO: Get actual user ID
        name: 'You',
        isCustomer: false,
      ),
      recipient: MessageRecipient(
        id: 'customer',
        name: 'Customer',
      ),
      metadata: MessageMetadata(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        source: 'mobile_app',
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await messagesService.sendMessage(message, apiService: messagesApiService);

    // Refresh the messages for this conversation
    ref.invalidate(messagesProvider(conversationId));
  };
});

// Provider for marking messages as read
final markAsReadProvider =
    Provider<Future<void> Function(String conversationId)>((ref) {
  return (String conversationId) async {
    final messagesService = ref.read(messagesServiceProvider);
    final businessContext = ref.read(businessContextProvider);

    if (businessContext == null) {
      throw Exception('Business context not available');
    }

    await messagesService.markConversationAsRead(conversationId);

    // Refresh conversations to update unread counts
    ref.invalidate(messagesProvider);
  };
});

// Paginated Messages State
class PaginatedMessagesState {
  final List<Message> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final bool isLoadingMore;

  const PaginatedMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.isLoadingMore = false,
  });

  PaginatedMessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
    bool? isLoadingMore,
  }) {
    return PaginatedMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

// Paginated Messages Notifier
class PaginatedMessagesNotifier extends StateNotifier<PaginatedMessagesState> {
  static const int pageSize = 50;
  final String conversationId;
  final MessagesService messagesService;

  Message? _lastMessage;

  PaginatedMessagesNotifier({
    required this.conversationId,
    required this.messagesService,
  }) : super(const PaginatedMessagesState()) {
    loadInitialMessages();
  }

  // Load initial batch of messages
  Future<void> loadInitialMessages() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = await messagesService
          .getMessagesPaginated(conversationId, limit: pageSize)
          .first;

      _lastMessage = messages.isNotEmpty ? messages.last : null;

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        hasMore: messages.length >= pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // Load more messages (pagination)
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || _lastMessage == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final moreMessages = await messagesService
          .getMessagesPaginated(
            conversationId,
            limit: pageSize,
            startAfter: _lastMessage,
          )
          .first;

      if (moreMessages.isEmpty) {
        state = state.copyWith(
          isLoadingMore: false,
          hasMore: false,
        );
        return;
      }

      _lastMessage = moreMessages.last;

      state = state.copyWith(
        messages: [...state.messages, ...moreMessages],
        isLoadingMore: false,
        hasMore: moreMessages.length >= pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  // Refresh messages
  Future<void> refresh() async {
    _lastMessage = null;
    state = const PaginatedMessagesState();
    await loadInitialMessages();
  }

  // Add a new message optimistically
  void addOptimisticMessage(Message message) {
    state = state.copyWith(
      messages: [message, ...state.messages],
    );
  }

  // Update a message (e.g., after confirmation)
  void updateMessage(String tempId, Message confirmedMessage) {
    final updatedMessages = state.messages.map((m) {
      return m.id == tempId ? confirmedMessage : m;
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  // Remove a message (e.g., failed send)
  void removeMessage(String messageId) {
    final updatedMessages =
        state.messages.where((m) => m.id != messageId).toList();

    state = state.copyWith(messages: updatedMessages);
  }
}

// Provider for paginated messages
final paginatedMessagesProvider = StateNotifierProvider.family<
    PaginatedMessagesNotifier,
    PaginatedMessagesState,
    String>((ref, conversationId) {
  final messagesService = ref.watch(messagesServiceProvider);

  return PaginatedMessagesNotifier(
    conversationId: conversationId,
    messagesService: messagesService,
  );
});
