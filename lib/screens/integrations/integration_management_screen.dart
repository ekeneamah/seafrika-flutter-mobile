import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/meta_integration_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/empty_view.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

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
  List<Integration> _filteredIntegrations = [];
  StreamSubscription<QuerySnapshot>? _integrationsSubscription;

  // Search and filter variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'active'; // all, connected, disconnected, error
  String _platformFilter = 'all'; // all, facebook, instagram, etc.

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
    });
    _loadIntegrations();
    _setupIntegrationsListener();
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
      debugPrint('[IntegrationScreen] Calling fetchIntegrations...');
      final integrations = await integrationService.fetchIntegrations();
      debugPrint('[IntegrationScreen] Integrations loaded:');
      for (final integration in integrations) {
        debugPrint(
            '  Integration: id=${integration.id}, platform=${integration.platformName}, icon=${integration.platformIcon}, status=${integration.status}, error=${integration.errorMessage}');
        debugPrint('  AccountInfo: ${integration.accountInfo}');
        debugPrint('  PageName: ${integration.pageName}');
      }
      if (mounted) {
        setState(() {
          _integrations = integrations;
          _isLoading = false;
        });
        _filterIntegrations();
      }
    } on IntegrationException catch (e) {
      debugPrint('[IntegrationScreen] IntegrationException: ${e.message}');
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[IntegrationScreen] Unexpected error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load integrations';
          _isLoading = false;
        });
      }
    }
  }

  void _setupIntegrationsListener() {
    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId != null) {
      debugPrint(
          '[IntegrationScreen] Setting up Firestore listener for businessId: $businessId');
      // Listen to integrations collection for real-time updates
      _integrationsSubscription = FirebaseFirestore.instance
          .collection('integrations')
          .where('businessId', isEqualTo: businessId)
          .snapshots()
          .listen(
        (snapshot) {
          debugPrint(
              '[IntegrationScreen] Firestore listener triggered with ${snapshot.docs.length} docs');
          // Update integrations list when changes occur
          final integrations = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            debugPrint(
                '[IntegrationScreen] Processing doc: id=${doc.id}, data=$data');
            return Integration.fromMap(data);
          }).toList();

          debugPrint(
              '[IntegrationScreen] Processed ${integrations.length} integrations');

          // Debug: Show accountInfo for each integration
          for (final integration in integrations) {
            debugPrint(
                '[IntegrationScreen] Integration ${integration.id}: accountInfo=${integration.accountInfo}, pageName=${integration.pageName}');
          }

          // Check for new integrations with errors
          for (final integration in integrations) {
            if (integration.status == 'incomplete' &&
                integration.errorMessage != null &&
                integration.errorMessage!.isNotEmpty) {
              debugPrint(
                  '[IntegrationScreen] Found incomplete integration: ${integration.id}');
              // Show error dialog for incomplete integrations
              _showRetryDialog(integration);
            }
          }

          if (mounted) {
            setState(() {
              _integrations = integrations;
              _isLoading = false;
              _error = null;
            });
            _filterIntegrations();
          }
        },
        onError: (error) {
          debugPrint('[IntegrationScreen] Firestore listener error: $error');
          if (mounted) {
            setState(() {
              _error = 'Failed to load integrations: $error';
              _isLoading = false;
            });
          }
        },
      );
    } else {
      debugPrint(
          '[IntegrationScreen] No businessId available, cannot setup listener');
    }
  }

  void _showRetryDialog(Integration integration) {
    // Avoid showing multiple dialogs for the same integration
    if (_hasShownRetryDialog(integration.id)) return;
    _markRetryDialogShown(integration.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 28),
                SizedBox(width: 12),
                Text('Connection Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'There was an issue connecting your ${integration.platformName} account.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 12),
                Text(
                  'This could happen due to network issues, permissions, or temporary service problems.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 16),
                Text(
                  'Would you like to try connecting again?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteIntegration(integration);
                },
                child:
                    Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _retryIntegration(integration);
                },
                child: Text('Retry Connection'),
              ),
            ],
          ),
        );
      }
    });
  }

  // Track shown dialogs to avoid duplicates
  final Set<String> _shownRetryDialogs = {};

  bool _hasShownRetryDialog(String integrationId) {
    return _shownRetryDialogs.contains(integrationId);
  }

  void _markRetryDialogShown(String integrationId) {
    _shownRetryDialogs.add(integrationId);
  }

  Future<void> _retryIntegration(Integration integration) async {
    // Open the OAuth URL again for retry
    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId == null) return;

    try {
      // Use unified Meta integration service for Meta platforms
      if (_isMetaPlatform(integration.channel)) {
        // Use MetaIntegrationService for all Meta platforms (Facebook, Instagram, Messenger)
        final response = await MetaIntegrationService.generateOAuthUrl(
          channels: _getMetaChannels(integration.channel),
          businessId: businessId,
          state: 'retry_${DateTime.now().millisecondsSinceEpoch}',
        );

        // Launch the OAuth URL
        final uri = Uri.parse(response.authUrl);
        print('Attempting to launch OAuth URL: ${response.authUrl}');

        try {
          bool launched = false;

          // Try external application first
          if (await canLaunchUrl(uri)) {
            print(
                'canLaunchUrl returned true, launching with externalApplication...');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('externalApplication launch completed');
          } else {
            print('canLaunchUrl returned false, trying platformDefault...');
            await launchUrl(uri, mode: LaunchMode.platformDefault);
            launched = true;
            print('platformDefault launch completed');
          }

          if (launched) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Opening ${integration.platformName} authentication. Please complete the setup in your browser.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        } catch (launchError) {
          print('Error launching URL: $launchError');
          throw Exception('Failed to launch browser: $launchError');
        }
      } else {
        // For non-Meta platforms, show not implemented message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${integration.platformName} retry not yet implemented'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Error opening ${integration.platformName} authentication: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Check if platform is a Meta platform
  bool _isMetaPlatform(String platformId) {
    final metaPlatforms = [
      'instagram',
      'facebook',
      'facebook_pages',
      'messenger'
    ];
    return metaPlatforms.contains(platformId.toLowerCase());
  }

  /// Get Meta channels for a specific platform
  List<String> _getMetaChannels(String platformId) {
    switch (platformId.toLowerCase()) {
      case 'instagram':
        return ['instagram'];
      case 'facebook':
      case 'facebook_pages':
        return ['facebook_pages'];
      case 'messenger':
        return ['messenger'];
      default:
        // Default to all Meta platforms for comprehensive integration
        return ['facebook_pages', 'messenger', 'instagram'];
    }
  }

  @override
  void dispose() {
    _integrationsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Filter integrations based on search query and filters
  void _filterIntegrations() {
    setState(() {
      _filteredIntegrations = _integrations.where((integration) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            integration.platformName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            (integration.pageName
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (integration.instagramUsername
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);

        // Status filter
        final matchesStatus = _statusFilter == 'all' ||
            (_statusFilter == 'active' && integration.status == 'active') ||
            (_statusFilter == 'connected' &&
                (integration.status == 'connected' ||
                    integration.status == 'active')) ||
            (_statusFilter == 'disconnected' &&
                integration.status == 'inactive') ||
            (_statusFilter == 'error' &&
                (integration.status == 'incomplete' ||
                    integration.status == 'error'));

        // Platform filter
        final matchesPlatform = _platformFilter == 'all' ||
            integration.platformId
                .toLowerCase()
                .contains(_platformFilter.toLowerCase());

        return matchesSearch && matchesStatus && matchesPlatform;
      }).toList();
    });
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _filterIntegrations();
  }

  void _onStatusFilterChanged(String status) {
    setState(() {
      _statusFilter = status;
    });
    _filterIntegrations();
  }

  void _onPlatformFilterChanged(String platform) {
    setState(() {
      _platformFilter = platform;
    });
    _filterIntegrations();
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
            Text(
                'Are you sure you want to delete the ${integration.platformName} integration?'),
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
                  : Column(
                      children: [
                        // Search and Filter Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.grey[50],
                          child: Column(
                            children: [
                              // Search Bar
                              TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText:
                                      'Search by platform or page name...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Filter Row
                              Row(
                                children: [
                                  // Status Filter
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _statusFilter,
                                      onChanged: (value) =>
                                          _onStatusFilterChanged(value!),
                                      decoration: InputDecoration(
                                        labelText: 'Status',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'all',
                                            child: Text('All Status')),
                                        DropdownMenuItem(
                                            value: 'active',
                                            child: Text('Active')),
                                        DropdownMenuItem(
                                            value: 'connected',
                                            child: Text('Connected')),
                                        DropdownMenuItem(
                                            value: 'disconnected',
                                            child: Text('Disconnected')),
                                        DropdownMenuItem(
                                            value: 'error',
                                            child: Text('Error')),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Platform Filter
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _platformFilter,
                                      onChanged: (value) =>
                                          _onPlatformFilterChanged(value!),
                                      decoration: InputDecoration(
                                        labelText: 'Platform',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                            value: 'all',
                                            child: Text('All Platforms')),
                                        ...(_integrations
                                                .map((i) => i.platformId)
                                                .toSet())
                                            .map(
                                          (platform) => DropdownMenuItem(
                                            value: platform,
                                            child: Text(platform
                                                    .substring(0, 1)
                                                    .toUpperCase() +
                                                platform.substring(1)),
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
                        // Results count
                        if (_filteredIntegrations.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  '${_filteredIntegrations.length} integration${_filteredIntegrations.length == 1 ? '' : 's'} found',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Integration List
                        Expanded(
                          child: _filteredIntegrations.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off,
                                          size: 64, color: Colors.grey[400]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No integrations found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try adjusting your search or filters',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _filteredIntegrations.length,
                                  itemBuilder: (context, index) {
                                    final integration =
                                        _filteredIntegrations[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () {
                                          // If integration is incomplete, show retry dialog
                                          if (integration.status ==
                                              'incomplete') {
                                            _showRetryDialog(integration);
                                            return;
                                          }

                                          // Navigate to platform-specific detail screen
                                          switch (integration.channel) {
                                            case 'instagram':
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.instagramIntegration,
                                                arguments: {
                                                  'integrationId':
                                                      integration.id
                                                },
                                              );
                                              break;
                                            case 'facebook_pages':
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes
                                                    .facebookPagesIntegration,
                                                arguments: {
                                                  'integrationId':
                                                      integration.id
                                                },
                                              );
                                              break;
                                            case 'messenger':
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.messengerIntegration,
                                                arguments: {
                                                  'integrationId':
                                                      integration.id
                                                },
                                              );
                                              break;
                                            case 'facebook':
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.facebookIntegration,
                                                arguments: {
                                                  'integrationId':
                                                      integration.id
                                                },
                                              );
                                              break;
                                            case 'whatsapp':
                                            case 'whatsapp_business':
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.whatsappIntegration,
                                                arguments: {
                                                  'integrationId':
                                                      integration.id
                                                },
                                              );
                                              break;
                                            case 'tiktok':
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes.tiktokIntegration,
                                                arguments: {
                                                  'integrationId':
                                                      integration.id
                                                },
                                              );
                                              break;
                                            default:
                                              // For platforms without dedicated dashboards, use generic dashboard
                                              Navigator.pushNamed(
                                                context,
                                                AppRoutes
                                                    .genericIntegrationDashboard,
                                                arguments: {
                                                  'integrationId':
                                                      integration.id
                                                },
                                              );
                                              break;
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Header row with icon, title and status
                                              Row(
                                                children: [
                                                  // Icon
                                                  Builder(
                                                    builder: (context) {
                                                      if (integration
                                                          .platformIcon
                                                          .startsWith('http')) {
                                                        debugPrint(
                                                            '[IntegrationScreen] Using NetworkImage for icon: ${integration.platformIcon}');
                                                        return CircleAvatar(
                                                          radius: 16,
                                                          backgroundImage:
                                                              NetworkImage(
                                                                  integration
                                                                      .platformIcon),
                                                        );
                                                      } else {
                                                        debugPrint(
                                                            '[IntegrationScreen] Using AssetImage for icon: ${integration.platformIcon}');
                                                        return CircleAvatar(
                                                          radius: 16,
                                                          backgroundImage:
                                                              AssetImage(integration
                                                                  .platformIcon),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(width: 10),

                                                  // Title and status
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          integration
                                                              .platformName,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                        ),
                                                        // Show page name if available
                                                        if (integration
                                                                .pageName !=
                                                            null)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 1),
                                                            child: Text(
                                                              integration
                                                                  .pageName!,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Colors
                                                                    .grey[600],
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ),
                                                        // Show Instagram username if available and different from page name
                                                        if (integration
                                                                    .instagramUsername !=
                                                                null &&
                                                            integration
                                                                    .instagramUsername !=
                                                                integration
                                                                    .pageName)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 1),
                                                            child: Text(
                                                              '@${integration.instagramUsername!}',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey[500],
                                                                fontStyle:
                                                                    FontStyle
                                                                        .italic,
                                                              ),
                                                            ),
                                                          ),
                                                        const SizedBox(
                                                            height: 2),
                                                        integration.status ==
                                                                'incomplete'
                                                            ? Row(
                                                                children: [
                                                                  Icon(
                                                                      Icons
                                                                          .warning_amber_rounded,
                                                                      size: 16,
                                                                      color: Colors
                                                                          .orange),
                                                                  const SizedBox(
                                                                      width: 4),
                                                                  Expanded(
                                                                    child: Text(
                                                                      'Setup incomplete - Tap to retry',
                                                                      style:
                                                                          TextStyle(
                                                                        color: Colors
                                                                            .orange,
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              )
                                                            : Text(
                                                                'Status: ${integration.status}',
                                                                style:
                                                                    TextStyle(
                                                                  color: _getStatusColor(
                                                                      integration
                                                                          .status),
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              // Actions row - responsive layout
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  if (integration.status ==
                                                          'connected' ||
                                                      integration.status ==
                                                          'active')
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.sync,
                                                          size: 18),
                                                      tooltip: 'Sync Now',
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                      onPressed: () =>
                                                          _syncIntegration(
                                                              integration),
                                                    ),
                                                  if (integration.channel ==
                                                          'instagram' &&
                                                      (integration.status ==
                                                              'connected' ||
                                                          integration.status ==
                                                              'active'))
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.analytics,
                                                          size: 18),
                                                      tooltip: 'Analytics',
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pushNamed(
                                                          context,
                                                          AppRoutes
                                                              .instagramAnalytics,
                                                          arguments: {
                                                            'integrationId':
                                                                integration.id
                                                          },
                                                        );
                                                      },
                                                    ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.settings,
                                                        size: 18),
                                                    tooltip: 'Settings',
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    constraints:
                                                        const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                    onPressed: () {
                                                      NavigationService
                                                          .navigateToIntegrationSettings(
                                                              integration.id);
                                                    },
                                                  ),
                                                  if (integration.status ==
                                                          'connected' ||
                                                      integration.status ==
                                                          'active')
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.link_off,
                                                          size: 18),
                                                      tooltip: 'Disconnect',
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                      onPressed: () =>
                                                          _disconnectIntegration(
                                                              integration),
                                                    )
                                                  else
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 18),
                                                      tooltip: 'Delete',
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                      onPressed: () =>
                                                          _deleteIntegration(
                                                              integration),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
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
      case 'incomplete':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
