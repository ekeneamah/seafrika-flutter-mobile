import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/reactions_api_service.dart';

/// Provider for reactions API service
final reactionsApiServiceProvider = Provider<ReactionsApiService>((ref) {
  return ReactionsApiService();
});

/// Provider to add a reaction to a message
final addReactionProvider = FutureProvider.family.autoDispose<
    Map<String, dynamic>,
    AddReactionParams>((ref, params) async {
  final service = ref.read(reactionsApiServiceProvider);
  return await service.addReaction(
    messageId: params.messageId,
    userId: params.userId,
    businessId: params.businessId,
    emoji: params.emoji,
    userName: params.userName,
    platform: params.platform,
  );
});

/// Provider to remove a reaction from a message
final removeReactionProvider = FutureProvider.family.autoDispose<
    void,
    RemoveReactionParams>((ref, params) async {
  final service = ref.read(reactionsApiServiceProvider);
  await service.removeReaction(
    messageId: params.messageId,
    reactionId: params.reactionId,
  );
});

/// Provider to get all reactions for a message
final messageReactionsProvider = FutureProvider.family.autoDispose<
    List<Map<String, dynamic>>,
    String>((ref, messageId) async {
  final service = ref.read(reactionsApiServiceProvider);
  return await service.getReactions(messageId: messageId);
});

/// Parameters for adding a reaction
class AddReactionParams {
  final String messageId;
  final String userId;
  final String businessId;
  final String emoji;
  final String? userName;
  final String? platform;

  AddReactionParams({
    required this.messageId,
    required this.userId,
    required this.businessId,
    required this.emoji,
    this.userName,
    this.platform,
  });
}

/// Parameters for removing a reaction
class RemoveReactionParams {
  final String messageId;
  final String reactionId;

  RemoveReactionParams({
    required this.messageId,
    required this.reactionId,
  });
}
