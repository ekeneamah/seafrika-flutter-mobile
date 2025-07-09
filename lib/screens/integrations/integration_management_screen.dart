import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/empty_view.dart';

class IntegrationManagementScreen extends StatefulWidget {
  const IntegrationManagementScreen({super.key});

  @override
  State<IntegrationManagementScreen> createState() =>
      _IntegrationManagementScreenState();
}

class _IntegrationManagementScreenState
    extends State<IntegrationManagementScreen> {
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
      final integrationService = context.read<IntegrationService>();
      final integrations = await integrationService.fetchIntegrations();
      setState(() {
        _integrations = integrations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load integrations';
        _isLoading = false;
      });
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
        final integrationService = context.read<IntegrationService>();
        await integrationService.disconnectIntegration(integration.id);
        await _loadIntegrations();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Integration disconnected successfully')),
          );
        }
      } catch (e) {
        setState(() => _error = 'Failed to disconnect integration');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrations'),
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
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.settings),
                                  onPressed: () {
                                    NavigationService
                                        .navigateToIntegrationSettings(
                                            integration.id);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.link_off),
                                  onPressed: () =>
                                      _disconnectIntegration(integration),
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
