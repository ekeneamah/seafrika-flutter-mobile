import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/threads_api_service.dart';
import 'message_bubble.dart';

/// Widget to display full thread view with all replies
class ThreadView extends ConsumerStatefulWidget {
  final String parentMessageId;

  const ThreadView({
    Key? key,
    required this.parentMessageId,
  }) : super(key: key);

  @override
  ConsumerState<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends ConsumerState<ThreadView> {
  final ThreadsApiService _threadsService = ThreadsApiService();
  bool _isLoading = true;
  ThreadResponse? _threadData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  Future<void> _loadThread() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final threadData = await _threadsService.getThreadMessages(widget.parentMessageId);
      setState(() {
        _threadData = threadData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thread (${_threadData?.replyCount ?? 0} replies)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadThread,
            tooltip: 'Refresh thread',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading thread',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadThread,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_threadData == null || _threadData!.messages.isEmpty) {
      return const Center(
        child: Text('No messages in thread'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _threadData!.messages.length,
      itemBuilder: (context, index) {
        final message = _threadData!.messages[index];
        final isParent = message.id == widget.parentMessageId;
        final threadDepth = message.metadata.threadDepth ?? 0;

        return Padding(
          padding: EdgeInsets.only(
            left: threadDepth * 24.0, // Indent based on thread depth
            bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isParent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.forum,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Original Message',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              MessageBubble(
                message: message,
                showAvatar: true,
                showTimestamp: true,
              ),
              if (message.metadata.replyCount != null && message.metadata.replyCount! > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 16),
                  child: Text(
                    '${message.metadata.replyCount} ${message.metadata.replyCount == 1 ? 'reply' : 'replies'}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
