import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class IntegrationSettingsScreen extends ConsumerStatefulWidget {
  final String integrationId;

  const IntegrationSettingsScreen({
    super.key,
    required this.integrationId,
  });

  @override
  ConsumerState<IntegrationSettingsScreen> createState() =>
      _IntegrationSettingsScreenState();
}

class _IntegrationSettingsScreenState extends ConsumerState<IntegrationSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _error;
  Integration? _integration;
  bool _autoSync = false;
  int _syncInterval = 30;
  bool _syncInventory = true;
  bool _syncOrders = true;
  bool _syncProducts = true;

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
      final integration =
          await integrationService.fetchIntegration(widget.integrationId);
      if (mounted) {
        setState(() {
          _integration = integration;
          _autoSync = integration.settings.autoSync;
          _syncInterval = integration.settings.syncInterval;
          _syncInventory = integration.settings.syncInventory;
          _syncOrders = integration.settings.syncOrders;
          _syncProducts = integration.settings.syncProducts;
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
          _error = 'Failed to load integration settings';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final integrationService = ref.read(integrationServiceProvider);
      await integrationService.updateIntegrationSettings(
        integrationId: widget.integrationId,
        settings: IntegrationSettings(
          autoSync: _autoSync,
          syncInterval: _syncInterval,
          syncInventory: _syncInventory,
          syncOrders: _syncOrders,
          syncProducts: _syncProducts,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
        NavigationService.goBack();
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
        setState(() => _error = 'Failed to save settings');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integration Settings'),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? error.ErrorView(
                  message: _error!,
                  onRetry: _loadIntegration,
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync Settings',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text('Auto Sync'),
                                subtitle: const Text(
                                    'Automatically sync data with the platform'),
                                value: _autoSync,
                                onChanged: (value) {
                                  setState(() => _autoSync = value);
                                },
                              ),
                              if (_autoSync) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: _syncInterval.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Sync Interval (minutes)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Please enter sync interval';
                                    }
                                    final interval = int.tryParse(value!);
                                    if (interval == null || interval < 5) {
                                      return 'Interval must be at least 5 minutes';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    setState(() => _syncInterval =
                                        int.tryParse(value) ?? 30);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync Options',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text('Sync Inventory'),
                                subtitle:
                                    const Text('Keep inventory levels in sync'),
                                value: _syncInventory,
                                onChanged: (value) {
                                  setState(() => _syncInventory = value);
                                },
                              ),
                              SwitchListTile(
                                title: const Text('Sync Orders'),
                                subtitle:
                                    const Text('Sync orders from the platform'),
                                value: _syncOrders,
                                onChanged: (value) {
                                  setState(() => _syncOrders = value);
                                },
                              ),
                              SwitchListTile(
                                title: const Text('Sync Products'),
                                subtitle:
                                    const Text('Sync product information'),
                                value: _syncProducts,
                                onChanged: (value) {
                                  setState(() => _syncProducts = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Text('Save Settings'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
