import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State class for message selection
class MessageSelectionState {
  final Set<String> selectedMessageIds;
  final bool isSelectionMode;
  final String? conversationId;

  const MessageSelectionState({
    this.selectedMessageIds = const {},
    this.isSelectionMode = false,
    this.conversationId,
  });

  MessageSelectionState copyWith({
    Set<String>? selectedMessageIds,
    bool? isSelectionMode,
    String? conversationId,
  }) {
    return MessageSelectionState(
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  bool isSelected(String messageId) {
    return selectedMessageIds.contains(messageId);
  }

  int get selectedCount => selectedMessageIds.length;

  bool get hasSelection => selectedMessageIds.isNotEmpty;

  MessageSelectionState clear() {
    return const MessageSelectionState();
  }
}

/// StateNotifier for managing message selection
class MessageSelectionNotifier extends StateNotifier<MessageSelectionState> {
  MessageSelectionNotifier() : super(const MessageSelectionState());

  /// Enter selection mode with the first selected message
  void enterSelectionMode(String messageId, String conversationId) {
    state = MessageSelectionState(
      selectedMessageIds: {messageId},
      isSelectionMode: true,
      conversationId: conversationId,
    );
  }

  /// Toggle selection of a message
  void toggleSelection(String messageId) {
    if (!state.isSelectionMode) return;

    final newSelection = Set<String>.from(state.selectedMessageIds);
    if (newSelection.contains(messageId)) {
      newSelection.remove(messageId);
    } else {
      newSelection.add(messageId);
    }

    // Exit selection mode if no messages selected
    if (newSelection.isEmpty) {
      exitSelectionMode();
    } else {
      state = state.copyWith(selectedMessageIds: newSelection);
    }
  }

  /// Select a message (add to selection)
  void selectMessage(String messageId) {
    if (!state.isSelectionMode) return;

    final newSelection = Set<String>.from(state.selectedMessageIds);
    newSelection.add(messageId);
    state = state.copyWith(selectedMessageIds: newSelection);
  }

  /// Deselect a message (remove from selection)
  void deselectMessage(String messageId) {
    if (!state.isSelectionMode) return;

    final newSelection = Set<String>.from(state.selectedMessageIds);
    newSelection.remove(messageId);

    if (newSelection.isEmpty) {
      exitSelectionMode();
    } else {
      state = state.copyWith(selectedMessageIds: newSelection);
    }
  }

  /// Select all messages in the conversation
  void selectAll(List<String> messageIds) {
    if (!state.isSelectionMode) return;

    state = state.copyWith(
      selectedMessageIds: Set<String>.from(messageIds),
    );
  }

  /// Deselect all messages but stay in selection mode
  void deselectAll() {
    if (!state.isSelectionMode) return;

    state = state.copyWith(
      selectedMessageIds: {},
    );
  }

  /// Exit selection mode and clear all selections
  void exitSelectionMode() {
    state = const MessageSelectionState();
  }

  /// Check if a message is selected
  bool isMessageSelected(String messageId) {
    return state.isSelected(messageId);
  }
}

/// Provider for message selection state
final messageSelectionProvider =
    StateNotifierProvider<MessageSelectionNotifier, MessageSelectionState>(
  (ref) => MessageSelectionNotifier(),
);
