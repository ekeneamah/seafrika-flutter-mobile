import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/facebook_models.dart';
import 'package:vendor_app/providers/facebook_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/theme/app_theme.dart';
import 'package:vendor_app/screens/integrations/facebook_post_creator_screen.dart';
import 'package:vendor_app/screens/integrations/facebook_messenger_screen.dart';
import 'package:vendor_app/screens/integrations/facebook_insights_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class FacebookDashboardScreen extends ConsumerStatefulWidget {
  const FacebookDashboardScreen({super.key});

  @override
  ConsumerState<FacebookDashboardScreen> createState() => _FacebookDashboardScreenState();
}

class _FacebookDashboardScreenState extends ConsumerState<FacebookDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FacebookPage? _selectedPage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFacebookData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadFacebookData() {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    
    if (businessId != null) {
      // Load user profile
      ref.read(facebookAuthProvider.notifier).loadUserProfile(
        businessId: businessId,
        userId: authService.currentUser?.id,
        token: authService.currentUser?.accessToken,
      );
      
      // Load user pages
      ref.read(facebookPagesProvider.notifier).loadPages(
        businessId: businessId,
        userId: authService.currentUser?.id,
        token: authService.currentUser?.accessToken,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(selectedBusinessIdProvider);
    final authService = ref.watch(authServiceProvider);
    final facebookAuth = ref.watch(facebookAuthProvider);
    final facebookPages = ref.watch(facebookPagesProvider);
    final facebookPosts = ref.watch(facebookPostsProvider);

    if (businessId == null) {
      return Scaffold(
        appBar: const IntegrationAppBar(title: 'Facebook Dashboard'),
        body: const Center(
          child: Text('No business selected'),
        ),
      );
    }

    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'Facebook Dashboard',
        actions: [
          if (facebookAuth.user != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _disconnectFacebook(),
            ),
        ],
      ),
      body: facebookAuth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : facebookAuth.error != null
              ? _buildErrorState(facebookAuth.error!)
              : facebookAuth.user == null
                  ? _buildUnauthenticatedState()
                  : _buildAuthenticatedState(),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadFacebookData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.facebook, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Connect your Facebook account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your Facebook pages, posts, and messages',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate back to integration screen for authentication
              Navigator.pop(context);
            },
            icon: const Icon(Icons.facebook),
            label: const Text('Connect Facebook'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedState() {
    final facebookAuth = ref.watch(facebookAuthProvider);
    final facebookPages = ref.watch(facebookPagesProvider);

    return Column(
      children: [
        // User Info Header
        _buildUserInfoHeader(facebookAuth.user!),
        
        // Page Selector
        if (facebookPages.pages.isNotEmpty) _buildPageSelector(facebookPages.pages),
        
        // Tab Bar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.post_add), text: 'Posts'),
            Tab(icon: Icon(Icons.message), text: 'Messages'),
            Tab(icon: Icon(Icons.analytics), text: 'Insights'),
          ],
        ),
        
        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildPostsTab(),
              _buildMessagesTab(),
              _buildInsightsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoHeader(FacebookUser user) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: user.picture != null ? NetworkImage(user.picture!) : null,
            child: user.picture == null ? Text(user.name[0].toUpperCase()) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (user.email != null)
                  Text(
                    user.email!,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageSelector(List<FacebookPage> pages) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<FacebookPage>(
        value: _selectedPage,
        decoration: const InputDecoration(
          labelText: 'Select Facebook Page',
          border: OutlineInputBorder(),
        ),
        items: pages.map((page) {
          return DropdownMenuItem(
            value: page,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: page.picture != null ? NetworkImage(page.picture!) : null,
                  child: page.picture == null ? Text(page.name[0].toUpperCase()) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(page.name, overflow: TextOverflow.ellipsis),
                      Text(
                        page.category,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (FacebookPage? page) {
          setState(() {
            _selectedPage = page;
          });
          if (page != null) {
            ref.read(facebookPagesProvider.notifier).selectPage(page);
            _loadPagePosts(page.id);
          }
        },
      ),
    );
  }

  Widget _buildOverviewTab() {
    final facebookPages = ref.watch(facebookPagesProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pages',
                  facebookPages.pages.length.toString(),
                  Icons.pages,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Selected Page',
                  _selectedPage?.name ?? 'None',
                  Icons.public,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          if (_selectedPage != null) ...[
            _buildQuickActionButton(
              'Create Post',
              Icons.post_add,
              Colors.blue,
              () => _navigateToPostCreator(),
            ),
            const SizedBox(height: 8),
            _buildQuickActionButton(
              'Upload Photo',
              Icons.photo_camera,
              Colors.green,
              () => _uploadPhoto(),
            ),
            const SizedBox(height: 8),
            _buildQuickActionButton(
              'Upload Video',
              Icons.videocam,
              Colors.orange,
              () => _uploadVideo(),
            ),
            const SizedBox(height: 8),
            _buildQuickActionButton(
              'Share to Timeline',
              Icons.share,
              Colors.purple,
              () => _shareToTimeline(),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Select a Facebook page to access quick actions',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPostsTab() {
    final facebookPosts = ref.watch(facebookPostsProvider);
    
    if (_selectedPage == null) {
      return const Center(
        child: Text('Please select a Facebook page to view posts'),
      );
    }
    
    return Column(
      children: [
        // Create Post Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _navigateToPostCreator,
            icon: const Icon(Icons.add),
            label: const Text('Create New Post'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
        
        // Posts List
        Expanded(
          child: facebookPosts.isLoading
              ? const Center(child: CircularProgressIndicator())
              : facebookPosts.error != null
                  ? Center(child: Text('Error: ${facebookPosts.error}'))
                  : facebookPosts.posts.isEmpty
                      ? const Center(child: Text('No posts found'))
                      : ListView.builder(
                          itemCount: facebookPosts.posts.length,
                          itemBuilder: (context, index) {
                            final post = facebookPosts.posts[index];
                            return _buildPostCard(post);
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildPostCard(FacebookPost post) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _selectedPage?.picture != null 
                      ? NetworkImage(_selectedPage!.picture!) 
                      : null,
                  child: _selectedPage?.picture == null 
                      ? Text(_selectedPage?.name[0].toUpperCase() ?? 'P') 
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPage?.name ?? 'Page',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDateTime(post.createdTime),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deletePost(post.id);
                    }
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Post Content
            if (post.message != null) ...[
              Text(post.message!),
              const SizedBox(height: 8),
            ],
            
            if (post.picture != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.picture!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Post Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPostActionButton(
                  Icons.thumb_up,
                  'Like',
                  () => _toggleLike(post.id),
                ),
                _buildPostActionButton(
                  Icons.comment,
                  'Comment',
                  () => _showCommentDialog(post.id),
                ),
                _buildPostActionButton(
                  Icons.emoji_emotions,
                  'React',
                  () => _showReactionDialog(post.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesTab() {
    if (_selectedPage == null) {
      return const Center(
        child: Text('Please select a Facebook page to view messages'),
      );
    }
    
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Messenger Integration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'View and respond to messages from your Facebook page',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    if (_selectedPage == null) {
      return const Center(
        child: Text('Please select a Facebook page to view insights'),
      );
    }
    
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Page Insights',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'View analytics and performance metrics for your Facebook page',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  void _loadPagePosts(String pageId) {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    
    if (businessId != null) {
      ref.read(facebookPostsProvider.notifier).loadPagePosts(
        pageId: pageId,
        businessId: businessId,
        userId: authService.currentUser?.id,
        token: authService.currentUser?.accessToken,
      );
    }
  }

  void _navigateToPostCreator() {
    if (_selectedPage != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FacebookPostCreatorScreen(page: _selectedPage!),
        ),
      ).then((_) {
        // Reload posts after returning from post creator
        _loadPagePosts(_selectedPage!.id);
      });
    }
  }

  void _uploadPhoto() async {
    if (_selectedPage == null) return;
    
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final businessId = ref.read(selectedBusinessIdProvider);
      final authService = ref.read(authServiceProvider);
      
      if (businessId != null) {
        await ref.read(facebookPostsProvider.notifier).uploadPhoto(
          pageId: _selectedPage!.id,
          photo: File(image.path),
          businessId: businessId,
          userId: authService.currentUser?.id,
          token: authService.currentUser?.accessToken,
        );
      }
    }
  }

  void _uploadVideo() async {
    if (_selectedPage == null) return;
    
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video != null) {
      final businessId = ref.read(selectedBusinessIdProvider);
      final authService = ref.read(authServiceProvider);
      
      if (businessId != null) {
        await ref.read(facebookPostsProvider.notifier).uploadVideo(
          pageId: _selectedPage!.id,
          video: File(video.path),
          businessId: businessId,
          userId: authService.currentUser?.id,
          token: authService.currentUser?.accessToken,
        );
      }
    }
  }

  void _shareToTimeline() {
    // Show dialog to create timeline post
    showDialog(
      context: context,
      builder: (context) => _buildShareToTimelineDialog(),
    );
  }

  Widget _buildShareToTimelineDialog() {
    final messageController = TextEditingController();
    final linkController = TextEditingController();
    
    return AlertDialog(
      title: const Text('Share to Timeline'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: messageController,
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: linkController,
            decoration: const InputDecoration(
              labelText: 'Link (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            _performShareToTimeline(messageController.text, linkController.text);
            Navigator.pop(context);
          },
          child: const Text('Share'),
        ),
      ],
    );
  }

  void _performShareToTimeline(String message, String? link) async {
    if (message.isEmpty) return;
    
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    final facebookService = ref.read(facebookServiceProvider);
    
    if (businessId != null) {
      try {
        await facebookService.shareToTimeline(
          message: message,
          businessId: businessId,
          link: link?.isNotEmpty == true ? link : null,
          userId: authService.currentUser?.id,
          token: authService.currentUser?.accessToken,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared to timeline successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  void _deletePost(String postId) async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    
    if (businessId != null) {
      await ref.read(facebookPostsProvider.notifier).deletePost(
        postId: postId,
        businessId: businessId,
        userId: authService.currentUser?.id,
        token: authService.currentUser?.accessToken,
      );
    }
  }

  void _toggleLike(String postId) async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    
    if (businessId != null) {
      await ref.read(facebookPostsProvider.notifier).toggleLike(
        postId: postId,
        businessId: businessId,
        userId: authService.currentUser?.id,
        token: authService.currentUser?.accessToken,
      );
    }
  }

  void _showCommentDialog(String postId) {
    final commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            labelText: 'Comment',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addComment(postId, commentController.text);
              Navigator.pop(context);
            },
            child: const Text('Comment'),
          ),
        ],
      ),
    );
  }

  void _addComment(String postId, String message) async {
    if (message.isEmpty) return;
    
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    
    if (businessId != null) {
      await ref.read(facebookPostsProvider.notifier).commentOnPost(
        postId: postId,
        message: message,
        businessId: businessId,
        pageId: _selectedPage?.id,
        userId: authService.currentUser?.id,
        token: authService.currentUser?.accessToken,
      );
    }
  }

  void _showReactionDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Reaction'),
        content: Wrap(
          spacing: 16,
          children: FacebookReactionType.values.map((reaction) {
            return GestureDetector(
              onTap: () {
                _addReaction(postId, reaction);
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _getReactionIcon(reaction),
                    const SizedBox(height: 4),
                    Text(
                      reaction.value,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _getReactionIcon(FacebookReactionType reaction) {
    switch (reaction) {
      case FacebookReactionType.like:
        return const Icon(Icons.thumb_up, color: Colors.blue);
      case FacebookReactionType.love:
        return const Icon(Icons.favorite, color: Colors.red);
      case FacebookReactionType.wow:
        return const Icon(Icons.sentiment_very_satisfied, color: Colors.orange);
      case FacebookReactionType.haha:
        return const Icon(Icons.sentiment_very_satisfied, color: Colors.yellow);
      case FacebookReactionType.sad:
        return const Icon(Icons.sentiment_very_dissatisfied, color: Colors.blue);
      case FacebookReactionType.angry:
        return const Icon(Icons.sentiment_very_dissatisfied, color: Colors.red);
    }
  }

  void _addReaction(String postId, FacebookReactionType reaction) async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    
    if (businessId != null) {
      await ref.read(facebookPostsProvider.notifier).addReaction(
        postId: postId,
        reactionType: reaction,
        businessId: businessId,
        userId: authService.currentUser?.id,
        token: authService.currentUser?.accessToken,
      );
    }
  }

  void _disconnectFacebook() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    
    if (businessId != null) {
      await ref.read(facebookAuthProvider.notifier).disconnect(
        businessId: businessId,
        userId: authService.currentUser?.id,
        token: authService.currentUser?.accessToken,
      );
      
      // Navigate back to integration screen
      Navigator.pop(context);
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(dt);
      
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
      return dateTime;
    }
  }
}
