import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/services/navigation_service.dart';

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
    final pageInfo = _currentIntegration!.accountInfo;
    final pageName = pageInfo?['pageName'] ?? 'Unknown Page';
    final category = pageInfo?['category'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: _facebookBlue,
                        child: const Icon(
                          Icons.facebook,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pageName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (category.isNotEmpty)
                              Text(
                                category,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Connected',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

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
}
