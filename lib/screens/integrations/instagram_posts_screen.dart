import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _error;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      final posts = await integrationService.getInstagramMedia(widget.integrationId);
      
      if (mounted) {
        setState(() {
          _posts = posts;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instagram Posts'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadPosts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPosts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildPostsContent(),
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
          decoration: BoxDecoration(
            gradient: const LinearGradient(
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
                '${_posts.length} posts found',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),

        // Posts list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _posts.length,
            itemBuilder: (context, index) {
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
                          isVideo ? post['thumbnail_url'] ?? post['media_url'] : post['media_url'],
                          fit: BoxFit.cover,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
    final caption = post['caption'] ?? 'Check out this post on Instagram!';
    
    // You would implement sharing functionality here
    // For now, just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share functionality: $caption'),
        action: SnackBarAction(
          label: 'Copy Link',
          onPressed: () {
            final permalink = post['permalink'] ?? '';
            // Copy permalink to clipboard
            debugPrint('Copying link: $permalink');
          },
        ),
      ),
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
