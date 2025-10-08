import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import 'messages_provider.dart';
import 'business_context_provider.dart';

// Provider for messages in a specific conversation
final messagesProvider =
    FutureProvider.family<List<Message>, String>((ref, conversationId) async {
  final messagesService = ref.watch(messagesServiceProvider);
  final businessContext = ref.watch(businessContextProvider);

  if (businessContext == null) {
    throw Exception('Business context not available');
  }

  return await messagesService
      .getMessages(businessContext.id, conversationId)
      .first;
});

// Provider for real-time messages stream
final messagesStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final messagesService = ref.watch(messagesServiceProvider);
  final businessContext = ref.watch(businessContextProvider);

  if (businessContext == null) {
    throw Exception('Business context not available');
  }

  return messagesService.getMessages(businessContext.id, conversationId);
});

// Provider for conversations using existing messagesProvider from messages_provider.dart
final conversationsProvider = messagesProvider;

// Provider for sending messages
final sendMessageProvider =
    Provider<Future<void> Function(String conversationId, String content)>(
        (ref) {
  return (String conversationId, String content) async {
    final messagesService = ref.read(messagesServiceProvider);
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

    await messagesService.sendMessage(businessContext.id, message);

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

    await messagesService.markConversationAsRead(
        businessContext.id, conversationId);

    // Refresh conversations to update unread counts
    ref.invalidate(messagesProvider);
  };
});
