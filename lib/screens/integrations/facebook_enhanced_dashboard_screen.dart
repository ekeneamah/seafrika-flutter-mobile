import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/facebook_models.dart';
import 'package:vendor_app/providers/facebook_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/screens/integrations/facebook_post_creator_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '📱 FacebookEnhancedDashboard: initState called with integrationId: ${widget.integrationId}');
    _tabController = TabController(length: 4, vsync: this);

    // Add listener to track tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabNames = ['Overview', 'Posts', 'Messages', 'Insights'];
        debugPrint(
            '📊 FacebookEnhancedDashboard: Tab changed to ${tabNames[_tabController.index]} (index: ${_tabController.index})');
      }
    });

    // Defer data loading until after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          '📱 FacebookEnhancedDashboard: Post-frame callback triggered, loading Facebook data');
      _loadFacebookData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadFacebookData() {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);

    debugPrint(
        '📱 FacebookEnhancedDashboard: Loading Facebook data for integration');
    debugPrint('   🏢 Business ID: $businessId');
    debugPrint('   🔗 Integration ID: ${widget.integrationId}');
    debugPrint('   👤 User ID: ${authService.currentUser?.id}');
    debugPrint(
        '   🔑 Has Token: ${authService.currentUser?.accessToken != null}');

    if (businessId != null && widget.integrationId.isNotEmpty) {
      debugPrint(
          '📱 FacebookEnhancedDashboard: Prerequisites met, loading integration data');

      // Load user profile using integrationId
      debugPrint(
          '📱 FacebookEnhancedDashboard: Calling loadUserProfile with integrationId');
      ref.read(facebookAuthProvider.notifier).loadUserProfile(
            integrationId: widget.integrationId,
            businessId: businessId,
            userId: authService.currentUser?.id,
            token: authService.currentUser?.accessToken,
          );

      // Load page info for this specific integration (single page)
      debugPrint(
          '📱 FacebookEnhancedDashboard: Loading page info for integration');
      ref.read(facebookPagesProvider.notifier).loadPages(
            integrationId: widget.integrationId,
            businessId: businessId,
            userId: authService.currentUser?.id,
            token: authService.currentUser?.accessToken,
          );

      // Automatically load posts for the integration's page
      debugPrint('📱 FacebookEnhancedDashboard: Loading posts for integration');
      _loadPostsForIntegration();
    } else {
      debugPrint(
          '❌ FacebookEnhancedDashboard: Prerequisites not met for loading data');
      debugPrint('   🏢 Business ID null: ${businessId == null}');
      debugPrint('   🔗 Integration ID empty: ${widget.integrationId.isEmpty}');
    }
  }

  void _loadPostsForIntegration() {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);

    debugPrint(
        '📝 FacebookEnhancedDashboard: Loading posts for integration: ${widget.integrationId}');
    debugPrint('📝 Business ID: $businessId');
    debugPrint('📝 User ID: ${authService.currentUser?.id}');
    debugPrint(
        '📝 Token available: ${authService.currentUser?.accessToken != null}');

    if (businessId != null) {
      debugPrint(
          '📝 Calling facebookPostsProvider.loadIntegrationPosts with integrationId...');
      ref.read(facebookPostsProvider.notifier).loadIntegrationPosts(
            integrationId: widget.integrationId,
            businessId: businessId,
            userId: authService.currentUser?.id,
            token: authService.currentUser?.accessToken,
          );
    } else {
      debugPrint(
          '❌ FacebookEnhancedDashboard: Cannot load posts - businessId is null');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 FacebookEnhancedDashboard: Building widget');

    final businessId = ref.watch(selectedBusinessIdProvider);
    final facebookAuth = ref.watch(facebookAuthProvider);
    final facebookPages = ref.watch(facebookPagesProvider);
    final facebookPosts = ref.watch(facebookPostsProvider);

    debugPrint('📊 Provider States:');
    debugPrint('   🏢 Business ID: $businessId');
    debugPrint('   🔐 Auth authenticated: ${facebookAuth.isAuthenticated}');
    debugPrint('   🔐 Auth loading: ${facebookAuth.isLoading}');
    debugPrint('   🔐 Auth error: ${facebookAuth.error}');
    debugPrint('   📄 Pages loading: ${facebookPages.isLoading}');
    debugPrint('   📄 Pages count: ${facebookPages.pages.length}');
    debugPrint('   📄 Pages error: ${facebookPages.error}');
    debugPrint('   📝 Posts loading: ${facebookPosts.isLoading}');
    debugPrint('   📝 Posts count: ${facebookPosts.posts.length}');
    debugPrint('   📝 Posts error: ${facebookPosts.error}');

    if (businessId == null) {
      debugPrint(
          '❌ FacebookEnhancedDashboard: No business selected, showing error state');
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
          ? (() {
              debugPrint('⏳ FacebookEnhancedDashboard: Showing loading state');
              return const Center(child: CircularProgressIndicator());
            })()
          : facebookAuth.error != null
              ? _buildErrorState(facebookAuth.error!)
              : facebookAuth.user == null
                  ? (() {
                      debugPrint(
                          '🔓 FacebookEnhancedDashboard: User not authenticated, showing unauthenticated state');
                      return _buildUnauthenticatedState();
                    })()
                  : (() {
                      debugPrint(
                          '✅ FacebookEnhancedDashboard: User authenticated, showing authenticated state');
                      return _buildAuthenticatedState();
                    })(),
    );
  }

  Widget _buildErrorState(String error) {
    debugPrint(
        '❌ FacebookEnhancedDashboard: Building error state with error: $error');
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
            onPressed: () {
              debugPrint(
                  '🔄 FacebookEnhancedDashboard: Retry button pressed from error state');
              _loadFacebookData();
            },
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
              debugPrint(
                  '🔗 FacebookEnhancedDashboard: Connect Facebook button pressed, navigating back to integration screen');
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
    debugPrint('✅ FacebookEnhancedDashboard: Building authenticated state');
    final facebookAuth = ref.watch(facebookAuthProvider);
    final facebookPages = ref.watch(facebookPagesProvider);

    debugPrint('   👤 User: ${facebookAuth.user?.name}');
    debugPrint('   📄 Available pages: ${facebookPages.pages.length}');

    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverToBoxAdapter(
            child: Column(
              children: [
                // User Info Header
                _buildUserInfoHeader(facebookAuth.user!),

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
              ],
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildPostsTab(),
          _buildMessagesTab(),
          _buildInsightsTab(),
        ],
      ),
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
            backgroundImage:
                user.picture != null ? NetworkImage(user.picture!) : null,
            child:
                user.picture == null ? Text(user.name[0].toUpperCase()) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildOverviewTab() {
    final facebookPages = ref.watch(facebookPagesProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Stats Cards
                _buildStatsGrid(),

                const SizedBox(height: 24),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                if (facebookPages.pages.isNotEmpty) ...[
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
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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

  Widget _buildStatsGrid() {
    final facebookPages = ref.watch(facebookPagesProvider);
    final facebookPosts = ref.watch(facebookPostsProvider);
    final facebookAuth = ref.watch(facebookAuthProvider);

    // Get the page data if available
    final page =
        facebookPages.pages.isNotEmpty ? facebookPages.pages.first : null;
    final postsCount = facebookPosts.posts.length;
    final fanCount = page?.fanCount ?? 0;
    final followersCount = page?.followersCount ?? 0;

    // Connection check based on having valid page data
    final isConnected = facebookAuth.isAuthenticated &&
        page != null &&
        page.id.isNotEmpty &&
        page.name.isNotEmpty &&
        !facebookPages.isLoading &&
        facebookPages.error == null;

    debugPrint('📊 FacebookEnhancedDashboard: Building stats grid');
    debugPrint('   👥 Fan Count: $fanCount');
    debugPrint('   👥 Followers Count: $followersCount');
    debugPrint('   📝 Posts Count: $postsCount');
    debugPrint('   🔗 Auth Connected: ${facebookAuth.isAuthenticated}');
    debugPrint('   📄 Page Available: ${page != null}');
    if (page != null) {
      debugPrint('   📄 Page ID: ${page.id}');
      debugPrint('   📄 Page Name: ${page.name}');
      debugPrint('   📄 Page Category: ${page.category}');
      debugPrint('   📄 Page About: ${page.about}');
      debugPrint('   📄 Page Fan Count: ${page.fanCount}');
      debugPrint('   📄 Page Followers Count: ${page.followersCount}');
      debugPrint(
          '   📄 Page Access Token: ${page.accessToken != null ? 'Present' : 'Missing'}');
      debugPrint('   📄 Page Tasks: ${page.tasks}');
    }
    debugPrint('   🔗 Final Connected Status: $isConnected');
    debugPrint('   ❓ Status Check Details:');
    debugPrint('      - Auth authenticated: ${facebookAuth.isAuthenticated}');
    debugPrint('      - Page not null: ${page != null}');
    debugPrint('      - Page ID not empty: ${page?.id.isNotEmpty ?? false}');
    debugPrint(
        '      - Page name not empty: ${page?.name.isNotEmpty ?? false}');
    debugPrint('      - Not loading: ${!facebookPages.isLoading}');
    debugPrint('      - No error: ${facebookPages.error == null}');
    if (facebookPages.error != null) {
      debugPrint('      - Error details: ${facebookPages.error}');
    }
    if (facebookAuth.error != null) {
      debugPrint('      - Auth error details: ${facebookAuth.error}');
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Fans',
            _getStatValue(
              isLoading: facebookPages.isLoading,
              hasError: facebookPages.error != null,
              value: _formatNumber(fanCount),
            ),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Followers',
            _getStatValue(
              isLoading: facebookPages.isLoading,
              hasError: facebookPages.error != null,
              value: _formatNumber(followersCount),
            ),
            Icons.person_add,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Posts',
            _getStatValue(
              isLoading: facebookPosts.isLoading,
              hasError: facebookPosts.error != null,
              value: postsCount.toString(),
            ),
            Icons.post_add,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _getStatValue({
    required bool isLoading,
    required bool hasError,
    required String value,
  }) {
    if (hasError) return 'Error';
    if (isLoading) return '...';
    return value;
  }

  Widget _buildQuickActionButton(
      String title, IconData icon, Color color, VoidCallback onTap) {
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
    final facebookPages = ref.watch(facebookPagesProvider);

    if (facebookPages.pages.isEmpty && !facebookPages.isLoading) {
      return const Center(
        child: Text('Page information not available'),
      );
    }

    return CustomScrollView(
      slivers: [
        // Create Post Button
        SliverToBoxAdapter(
          child: Padding(
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
        ),

        // Posts List
        facebookPosts.isLoading
            ? (() {
                debugPrint(
                    '⏳ FacebookEnhancedDashboard: Posts loading for integration: ${widget.integrationId}');
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              })()
            : facebookPosts.error != null
                ? SliverFillRemaining(
                    child: _buildPostsErrorState(facebookPosts.error!),
                  )
                : facebookPosts.posts.isEmpty
                    ? SliverFillRemaining(
                        child: _buildNoPostsState(),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = facebookPosts.posts[index];
                            return _buildPostCard(post);
                          },
                          childCount: facebookPosts.posts.length,
                        ),
                      ),
      ],
    );
  }

  Widget _buildPostsErrorState(String error) {
    debugPrint(
        '❌ FacebookEnhancedDashboard: Building posts error state with error: $error');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Posts Error: $error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              debugPrint(
                  '🔄 FacebookEnhancedDashboard: Retrying posts load from error state');
              _loadPostsForIntegration();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPostsState() {
    debugPrint('📝 FacebookEnhancedDashboard: Building no posts state');
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.post_add, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No posts found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Posts will appear here once available',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
                Consumer(
                  builder: (context, ref, child) {
                    final facebookPages = ref.watch(facebookPagesProvider);
                    final page = facebookPages.pages.isNotEmpty
                        ? facebookPages.pages.first
                        : null;

                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: page?.picture != null
                          ? NetworkImage(page!.picture!)
                          : null,
                      child: page?.picture == null
                          ? Text(page?.name[0].toUpperCase() ?? 'P')
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Consumer(
                        builder: (context, ref, child) {
                          final facebookPages =
                              ref.watch(facebookPagesProvider);
                          final page = facebookPages.pages.isNotEmpty
                              ? facebookPages.pages.first
                              : null;

                          return Text(
                            page?.name ?? 'Page',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      Text(
                        _formatDateTime(post.createdTime),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
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

  Widget _buildPostActionButton(
      IconData icon, String label, VoidCallback onTap) {
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
    final facebookPages = ref.watch(facebookPagesProvider);

    if (facebookPages.pages.isEmpty && !facebookPages.isLoading) {
      return const Center(
        child: Text('Page information not available'),
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
    final facebookPages = ref.watch(facebookPagesProvider);

    if (facebookPages.pages.isEmpty && !facebookPages.isLoading) {
      return const Center(
        child: Text('Page information not available'),
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

  void _navigateToPostCreator() {
    final facebookPages = ref.read(facebookPagesProvider);
    debugPrint(
        '➕ FacebookEnhancedDashboard: Navigate to post creator requested');

    if (facebookPages.pages.isNotEmpty) {
      final page = facebookPages.pages.first;
      debugPrint('➕ Navigation successful for page: ${page.name} (${page.id})');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FacebookPostCreatorScreen(page: page),
        ),
      ).then((_) {
        // Reload posts after returning from post creator
        debugPrint(
            '🔄 FacebookEnhancedDashboard: Returned from post creator, reloading posts');
        _loadPostsForIntegration();
      });
    } else {
      debugPrint(
          '❌ FacebookEnhancedDashboard: Cannot navigate to post creator - no page information available');
    }
  }

  void _uploadPhoto() async {
    final facebookPages = ref.read(facebookPagesProvider);
    debugPrint('📸 FacebookEnhancedDashboard: Upload photo requested');

    if (facebookPages.pages.isEmpty) {
      debugPrint(
          '❌ FacebookEnhancedDashboard: Cannot upload photo - no page information available');
      return;
    }

    final page = facebookPages.pages.first;
    debugPrint('📸 Opening image picker for page: ${page.name}');
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      debugPrint('📸 Image selected: ${image.path}');
      final businessId = ref.read(selectedBusinessIdProvider);
      final authService = ref.read(authServiceProvider);

      debugPrint('📸 Business ID: $businessId');
      debugPrint('📸 User ID: ${authService.currentUser?.id}');

      if (businessId != null) {
        debugPrint('📸 Uploading photo to Facebook...');
        await ref.read(facebookPostsProvider.notifier).uploadPhoto(
              pageId: page.id,
              photo: File(image.path),
              businessId: businessId,
              userId: authService.currentUser?.id,
              token: authService.currentUser?.accessToken,
            );
        debugPrint(
            '✅ FacebookEnhancedDashboard: Photo upload request completed');
      } else {
        debugPrint(
            '❌ FacebookEnhancedDashboard: Cannot upload photo - business ID is null');
      }
    } else {
      debugPrint('❌ FacebookEnhancedDashboard: Photo upload cancelled by user');
    }
  }

  void _uploadVideo() async {
    final facebookPages = ref.read(facebookPagesProvider);
    if (facebookPages.pages.isEmpty) return;

    final page = facebookPages.pages.first;
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);

    if (video != null) {
      final businessId = ref.read(selectedBusinessIdProvider);
      final authService = ref.read(authServiceProvider);

      if (businessId != null) {
        await ref.read(facebookPostsProvider.notifier).uploadVideo(
              pageId: page.id,
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
            _performShareToTimeline(
                messageController.text, linkController.text);
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
            pageId: widget.integrationId,
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
        return const Icon(Icons.sentiment_very_dissatisfied,
            color: Colors.blue);
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
