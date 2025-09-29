import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/config/api_config.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Facebook Pages Integration Screen
///
/// This screen handles Facebook Pages integration for business page management.
/// Features include:
/// - Page insights and analytics
/// - Post management and scheduling
/// - Comments and messaging management
/// - Page settings and configuration

class FacebookPagesIntegrationScreen extends ConsumerStatefulWidget {
  final String? integrationId;

  const FacebookPagesIntegrationScreen({
    super.key,
    this.integrationId,
  });

  @override
  ConsumerState<FacebookPagesIntegrationScreen> createState() =>
      _FacebookPagesIntegrationScreenState();
}

class _FacebookPagesIntegrationScreenState
    extends ConsumerState<FacebookPagesIntegrationScreen> {
  static const Color _facebookBlue = Color(0xFF1877F2);

  bool _isLoading = false;
  String? _error;
  Integration? _currentIntegration;
  Map<String, dynamic>? _facebookPage;

  @override
  void initState() {
    super.initState();
    _loadIntegration();
  }

  Future<void> _loadIntegration() async {
    if (widget.integrationId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      final integrations = await integrationService.fetchIntegrations();
      final integration = integrations.firstWhere(
        (i) => i.id == widget.integrationId,
        orElse: () => throw Exception('Integration not found'),
      );

      setState(() {
        _currentIntegration = integration;
      });

      // Load Facebook page data
      await _loadFacebookPage();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFacebookPage() async {
    if (_currentIntegration == null) return;

    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getFacebookPageInfo(_currentIntegration!.id)),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _facebookPage = responseData;
        });
      } else {
        final errorBody = json.decode(response.body);
        setState(() {
          _facebookPage = null;
          _error =
              'Failed to load Facebook page: ${errorBody['message'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      debugPrint('Failed to load Facebook page: $e');
      setState(() {
        _facebookPage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'Facebook Pages',
        actions: [
          if (_currentIntegration != null)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                NavigationService.navigateToIntegrationSettings(
                  _currentIntegration!.id,
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _currentIntegration == null
                  ? _buildNotConnectedView()
                  : _buildConnectedView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Integration',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadIntegration,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.facebook, size: 64, color: _facebookBlue),
          const SizedBox(height: 16),
          Text(
            'Facebook Pages Not Connected',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Connect your Facebook Pages to manage posts, insights, and engagement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              NavigationService.navigateToAddIntegration();
            },
            icon: const Icon(Icons.add),
            label: const Text('Connect Facebook Pages'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _facebookBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section with page profile
          if (_facebookPage != null) _buildPageHeroSection(),

          if (_facebookPage == null) ...[
            // Connection status fallback when no page data
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Facebook Pages Connected',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connected on ${_currentIntegration!.createdAt.toString().split(' ')[0]}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Features Section
          Text(
            'Facebook Pages Features',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Feature Cards
          _buildFeatureCard(
            icon: Icons.analytics,
            title: 'Page Insights',
            description:
                'View detailed analytics and performance metrics for your Facebook Page.',
            onTap: () {
              NavigationService.navigateToFacebookInsights();
            },
          ),

          const SizedBox(height: 12),

          _buildFeatureCard(
            icon: Icons.post_add,
            title: 'Manage Posts',
            description:
                'Create, schedule, and manage posts for your Facebook Page.',
            onTap: () {
              if (widget.integrationId != null) {
                NavigationService.navigateToFacebookPosts(
                    widget.integrationId!);
              }
            },
          ),

          const SizedBox(height: 12),

          _buildFeatureCard(
            icon: Icons.message,
            title: 'Messages & Comments',
            description:
                'Respond to messages and comments on your Facebook Page.',
            onTap: () {
              if (widget.integrationId != null) {
                NavigationService.navigateToFacebookMessages(
                    widget.integrationId!);
              }
            },
          ),

          const SizedBox(height: 12),

          _buildFeatureCard(
            icon: Icons.settings,
            title: 'Integration Settings',
            description:
                'Configure sync settings and manage your Facebook Pages integration.',
            onTap: () {
              NavigationService.navigateToIntegrationSettings(
                _currentIntegration!.id,
              );
            },
          ),

          const SizedBox(height: 32),

          // Disconnect Section
          Center(
            child: TextButton.icon(
              onPressed: () => _showDisconnectDialog(),
              icon: Icon(Icons.link_off, color: Colors.red[600]),
              label: Text(
                'Disconnect Facebook Pages',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _facebookBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: _facebookBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Facebook Pages'),
        content: const Text(
          'Are you sure you want to disconnect your Facebook Pages integration? '
          'This will stop syncing data and remove access to Facebook features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _disconnectIntegration();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectIntegration() async {
    // TODO: Implement disconnect logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disconnect functionality coming soon!'),
      ),
    );
  }

  Widget _buildPageHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1877F2),
            Color(0xFF4267B2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1877F2).withOpacity(0.3),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        children: [
          // Connection status indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Connected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadFacebookPage,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: 'Refresh page info',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Page profile section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile picture
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _facebookPage!['picture'] != null
                    ? Image.network(
                        _facebookPage!['picture']['data']['url'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.business,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
              ),

              const SizedBox(width: 16),

              // Page details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page name and verification
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _facebookPage!['name'] ?? 'Unknown Page',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_facebookPage!['is_verified'] == true) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ],
                    ),

                    // Category
                    if (_facebookPage!['category'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _facebookPage!['category'],
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Stats row
                    Row(
                      children: [
                        if (_facebookPage!['fan_count'] != null) ...[
                          _buildHeroStat(
                            'Fans',
                            _formatCount(_facebookPage!['fan_count']),
                          ),
                          const SizedBox(width: 20),
                        ],
                        if (_facebookPage!['followers_count'] != null)
                          _buildHeroStat(
                            'Followers',
                            _formatCount(_facebookPage!['followers_count']),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // About section
          if (_facebookPage!['about'] != null ||
              _facebookPage!['description'] != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _facebookPage!['about'] ?? _facebookPage!['description'] ?? '',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Connection date
          Text(
            'Connected on ${_currentIntegration!.createdAt.toString().split(' ')[0]}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
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
