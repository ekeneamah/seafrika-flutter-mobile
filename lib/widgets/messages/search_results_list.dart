import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/message.dart';

/// Search results list with highlighting and navigation
class SearchResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final String query;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final Function(String messageId, String conversationId) onResultTap;
  final String? emptyMessage;

  const SearchResultsList({
    Key? key,
    required this.results,
    required this.query,
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    required this.onResultTap,
    this.emptyMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading && results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (results.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == results.length) {
          // Load more indicator
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: onLoadMore,
                      child: const Text('Load More'),
                    ),
            ),
          );
        }

        final result = results[index];
        return SearchResultItem(
          result: result,
          query: query,
          onTap: () => onResultTap(
            result['id'],
            result['conversationId'],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No messages found',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual search result item with highlighting
class SearchResultItem extends StatelessWidget {
  final Map<String, dynamic> result;
  final String query;
  final VoidCallback onTap;

  const SearchResultItem({
    Key? key,
    required this.result,
    required this.query,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senderName = result['sender']?['name'] ?? 'Unknown';
    final messageText = result['content']?['text'] ?? '';
    final highlightedText = result['highlightedText'] ?? messageText;
    final createdAt = _parseDateTime(result['createdAt']);
    final platform = result['platform'] ?? 'app';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header (sender + time + platform)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      senderName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPlatformIcon(platform, theme),
                  const SizedBox(width: 4),
                  Text(
                    createdAt != null ? timeago.format(createdAt) : '',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Message content with highlighting
              _buildHighlightedText(
                context,
                highlightedText,
                messageText,
                theme,
              ),

              // Attachment indicator
              if (_hasAttachments(result)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getAttachmentText(result),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformIcon(String platform, ThemeData theme) {
    IconData icon;
    Color color;

    switch (platform.toLowerCase()) {
      case 'messenger':
        icon = Icons.messenger_outlined;
        color = Colors.blue;
        break;
      case 'instagram':
        icon = Icons.camera_alt_outlined;
        color = Colors.pink;
        break;
      case 'whatsapp':
        icon = Icons.chat_bubble_outline;
        color = Colors.green;
        break;
      default:
        icon = Icons.phone_android;
        color = theme.colorScheme.primary;
    }

    return Icon(icon, size: 14, color: color);
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String highlightedText,
    String plainText,
    ThemeData theme,
  ) {
    // Remove HTML tags for display and apply Flutter-style highlighting
    final textToDisplay = highlightedText.replaceAll(RegExp(r'<[^>]*>'), '');

    // Find all occurrences of the query (case-insensitive)
    final queryLower = query.toLowerCase();
    final textLower = textToDisplay.toLowerCase();

    final spans = <TextSpan>[];
    int lastIndex = 0;

    while (lastIndex < textToDisplay.length) {
      final index = textLower.indexOf(queryLower, lastIndex);
      if (index == -1) {
        // Add remaining text
        spans.add(TextSpan(
          text: textToDisplay.substring(lastIndex),
        ));
        break;
      }

      // Add text before match
      if (index > lastIndex) {
        spans.add(TextSpan(
          text: textToDisplay.substring(lastIndex, index),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: textToDisplay.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: theme.colorScheme.primaryContainer,
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ));

      lastIndex = index + query.length;
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 13,
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
        children: spans,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  bool _hasAttachments(Map<String, dynamic> result) {
    final attachments = result['content']?['attachments'];
    return attachments != null && attachments is List && attachments.isNotEmpty;
  }

  String _getAttachmentText(Map<String, dynamic> result) {
    final attachments = result['content']?['attachments'] as List?;
    if (attachments == null || attachments.isEmpty) return '';

    final count = attachments.length;
    final type = attachments.first['type'] ?? 'file';

    if (count == 1) {
      return '1 $type';
    }
    return '$count attachments';
  }

  DateTime? _parseDateTime(dynamic timestamp) {
    if (timestamp == null) return null;

    try {
      if (timestamp is Map && timestamp.containsKey('_seconds')) {
        // Firestore Timestamp
        return DateTime.fromMillisecondsSinceEpoch(
          timestamp['_seconds'] * 1000,
        );
      } else if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
    }

    return null;
  }
}

/// Search statistics widget
class SearchStats extends StatelessWidget {
  final int totalResults;
  final String query;
  final Duration? searchDuration;

  const SearchStats({
    Key? key,
    required this.totalResults,
    required this.query,
    this.searchDuration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '$totalResults result${totalResults == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (searchDuration != null) ...[
            const SizedBox(width: 8),
            Text(
              '(${searchDuration!.inMilliseconds}ms)',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
