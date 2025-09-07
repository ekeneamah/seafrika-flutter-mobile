import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/empty_view.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/config/routes.dart';

class IntegrationManagementScreen extends ConsumerStatefulWidget {
  const IntegrationManagementScreen({super.key});

  @override
  ConsumerState<IntegrationManagementScreen> createState() =>
      _IntegrationManagementScreenState();
}

class _IntegrationManagementScreenState
    extends ConsumerState<IntegrationManagementScreen> {
  bool _isLoading = true;
  String? _error;
  List<Integration> _integrations = [];

  @override
  void initState() {
    super.initState();
    _loadIntegrations();
  }

  Future<void> _loadIntegrations() async {
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
      if (mounted) {
        setState(() {
          _integrations = integrations;
          _isLoading = false;
        });
      }
    } on IntegrationException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load integrations';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _disconnectIntegration(Integration integration) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Integration'),
        content: Text(
            'Are you sure you want to disconnect ${integration.platformName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final integrationService = ref.read(integrationServiceProvider);
        if (integrationService == null) {
          throw Exception('No business selected');
        }
        await integrationService.disconnectIntegration(integration.id);
        await _loadIntegrations();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Integration disconnected successfully')),
          );
        }
      } on IntegrationException catch (e) {
        if (mounted) {
          setState(() => _error = e.message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _error = 'Failed to disconnect integration');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to disconnect integration'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncIntegration(Integration integration) async {
    setState(() => _isLoading = true);

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }
      await integrationService.syncIntegration(integration.id);
      await _loadIntegrations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${integration.platformName} synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on IntegrationException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to sync integration');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync integration'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteIntegration(Integration integration) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Integration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the ${integration.platformName} integration?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All sync settings will be lost.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final integrationService = ref.read(integrationServiceProvider);
        if (integrationService == null) {
          throw Exception('No business selected');
        }
        await integrationService.deleteIntegration(integration.id);
        await _loadIntegrations();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Integration deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } on IntegrationException catch (e) {
        if (mounted) {
          setState(() => _error = e.message);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _error = 'Failed to delete integration');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete integration'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(selectedBusinessIdProvider);
    
    // Show error if no business is selected
    if (businessId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Integrations'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No Business Selected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select a business to manage integrations',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'Integrations',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIntegrations,
          ),
        ],
      ),
      body: _isLoading
          ? const error.LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadIntegrations,
                )
              : _integrations.isEmpty
                  ? const EmptyView(
                      icon: Icons.link_off,
                      title: 'No Integrations',
                      message: 'Connect your store with external platforms',
                      action: Text('Add Integration'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _integrations.length,
                      itemBuilder: (context, index) {
                        final integration = _integrations[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  NetworkImage(integration.platformIcon),
                            ),
                            title: Text(integration.platformName),
                            subtitle: Text(
                              'Status: ${integration.status}',
                              style: TextStyle(
                                color: _getStatusColor(integration.status),
                              ),
                            ),
                            onTap: () {
                              // Navigate to Instagram integration screen for Instagram
                              if (integration.platformId == 'instagram') {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.instagramIntegration,
                                );
                              }
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (integration.status == 'connected' || integration.status == 'active')
                                  IconButton(
                                    icon: const Icon(Icons.sync),
                                    tooltip: 'Sync Now',
                                    onPressed: () => _syncIntegration(integration),
                                  ),
                                if (integration.platformId == 'instagram' && (integration.status == 'connected' || integration.status == 'active'))
                                  IconButton(
                                    icon: const Icon(Icons.analytics),
                                    tooltip: 'Analytics',
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        AppRoutes.instagramAnalytics,
                                        arguments: {'integrationId': integration.id},
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.settings),
                                  tooltip: 'Settings',
                                  onPressed: () {
                                    NavigationService
                                        .navigateToIntegrationSettings(
                                            integration.id);
                                  },
                                ),
                                if (integration.status == 'connected' || integration.status == 'active')
                                  IconButton(
                                    icon: const Icon(Icons.link_off),
                                    tooltip: 'Disconnect',
                                    onPressed: () =>
                                        _disconnectIntegration(integration),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteIntegration(integration),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          NavigationService.navigateToAddIntegration();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Integration'),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
      case 'active':
        return Colors.green;
      case 'disconnected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
