import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/message_selection_provider.dart';

/// Action bar shown when messages are selected
class MessageSelectionActionBar extends ConsumerWidget {
  final VoidCallback onDelete;
  final VoidCallback onForward;
  final VoidCallback onCopy;
  final VoidCallback? onSelectAll;
  final int totalMessageCount;

  const MessageSelectionActionBar({
    Key? key,
    required this.onDelete,
    required this.onForward,
    required this.onCopy,
    this.onSelectAll,
    required this.totalMessageCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionState = ref.watch(messageSelectionProvider);
    final selectionNotifier = ref.read(messageSelectionProvider.notifier);

    if (!selectionState.isSelectionMode) {
      return const SizedBox.shrink();
    }

    final selectedCount = selectionState.selectedCount;
    final allSelected = selectedCount == totalMessageCount;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Close/Cancel button
          IconButton(
            onPressed: () {
              selectionNotifier.exitSelectionMode();
            },
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Cancel',
          ),

          // Selected count
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Select All / Deselect All button
          if (onSelectAll != null)
            IconButton(
              onPressed: () {
                if (allSelected) {
                  selectionNotifier.deselectAll();
                } else {
                  onSelectAll!();
                }
              },
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
                color: Colors.white,
              ),
              tooltip: allSelected ? 'Deselect All' : 'Select All',
            ),

          // Copy button
          IconButton(
            onPressed: selectedCount > 0 ? onCopy : null,
            icon: const Icon(Icons.copy, color: Colors.white),
            tooltip: 'Copy',
          ),

          // Forward button
          IconButton(
            onPressed: selectedCount > 0 ? onForward : null,
            icon: const Icon(Icons.forward, color: Colors.white),
            tooltip: 'Forward',
          ),

          // Delete button
          IconButton(
            onPressed: selectedCount > 0 ? () => _confirmDelete(context) : null,
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Delete',
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages'),
        content: Consumer(
          builder: (context, ref, _) {
            final selectedCount =
                ref.watch(messageSelectionProvider).selectedCount;
            return Text(
              'Are you sure you want to delete $selectedCount message${selectedCount > 1 ? 's' : ''}?',
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Compact action bar for mobile with icons only
class CompactMessageSelectionActionBar extends ConsumerWidget {
  final VoidCallback onDelete;
  final VoidCallback onForward;
  final VoidCallback onCopy;

  const CompactMessageSelectionActionBar({
    Key? key,
    required this.onDelete,
    required this.onForward,
    required this.onCopy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionState = ref.watch(messageSelectionProvider);
    final selectionNotifier = ref.read(messageSelectionProvider.notifier);

    if (!selectionState.isSelectionMode) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () => selectionNotifier.exitSelectionMode(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
          Text(
            '${selectionState.selectedCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy, color: Colors.white, size: 20),
          ),
          IconButton(
            onPressed: onForward,
            icon: const Icon(Icons.forward, color: Colors.white, size: 20),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
