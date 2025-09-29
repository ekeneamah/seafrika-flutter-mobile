import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';

class InstagramPostsScreen extends ConsumerStatefulWidget {
  final String integrationId;

  const InstagramPostsScreen({
    super.key,
    required this.integrationId,
  });

  @override
  ConsumerState<InstagramPostsScreen> createState() =>
      _InstagramPostsScreenState();
}

class _InstagramPostsScreenState extends ConsumerState<InstagramPostsScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _posts = [];
  String? _nextCursor;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _posts.clear();
        _nextCursor = null;
        _hasMore = true;
        _error = null;
      });
    }

    setState(() {
      _isLoading = refresh || _posts.isEmpty;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      final result = await integrationService.getInstagramMedia(
        widget.integrationId,
        limit: _pageSize,
        after: refresh ? null : null, // Always start fresh for refresh
      );

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(result['items'] ?? []);
          _nextCursor = result['nextCursor'];
          _hasMore = result['hasMore'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load posts: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (!_hasMore || _nextCursor == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      final result = await integrationService.getInstagramMedia(
        widget.integrationId,
        limit: _pageSize,
        after: _nextCursor,
      );

      if (mounted) {
        setState(() {
          _posts.addAll(List<Map<String, dynamic>>.from(result['items'] ?? []));
          _nextCursor = result['nextCursor'];
          _hasMore = result['hasMore'] ?? false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load more posts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadPosts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'Instagram Posts',
        actions: [
          IconButton(
            onPressed: () => _loadPosts(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePostDialog,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadPosts(refresh: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: _buildPostsContent(),
                ),
    );
  }

  Widget _buildPostsContent() {
    if (_posts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No posts found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Your Instagram posts will appear here once you start posting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with stats
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFFE1306C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Posts',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_posts.length} posts loaded${_hasMore ? ' • Scroll for more' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),

        // Posts list with infinite scroll
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _posts.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Show loading indicator at the end if there are more posts
              if (index == _posts.length) {
                if (_isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else {
                  // This should not happen since we check _hasMore
                  return const SizedBox.shrink();
                }
              }

              final post = _posts[index];
              return _buildPostCard(post);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final mediaType = post['media_type'] ?? 'IMAGE';
    final isVideo = mediaType == 'VIDEO';
    final caption = post['caption'] ?? '';
    final timestamp = post['timestamp'] ?? '';
    final likeCount = post['like_count'] ?? 0;
    final commentsCount = post['comments_count'] ?? 0;
    final permalink = post['permalink'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media preview
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: post['media_url'] != null
                      ? Image.network(
                          // For videos, use thumbnail_url if available, otherwise fallback to media_url
                          isVideo && post['thumbnail_url'] != null
                              ? post['thumbnail_url']
                              : post['media_url'],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.photo,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),

              // Media type indicator
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isVideo ? Icons.play_arrow : Icons.photo,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        mediaType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Post content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Caption
                if (caption.isNotEmpty) ...[
                  Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],

                // Engagement metrics
                Row(
                  children: [
                    _buildMetricChip(
                      Icons.favorite,
                      likeCount.toString(),
                      Colors.red,
                    ),
                    const SizedBox(width: 12),
                    _buildMetricChip(
                      Icons.comment,
                      commentsCount.toString(),
                      Colors.blue,
                    ),
                    const Spacer(),
                    if (timestamp.isNotEmpty)
                      Text(
                        _formatDate(timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openInstagramPost(permalink),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('View on Instagram'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(
                              color: AppTheme.primary.withOpacity(0.3)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _viewComments(post),
                      icon: const Icon(Icons.comment_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        foregroundColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => _sharePost(post),
                      icon: const Icon(Icons.share),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        foregroundColor: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInstagramPost(String permalink) async {
    if (permalink.isNotEmpty) {
      final uri = Uri.parse(permalink);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _sharePost(Map<String, dynamic> post) {
    final caption = post['caption'] ?? '';
    final permalink = post['permalink'] ?? '';

    String shareText = '';
    if (caption.isNotEmpty) {
      shareText = caption;
      if (permalink.isNotEmpty) {
        shareText += '\n\nView on Instagram: $permalink';
      }
    } else if (permalink.isNotEmpty) {
      shareText = 'Check out this post on Instagram: $permalink';
    } else {
      shareText = 'Check out this Instagram post!';
    }

    Share.share(shareText, subject: 'Instagram Post');
  }

  void _viewComments(Map<String, dynamic> post) {
    final commentsCount = post['comments_count'] ?? 0;
    final postId = post['id'] ?? '';

    if (commentsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This post has no comments'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCommentsSheet(postId, commentsCount),
    );
  }

  Widget _buildCommentsSheet(String postId, int commentsCount) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.comment, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Comments ($commentsCount)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Comments content
              Expanded(
                child: _buildCommentsContent(postId, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentsContent(
      String postId, ScrollController scrollController) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadCommentsForPost(postId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Failed to load comments\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Trigger rebuild to retry
                    Navigator.pop(context);
                    _viewComments({'id': postId, 'comments_count': 1});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final comments = snapshot.data ?? [];

        if (comments.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No comments available',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Comments might not be accessible through the API or this post has no comments.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return _buildCommentItem(comment);
          },
        );
      },
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final text = comment['text'] ?? '';
    final username = comment['username'] ?? 'Unknown User';
    final timestamp = comment['timestamp'] ?? '';
    final likeCount = comment['like_count'] ?? 0;
    final commentId = comment['id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[100],
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (timestamp.isNotEmpty)
                      Text(
                        _formatDate(timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              if (likeCount > 0) ...[
                Icon(Icons.favorite, size: 14, color: Colors.red[300]),
                const SizedBox(width: 4),
                Text(
                  likeCount.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[300],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showReplyDialog(commentId, username),
                icon: const Icon(Icons.reply, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadCommentsForPost(String postId) async {
    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      final result = await integrationService.getInstagramComments(
          widget.integrationId, postId);
      return List<Map<String, dynamic>>.from(result['comments'] ?? []);
    } catch (e) {
      throw Exception('Failed to load comments: $e');
    }
  }

  void _showReplyDialog(String commentId, String username) {
    final TextEditingController replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reply to @$username'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: replyController,
                decoration: const InputDecoration(
                  hintText: 'Write your reply...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 1000,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final reply = replyController.text.trim();
                if (reply.isNotEmpty) {
                  Navigator.pop(context);
                  await _replyToComment(commentId, reply, username);
                }
              },
              child: const Text('Reply'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _replyToComment(
      String commentId, String message, String username) async {
    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      // Find the post ID from current context (we need to track this)
      // For now, we'll use a placeholder - in a real implementation,
      // you'd need to track which post's comments are being viewed
      String postId =
          'current_post_id'; // This should be tracked when viewing comments

      final result = await integrationService.replyToInstagramComment(
        widget.integrationId,
        postId,
        commentId,
        message,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply posted to @$username'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post reply: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          _CreatePostDialog(integrationId: widget.integrationId),
    );
  }

  String _formatDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}

class _CreatePostDialog extends ConsumerStatefulWidget {
  final String integrationId;

  const _CreatePostDialog({required this.integrationId});

  @override
  ConsumerState<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends ConsumerState<_CreatePostDialog> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  String _selectedMediaType = 'IMAGE';
  bool _isCreating = false;

  @override
  void dispose() {
    _captionController.dispose();
    _imageUrlController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Instagram Post'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Media Type Selection
            DropdownButtonFormField<String>(
              value: _selectedMediaType,
              decoration: const InputDecoration(
                labelText: 'Media Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'IMAGE', child: Text('Image')),
                DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedMediaType = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Media URL Input
            if (_selectedMediaType == 'IMAGE')
              TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://example.com/image.jpg',
                  border: OutlineInputBorder(),
                ),
              )
            else
              TextField(
                controller: _videoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Video URL',
                  hintText: 'https://example.com/video.mp4',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),

            // Caption Input
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                hintText: 'Write your caption...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 2200,
            ),

            if (_isCreating)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createPost,
          child: const Text('Create Post'),
        ),
      ],
    );
  }

  Future<void> _createPost() async {
    final mediaUrl = _selectedMediaType == 'IMAGE'
        ? _imageUrlController.text.trim()
        : _videoUrlController.text.trim();

    if (mediaUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a media URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      final result = await integrationService.createInstagramPost(
        widget.integrationId,
        imageUrl: _selectedMediaType == 'IMAGE' ? mediaUrl : null,
        videoUrl: _selectedMediaType == 'VIDEO' ? mediaUrl : null,
        caption: _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : null,
        mediaType: _selectedMediaType,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post created successfully! ID: ${result['id']}'),
            backgroundColor: Colors.green,
            action: result['permalink'] != null
                ? SnackBarAction(
                    label: 'View',
                    onPressed: () async {
                      final uri = Uri.parse(result['permalink']);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
