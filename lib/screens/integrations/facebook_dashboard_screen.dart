import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacebookDashboardScreen extends ConsumerStatefulWidget {
  final String integrationId;
  final int initialTab;

  const FacebookDashboardScreen({
    super.key,
    required this.integrationId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<FacebookDashboardScreen> createState() =>
      _FacebookDashboardScreenState();
}

class _FacebookDashboardScreenState
    extends ConsumerState<FacebookDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _pageInfo;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadIntegration(),
        _loadPageInfo(),
        _loadPosts(),
        _loadComments(),
        _loadMessages(),
        _loadInsights(),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadIntegration() async {
    final integrationService = ref.read(integrationServiceProvider);
    if (integrationService == null) {
      throw Exception('No business selected');
    }

    final integrations = await integrationService.fetchIntegrations();
    final integration =
        integrations.where((i) => i.id == widget.integrationId).firstOrNull;

    if (integration == null) {
      throw Exception('Integration not found');
    }

    // Integration loaded successfully
  }

  Future<void> _loadPageInfo() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/facebook/${widget.integrationId}/page-info'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _pageInfo = data;
        });
      }
    } catch (e) {
      debugPrint('Failed to load page info: $e');
    }
  }

  Future<void> _loadPosts() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/facebook/${widget.integrationId}/posts'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _posts = List<Map<String, dynamic>>.from(data['posts'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Failed to load posts: $e');
    }
  }

  Future<void> _loadComments() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/facebook/${widget.integrationId}/comments'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Failed to load comments: $e');
    }
  }

  Future<void> _loadMessages() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/facebook/${widget.integrationId}/messages'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages =
              List<Map<String, dynamic>>.from(data['conversations'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Failed to load messages: $e');
    }
  }

  Future<void> _loadInsights() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/facebook/${widget.integrationId}/insights'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _insights = data;
        });
      }
    } catch (e) {
      debugPrint('Failed to load insights: $e');
    }
  }

  Future<void> _createPost(String message, {String? imageUrl}) async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'message': message,
      };

      if (imageUrl != null) {
        payload['image_url'] = imageUrl;
      }

      final response = await http.post(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/facebook/${widget.integrationId}/posts'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadPosts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to create post');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _replyToComment(String commentId, String message) async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/facebook/${widget.integrationId}/comments/$commentId/reply'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'message': message}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadComments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reply sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to send reply');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reply: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'Facebook Dashboard',
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Posts', icon: Icon(Icons.post_add)),
            Tab(text: 'Comments', icon: Icon(Icons.comment)),
            Tab(text: 'Messages', icon: Icon(Icons.message)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
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
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPostsTab(),
                    _buildCommentsTab(),
                    _buildMessagesTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _showCreatePostDialog,
              backgroundColor: const Color(0xFF1877F2),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildPostsTab() {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: _posts.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No posts yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('Create your first post using the + button'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final post = _posts[index];
                return _buildPostCard(post);
              },
            ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_pageInfo?['picture'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      _pageInfo!['picture']['data']['url'],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.business, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pageInfo?['name'] ?? 'Facebook Page',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (post['created_time'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(post['created_time']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View on Facebook'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Post content
          if (post['message'] != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                post['message'],
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Post media
          if (post['full_picture'] != null) ...[
            Image.network(
              post['full_picture'],
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image_not_supported, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Post stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (post['likes'] != null &&
                    post['likes']['summary'] != null) ...[
                  Icon(Icons.thumb_up, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text('${post['likes']['summary']['total_count']}'),
                  const SizedBox(width: 16),
                ],
                if (post['comments'] != null &&
                    post['comments']['summary'] != null) ...[
                  Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${post['comments']['summary']['total_count']}'),
                  const SizedBox(width: 16),
                ],
                if (post['shares'] != null) ...[
                  Icon(Icons.share, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${post['shares']['count']}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsTab() {
    return RefreshIndicator(
      onRefresh: _loadComments,
      child: _comments.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.comment, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No comments yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('Comments on your posts will appear here'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return _buildCommentCard(comment);
              },
            ),
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comment header
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: comment['from']?['picture'] != null
                      ? NetworkImage(comment['from']['picture'])
                      : null,
                  child: comment['from']?['picture'] == null
                      ? const Icon(Icons.person, size: 16)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment['from']?['name'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (comment['created_time'] != null) ...[
                        Text(
                          _formatDate(comment['created_time']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.reply),
                  onPressed: () => _showReplyDialog(comment['id']),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Comment content
            Text(
              comment['message'] ?? '',
              style: const TextStyle(fontSize: 16),
            ),

            // Comment stats
            if (comment['like_count'] != null && comment['like_count'] > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.thumb_up, size: 14, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${comment['like_count']} likes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesTab() {
    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: _messages.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('Page messages will appear here'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final conversation = _messages[index];
                return _buildConversationCard(conversation);
              },
            ),
    );
  }

  Widget _buildConversationCard(Map<String, dynamic> conversation) {
    final participants = conversation['participants']?['data'] ?? [];
    final lastMessage = conversation['messages']?['data']?.isNotEmpty == true
        ? conversation['messages']['data'][0]
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          child: participants.isNotEmpty && participants[0]['name'] != null
              ? Text(participants[0]['name'][0].toUpperCase())
              : const Icon(Icons.person),
        ),
        title: Text(
          participants.isNotEmpty && participants[0]['name'] != null
              ? participants[0]['name']
              : 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: lastMessage != null
            ? Text(
                lastMessage['message'] ?? 'No message',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : const Text('No messages'),
        trailing: lastMessage != null
            ? Text(
                _formatDate(lastMessage['created_time']),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              )
            : null,
        onTap: () {
          // TODO: Navigate to conversation detail
        },
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _loadInsights,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page overview
            if (_pageInfo != null) _buildPageOverview(),

            const SizedBox(height: 24),

            // Analytics cards
            if (_insights != null) ...[
              const Text(
                'Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildAnalyticsCards(),
            ] else ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.analytics, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Analytics not available',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text('Analytics data will appear when available'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPageOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Page Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_pageInfo!['picture'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _pageInfo!['picture']['data']['url'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pageInfo!['name'] ?? 'Facebook Page',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_pageInfo!['category'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _pageInfo!['category'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_pageInfo!['fan_count'] != null) ...[
                  Expanded(
                    child: _buildStatCard(
                      'Fans',
                      _formatCount(_pageInfo!['fan_count']),
                      Icons.people,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (_pageInfo!['followers_count'] != null) ...[
                  Expanded(
                    child: _buildStatCard(
                      'Followers',
                      _formatCount(_pageInfo!['followers_count']),
                      Icons.follow_the_signs,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard('Posts', _posts.length.toString(), Icons.post_add),
        _buildStatCard('Comments', _comments.length.toString(), Icons.comment),
        _buildStatCard('Messages', _messages.length.toString(), Icons.message),
        _buildStatCard(
            'Reach', _insights?['reach']?.toString() ?? '0', Icons.visibility),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF1877F2),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePostDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreatePostDialog(
        onCreatePost: _createPost,
      ),
    );
  }

  void _showReplyDialog(String commentId) {
    showDialog(
      context: context,
      builder: (context) => _ReplyDialog(
        onSendReply: (message) => _replyToComment(commentId, message),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
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
      return dateString;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _CreatePostDialog extends StatefulWidget {
  final Function(String message, {String? imageUrl}) onCreatePost;

  const _CreatePostDialog({required this.onCreatePost});

  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  final _messageController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Post'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Post message',
              hintText: 'What\'s on your mind?',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _imageUrlController,
            decoration: const InputDecoration(
              labelText: 'Image URL (optional)',
              hintText: 'https://example.com/image.jpg',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createPost,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Post'),
        ),
      ],
    );
  }

  void _createPost() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final imageUrl = _imageUrlController.text.trim();
    widget.onCreatePost(
      _messageController.text.trim(),
      imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
    );

    Navigator.pop(context);
  }
}

class _ReplyDialog extends StatefulWidget {
  final Function(String message) onSendReply;

  const _ReplyDialog({required this.onSendReply});

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reply to Comment'),
      content: TextField(
        controller: _messageController,
        decoration: const InputDecoration(
          labelText: 'Your reply',
          hintText: 'Type your reply...',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
        maxLength: 200,
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendReply,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1877F2),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reply'),
        ),
      ],
    );
  }

  void _sendReply() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reply'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    widget.onSendReply(_messageController.text.trim());
    Navigator.pop(context);
  }
}
