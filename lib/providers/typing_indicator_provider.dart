import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/typing_indicator_service.dart';

/// Provider for TypingIndicatorService
final typingIndicatorServiceProvider = Provider<TypingIndicatorService>((ref) {
  return TypingIndicatorService();
});

/// Provider for typing users stream in a specific conversation
///
/// Usage:
/// ```dart
/// final typingUsers = ref.watch(typingUsersProvider(conversationParams));
///
/// typingUsers.when(
///   data: (users) => users.isNotEmpty
///     ? Text('${users.first.displayText}')
///     : SizedBox.shrink(),
///   loading: () => SizedBox.shrink(),
///   error: (_, __) => SizedBox.shrink(),
/// );
/// ```
final typingUsersProvider = StreamProvider.autoDispose
    .family<List<TypingUser>, TypingUsersParams>((ref, params) {
  final service = ref.watch(typingIndicatorServiceProvider);

  return service.getTypingUsers(
    businessId: params.businessId,
    integrationId: params.integrationId,
    conversationId: params.conversationId,
  );
});

/// Parameters for typing users provider
class TypingUsersParams {
  final String businessId;
  final String integrationId;
  final String conversationId;

  TypingUsersParams({
    required this.businessId,
    required this.integrationId,
    required this.conversationId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypingUsersParams &&
          runtimeType == other.runtimeType &&
          businessId == other.businessId &&
          integrationId == other.integrationId &&
          conversationId == other.conversationId;

  @override
  int get hashCode =>
      businessId.hashCode ^ integrationId.hashCode ^ conversationId.hashCode;
}
