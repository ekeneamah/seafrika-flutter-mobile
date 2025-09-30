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
    debugPrint('[IntegrationScreen] initState() called');
    _searchController.addListener(() {
      _onSearchChanged(_searchController.text);
    });
    debugPrint('[IntegrationScreen] Starting _loadIntegrations()');
    _loadIntegrations();
    _setupIntegrationsListener();
  }

  Future<void> _loadIntegrations() async {
    debugPrint('[IntegrationScreen] _loadIntegrations() started');
    setState(() {
      _isLoading = true;
      _error = null;
    });
    debugPrint('[IntegrationScreen] State set to loading');

    try {
      final integrationService = ref.read(integrationServiceProvider);
      debugPrint(
          '[IntegrationScreen] Got integrationService: ${integrationService != null}');
      if (integrationService == null) {
        debugPrint(
            '[IntegrationScreen] ERROR: integrationService is null, no business selected');
        throw Exception('No business selected');
      }
      debugPrint('[IntegrationScreen] Calling fetchIntegrations...');
      final integrations = await integrationService.fetchIntegrations();
      debugPrint(
          '[IntegrationScreen] Integrations loaded: ${integrations.length} items');
      for (final integration in integrations) {
        debugPrint(
            '  Integration: id=${integration.id}, platform=${integration.platformName}, icon=${integration.platformIcon}, status=${integration.status}, error=${integration.errorMessage}');
        debugPrint('  AccountInfo: ${integration.accountInfo}');
        debugPrint('  PageName: ${integration.pageName}');
        debugPrint('  TikTokDisplayName: ${integration.tikTokDisplayName}');
        debugPrint('  TikTokUsername: ${integration.tikTokUsername}');
        try {
          debugPrint('  YouTubeTitle: ${integration.youTubeTitle}');
          debugPrint('  YouTubeCustomUrl: ${integration.youTubeCustomUrl}');
        } catch (e) {
          debugPrint('  YouTubeTitle: Error accessing YouTube properties - $e');
        }
      }
      debugPrint('[IntegrationScreen] Processing complete, mounted: $mounted');
      if (mounted) {
        debugPrint(
            '[IntegrationScreen] Setting state with ${integrations.length} integrations');
        setState(() {
          _integrations = integrations;
          _isLoading = false;
        });
        debugPrint(
            '[IntegrationScreen] State updated, calling _filterIntegrations()');
        _filterIntegrations();
      } else {
        debugPrint(
            '[IntegrationScreen] Widget not mounted, skipping state update');
      }
    } on IntegrationException catch (e) {
      debugPrint(
          '[IntegrationScreen] IntegrationException caught: ${e.message}');
      debugPrint('[IntegrationScreen] Exception stack trace: ${e.toString()}');
      if (mounted) {
        debugPrint('[IntegrationScreen] Setting error state');
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      } else {
        debugPrint(
            '[IntegrationScreen] Widget not mounted, skipping error state update');
      }
    } catch (e, stackTrace) {
      debugPrint('[IntegrationScreen] Unexpected error caught: $e');
      debugPrint('[IntegrationScreen] Stack trace: $stackTrace');
      if (mounted) {
        debugPrint('[IntegrationScreen] Setting generic error state');
        setState(() {
          _error = 'Failed to load integrations';
          _isLoading = false;
        });
        debugPrint('[IntegrationScreen] Generic error state set');
      } else {
        debugPrint(
            '[IntegrationScreen] Widget not mounted, skipping generic error state update');
      }
    }
    debugPrint('[IntegrationScreen] _loadIntegrations() completed');
  }

  void _setupIntegrationsListener() {
    debugPrint('[IntegrationScreen] _setupIntegrationsListener() called');
    final businessId = ref.read(selectedBusinessIdProvider);
    debugPrint('[IntegrationScreen] Business ID from provider: $businessId');
    if (businessId != null) {
      debugPrint(
          '[IntegrationScreen] Setting up Firestore listener for businessId: $businessId');
      // Cancel existing subscription if any
      _integrationsSubscription?.cancel();
      debugPrint('[IntegrationScreen] Cancelled previous subscription if any');

      // Listen to integrations collection for real-time updates
      _integrationsSubscription = FirebaseFirestore.instance
          .collection('integrations')
          .where('businessId', isEqualTo: businessId)
          .snapshots()
          .listen(
        (snapshot) {
          debugPrint(
              '[IntegrationScreen] Firestore listener triggered with ${snapshot.docs.length} docs');
          debugPrint(
              '[IntegrationScreen] Snapshot metadata: pending=${snapshot.metadata.hasPendingWrites}, fromCache=${snapshot.metadata.isFromCache}');
          // Update integrations list when changes occur
          final integrations = snapshot.docs.map((doc) {
            final data = doc.data();
            debugPrint('[IntegrationScreen] Processing doc: ${doc.id}');
            data['id'] = doc.id;
            debugPrint(
                '[IntegrationScreen] Processing doc: id=${doc.id}, data=$data');
            try {
              final integration = Integration.fromMap(data);
              debugPrint(
                  '[IntegrationScreen] Successfully created Integration for doc: ${doc.id}');
              return integration;
            } catch (e, stackTrace) {
              debugPrint(
                  '[IntegrationScreen] ERROR creating Integration from doc ${doc.id}: $e');
              debugPrint('[IntegrationScreen] Stack trace: $stackTrace');
              debugPrint('[IntegrationScreen] Doc data: $data');
              rethrow;
            }
          }).toList();

          debugPrint(
              '[IntegrationScreen] Processed ${integrations.length} integrations successfully');

          // Debug: Show accountInfo for each integration
          for (final integration in integrations) {
            try {
              debugPrint(
                  '[IntegrationScreen] Integration ${integration.id}: accountInfo=${integration.accountInfo}, pageName=${integration.pageName}, tikTokDisplayName=${integration.tikTokDisplayName}, tikTokUsername=${integration.tikTokUsername}, youTubeTitle=${integration.youTubeTitle}, youTubeCustomUrl=${integration.youTubeCustomUrl}');
            } catch (e) {
              debugPrint(
                  '[IntegrationScreen] ERROR accessing properties for integration ${integration.id}: $e');
            }
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
    debugPrint('[IntegrationScreen] dispose() called');
    _integrationsSubscription?.cancel();
    debugPrint('[IntegrationScreen] Cancelled integrations subscription');
    _searchController.dispose();
    debugPrint('[IntegrationScreen] Disposed search controller');
    super.dispose();
    debugPrint('[IntegrationScreen] dispose() completed');
  }

  // Filter integrations based on search query and filters
  void _filterIntegrations() {
    debugPrint('[IntegrationScreen] _filterIntegrations() called');
    debugPrint(
        '[IntegrationScreen] Total integrations: ${_integrations.length}');
    debugPrint('[IntegrationScreen] Search query: "$_searchQuery"');
    debugPrint('[IntegrationScreen] Status filter: "$_statusFilter"');
    debugPrint('[IntegrationScreen] Platform filter: "$_platformFilter"');

    setState(() {
      try {
        _filteredIntegrations = _integrations.where((integration) {
          debugPrint(
              '[IntegrationScreen] Filtering integration: ${integration.id} (${integration.platformName})');

          // Search filter
          bool matchesSearch = false;
          try {
            matchesSearch = _searchQuery.isEmpty ||
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
                    false) ||
                (integration.tikTokDisplayName
                        ?.toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ??
                    false) ||
                (integration.tikTokUsername
                        ?.toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ??
                    false) ||
                (integration.youTubeTitle
                        ?.toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ??
                    false) ||
                (integration.youTubeCustomUrl
                        ?.toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ??
                    false);
          } catch (e) {
            debugPrint(
                '[IntegrationScreen] Error in search filter for ${integration.id}: $e');
            matchesSearch =
                _searchQuery.isEmpty; // Default to show if search is empty
          }

          debugPrint(
              '[IntegrationScreen] ${integration.id} matches search: $matchesSearch');

          // Status filter
          bool matchesStatus = false;
          try {
            matchesStatus = _statusFilter == 'all' ||
                (_statusFilter == 'active' && integration.status == 'active') ||
                (_statusFilter == 'connected' &&
                    (integration.status == 'connected' ||
                        integration.status == 'active')) ||
                (_statusFilter == 'disconnected' &&
                    integration.status == 'inactive') ||
                (_statusFilter == 'error' &&
                    (integration.status == 'incomplete' ||
                        integration.status == 'error'));
          } catch (e) {
            debugPrint(
                '[IntegrationScreen] Error in status filter for ${integration.id}: $e');
            matchesStatus = true; // Default to show
          }

          debugPrint(
              '[IntegrationScreen] ${integration.id} matches status: $matchesStatus');

          // Platform filter
          bool matchesPlatform = false;
          try {
            matchesPlatform = _platformFilter == 'all' ||
                integration.platformId
                    .toLowerCase()
                    .contains(_platformFilter.toLowerCase());
          } catch (e) {
            debugPrint(
                '[IntegrationScreen] Error in platform filter for ${integration.id}: $e');
            matchesPlatform = true; // Default to show
          }

          debugPrint(
              '[IntegrationScreen] ${integration.id} matches platform: $matchesPlatform');

          final result = matchesSearch && matchesStatus && matchesPlatform;
          debugPrint(
              '[IntegrationScreen] ${integration.id} final result: $result');
          return result;
        }).toList();

        debugPrint(
            '[IntegrationScreen] Filtered to ${_filteredIntegrations.length} integrations');
      } catch (e, stackTrace) {
        debugPrint('[IntegrationScreen] ERROR in _filterIntegrations: $e');
        debugPrint('[IntegrationScreen] Stack trace: $stackTrace');
        _filteredIntegrations = _integrations; // Fallback to showing all
      }
    });
    debugPrint('[IntegrationScreen] _filterIntegrations() completed');
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
    debugPrint('[IntegrationScreen] build() called');
    final businessId = ref.watch(selectedBusinessIdProvider);
    debugPrint('[IntegrationScreen] Business ID in build: $businessId');
    debugPrint('[IntegrationScreen] _isLoading: $_isLoading, _error: $_error');
    debugPrint(
        '[IntegrationScreen] _integrations.length: ${_integrations.length}');
    debugPrint(
        '[IntegrationScreen] _filteredIntegrations.length: ${_filteredIntegrations.length}');

    // Show error if no business is selected
    if (businessId == null) {
      debugPrint(
          '[IntegrationScreen] No business selected, showing error screen');
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

    debugPrint('[IntegrationScreen] Building main scaffold');
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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          NavigationService.navigateToAddIntegration();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Integration'),
      ),
    );
  }

  Widget _buildBody() {
    debugPrint(
        '[IntegrationScreen] Building body widget, loading: $_isLoading, error: $_error, integrations count: ${_integrations.length}');

    if (_isLoading) {
      debugPrint('[IntegrationScreen] Showing loading view');
      return const error.LoadingView();
    } else if (_error != null) {
      debugPrint('[IntegrationScreen] Showing error view: $_error');
      return error.ErrorView(
        message: _error!,
        onRetry: _loadIntegrations,
      );
    } else if (_integrations.isEmpty) {
      debugPrint('[IntegrationScreen] Showing empty view (no integrations)');
      return const EmptyView(
        icon: Icons.link_off,
        title: 'No Integrations',
        message: 'Connect your store with external platforms',
        action: Text('Add Integration'),
      );
    } else {
      debugPrint('[IntegrationScreen] Building integrations list');
      return Column(
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
                    hintText: 'Search by platform or page name...',
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
                        onChanged: (value) => _onStatusFilterChanged(value!),
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All Status')),
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'connected', child: Text('Connected')),
                          DropdownMenuItem(
                              value: 'disconnected',
                              child: Text('Disconnected')),
                          DropdownMenuItem(
                              value: 'error', child: Text('Error')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Platform Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _platformFilter,
                        onChanged: (value) => _onPlatformFilterChanged(value!),
                        decoration: InputDecoration(
                          labelText: 'Platform',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All Platforms')),
                          DropdownMenuItem(
                              value: 'facebook', child: Text('Facebook')),
                          DropdownMenuItem(
                              value: 'instagram', child: Text('Instagram')),
                          DropdownMenuItem(
                              value: 'tiktok', child: Text('TikTok')),
                          DropdownMenuItem(
                              value: 'youtube', child: Text('YouTube')),
                          DropdownMenuItem(
                              value: 'whatsapp', child: Text('WhatsApp')),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Results Section
          Expanded(
            child: _filteredIntegrations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No integrations found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredIntegrations.length,
                    itemBuilder: (context, index) {
                      final integration = _filteredIntegrations[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            // If integration is incomplete, show retry dialog
                            if (integration.status == 'incomplete') {
                              _showRetryDialog(integration);
                              return;
                            }

                            // Navigate to platform-specific detail screen
                            switch (integration.channel) {
                              case 'instagram':
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.instagramIntegration,
                                  arguments: {'integrationId': integration.id},
                                );
                                break;
                              case 'facebook_pages':
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.facebookDashboard,
                                  arguments: {
                                    'integrationId': integration.id,
                                    'initialTab': 0,
                                  },
                                );
                                break;
                              case 'messenger':
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.messengerIntegration,
                                  arguments: {'integrationId': integration.id},
                                );
                                break;
                              case 'facebook':
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.facebookDashboard,
                                  arguments: {
                                    'integrationId': integration.id,
                                    'initialTab': 0,
                                  },
                                );
                                break;
                              case 'whatsapp':
                              case 'whatsapp_business':
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.whatsappIntegration,
                                  arguments: {'integrationId': integration.id},
                                );
                                break;
                              case 'tiktok':
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.tiktokIntegrationAlt,
                                  arguments: {'integrationId': integration.id},
                                );
                                break;
                              case 'youtube':
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.youTubeIntegration,
                                  arguments: {'integrationId': integration.id},
                                );
                                break;
                              default:
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.genericIntegrationDashboard,
                                  arguments: {
                                    'integrationId': integration.id,
                                    'platformName': integration.platformName,
                                  },
                                );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Header row with icon, title and status
                                Row(
                                  children: [
                                    // Icon
                                    Builder(
                                      builder: (context) {
                                        if (integration.platformIcon
                                            .startsWith('http')) {
                                          debugPrint(
                                              '[IntegrationScreen] Using NetworkImage for icon: ${integration.platformIcon}');
                                          return CircleAvatar(
                                            radius: 16,
                                            backgroundImage: NetworkImage(
                                                integration.platformIcon),
                                          );
                                        } else {
                                          debugPrint(
                                              '[IntegrationScreen] Using AssetImage for icon: ${integration.platformIcon}');
                                          return CircleAvatar(
                                            radius: 16,
                                            backgroundImage: AssetImage(
                                                integration.platformIcon),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 10),

                                    // Title and status
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            integration.platformName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          // Show page name if available
                                          if (integration.pageName != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 1),
                                              child: Text(
                                                integration.pageName!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          // Show Instagram username if available and different from page name
                                          if (integration.instagramUsername !=
                                                  null &&
                                              integration.instagramUsername !=
                                                  integration.pageName)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 1),
                                              child: Text(
                                                '@${integration.instagramUsername!}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[500],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          // Show TikTok display name if available
                                          if (integration.tikTokDisplayName !=
                                              null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 1),
                                              child: Text(
                                                integration.tikTokDisplayName!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          // Show TikTok username if available and different from display name
                                          if (integration.tikTokUsername !=
                                                  null &&
                                              integration.tikTokUsername !=
                                                  integration.tikTokDisplayName)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 1),
                                              child: Text(
                                                '@${integration.tikTokUsername!}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[500],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          // Show YouTube channel title if available
                                          Builder(
                                            builder: (context) {
                                              try {
                                                if (integration.youTubeTitle !=
                                                    null) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 1),
                                                    child: Text(
                                                      integration.youTubeTitle!,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                debugPrint(
                                                    'Error displaying YouTube title: $e');
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                          // Show YouTube custom URL if available and different from title
                                          Builder(
                                            builder: (context) {
                                              try {
                                                if (integration
                                                            .youTubeCustomUrl !=
                                                        null &&
                                                    integration
                                                            .youTubeCustomUrl !=
                                                        integration
                                                            .youTubeTitle) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 1),
                                                    child: Text(
                                                      integration
                                                          .youTubeCustomUrl!,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey[500],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                debugPrint(
                                                    'Error displaying YouTube custom URL: $e');
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),
                                          const SizedBox(height: 2),
                                          integration.status == 'incomplete'
                                              ? Row(
                                                  children: [
                                                    Icon(Icons.warning,
                                                        size: 14,
                                                        color:
                                                            Colors.orange[600]),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        integration
                                                                .errorMessage ??
                                                            'Setup incomplete',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .orange[600],
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(
                                                            integration.status),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _formatStatus(
                                                          integration.status),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: _getStatusColor(
                                                            integration.status),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ],
                                      ),
                                    ),

                                    // Actions
                                    PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        switch (value) {
                                          case 'refresh':
                                            await _loadIntegrations();
                                            break;
                                          case 'delete':
                                            await _deleteIntegration(
                                                integration);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'refresh',
                                          child: Row(
                                            children: [
                                              Icon(Icons.refresh),
                                              SizedBox(width: 8),
                                              Text('Refresh'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
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
      );
    }
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

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'connected':
        return 'Connected';
      case 'active':
        return 'Active';
      case 'disconnected':
        return 'Disconnected';
      case 'pending':
        return 'Pending';
      case 'incomplete':
        return 'Incomplete';
      default:
        return status.toUpperCase();
    }
  }
}
