import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;

class GenericIntegrationDashboard extends ConsumerStatefulWidget {
  final String integrationId;

  const GenericIntegrationDashboard({
    super.key,
    required this.integrationId,
  });

  @override
  ConsumerState<GenericIntegrationDashboard> createState() =>
      _GenericIntegrationDashboardState();
}

class _GenericIntegrationDashboardState
    extends ConsumerState<GenericIntegrationDashboard> {
  bool _isLoading = true;
  String? _error;
  Integration? _integration;

  @override
  void initState() {
    super.initState();
    _loadIntegration();
  }

  Future<void> _loadIntegration() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      final integration =
          await integrationService.fetchIntegration(widget.integrationId);

      setState(() {
        _integration = integration;
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
    if (_isLoading) {
      return const Scaffold(
        appBar: IntegrationAppBar(title: 'Integration Dashboard'),
        body: LoadingView(),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: const IntegrationAppBar(title: 'Integration Dashboard'),
        body: error.ErrorView(
          message: _error!,
          onRetry: _loadIntegration,
        ),
      );
    }

    if (_integration == null) {
      return const Scaffold(
        appBar: IntegrationAppBar(title: 'Integration Dashboard'),
        body: Center(child: Text('Integration not found')),
      );
    }

    return Scaffold(
      appBar: IntegrationAppBar(
        title: '${_integration!.platformName} Dashboard',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Integration Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[100],
                            ),
                            child: Image.asset(
                              _integration!.platformIcon,
                              width: 24,
                              height: 24,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.integration_instructions),
                            )),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _integration!.platformName,
                                style:
                                    Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(_integration!.status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _integration!.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
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

            // Available Actions
            Text(
              'Available Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Action Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _ActionCard(
                  icon: Icons.settings,
                  title: 'Settings',
                  subtitle: 'Configure integration',
                  onTap: () {
                    NavigationService.navigateToIntegrationSettings(
                      _integration!.id,
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.sync,
                  title: 'Sync Now',
                  subtitle: 'Force sync data',
                  onTap: () {
                    _performSync();
                  },
                ),
                _ActionCard(
                  icon: Icons.analytics,
                  title: 'Analytics',
                  subtitle: 'View performance',
                  onTap: () {
                    // TODO: Navigate to analytics if available
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Analytics coming soon'),
                      ),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.history,
                  title: 'Sync History',
                  subtitle: 'View sync logs',
                  onTap: () {
                    // TODO: Navigate to sync history
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sync history coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Activity (placeholder)
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Activity will appear here once sync begins',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
      case 'active':
        return Colors.green;
      case 'error':
        return Colors.red;
      case 'disconnected':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Future<void> _performSync() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sync initiated...')),
    );

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService != null) {
        // TODO: Implement actual sync logic
        await Future.delayed(const Duration(seconds: 2)); // Simulate sync

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sync completed successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
