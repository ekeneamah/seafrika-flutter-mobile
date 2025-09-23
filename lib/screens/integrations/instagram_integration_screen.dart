import 'package:flutter/material.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/screens/integrations/instagram_analytics_screen.dart';

/// Custom exception for token expiration
class TokenExpiredException implements Exception {
  final String message;
  TokenExpiredException(this.message);

  @override
  String toString() => 'TokenExpiredException: $message';
}

/// Instagram Business Integration Screen
///
/// This screen handles Instagram Business account integration using Facebook Graph API.
/// Unlike Instagram Basic Display API, Facebook Graph API provides access to:
/// - Business insights and analytics
/// - Content publishing capabilities
/// - Comments and DM management
/// - Advanced media management features
///
/// The integration works by:
/// 1. User authorizes via Facebook OAuth
/// 2. We access their Facebook pages
/// 3. We find pages connected to Instagram Business Accounts
/// 4. We use Facebook access token for Instagram Business features

class InstagramIntegrationScreen extends ConsumerStatefulWidget {
  final String? integrationId;

  const InstagramIntegrationScreen({
    super.key,
    this.integrationId,
  });

  @override
  ConsumerState<InstagramIntegrationScreen> createState() =>
      _InstagramIntegrationScreenState();
}

class _InstagramIntegrationScreenState
    extends ConsumerState<InstagramIntegrationScreen> {
  bool _isLoading = false;
  String? _error;
  Integration? _currentIntegration;
  Map<String, dynamic>? _instagramProfile;
  bool _showConnectionSteps = false;

  @override
  void initState() {
    super.initState();
    _checkExistingIntegration();
  }

  Future<void> _checkExistingIntegration() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No business selected';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        setState(() {
          _isLoading = false;
          _error = 'No business selected';
        });
        return;
      }

      Integration? instagramIntegration;

      // If integrationId is provided, fetch that specific integration
      if (widget.integrationId != null) {
        try {
          instagramIntegration =
              await integrationService.fetchIntegration(widget.integrationId!);
          debugPrint('Fetched integration by ID: $instagramIntegration');
        } catch (e) {
          debugPrint('Error fetching integration by ID: $e');
          setState(() {
            _error = 'Failed to load integration: $e';
            _isLoading = false;
          });
          return;
        }
      }
      if (instagramIntegration != null) {
        setState(() {
          _currentIntegration = instagramIntegration;
        });
        await _loadInstagramProfile();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to check existing integration: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInstagramProfile() async {
    if (_currentIntegration == null) return;

    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId == null) return;

    try {
      // Always use backend API for Instagram data - no direct token access
      debugPrint('Fetching Instagram profile from backend API...');

      // First try to use backend API to get fresh Instagram data
      if (_currentIntegration!.id.isNotEmpty) {
        try {
          await _fetchInstagramProfileFromBackend();
          return; // Success - exit early
        } catch (e) {
          debugPrint('Backend fetch failed: $e');
          // Continue to try using stored account info below
        }
      }

      // Fallback to profile information stored in the integration's accountInfo
      if (_currentIntegration?.accountInfo != null) {
        debugPrint('Using profile information from integration accountInfo...');
        final accountInfo = _currentIntegration!.accountInfo!;

        // Use stored metrics from accountInfo (no direct API calls)
        final transformedProfile = {
          'id': accountInfo['instagramId'],
          'username': accountInfo['instagramUsername'],
          'name':
              accountInfo['instagramUsername'], // Use username as display name
          // Add connected page info for reference
          'connectedPageId': accountInfo['pageId'],
          'connectedPageName': accountInfo['pageName'],
          // Use stored metrics from accountInfo
          'followers_count': accountInfo['followers_count'],
          'follows_count': accountInfo['follows_count'],
          'media_count': accountInfo['media_count'],
          'profile_picture_url': accountInfo['profile_picture_url'],
          'biography': accountInfo['biography'],
          'website': accountInfo['website'],
        };

        setState(() {
          _instagramProfile = transformedProfile;
        });
        debugPrint(
            'Profile loaded from accountInfo: @${transformedProfile['username']}');
        return;
      }

      // If no profile information is available, show a message
      debugPrint('No Instagram profile information available');
      setState(() {
        _instagramProfile = null;
        _error =
            null; // Don't treat this as an error for connected integrations
      });
    } catch (e) {
      debugPrint('Failed to load Instagram profile: $e');
      if (e is TokenExpiredException) {
        debugPrint('[Instagram] TokenExpiredException detected: ${e.message}');
        setState(() {
          _instagramProfile = null;
          _error = 'token_expired';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          debugPrint('[Instagram] Showing token expired dialog');
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[600]),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Instagram Token Expired')),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Instagram integration has expired and needs to be reconnected.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This happens periodically for security reasons. You\'ll need to:',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Reconnect your Instagram Business account'),
                    const Text('• Grant permissions again'),
                    const Text('• Your settings and data will be preserved'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      debugPrint(
                          '[Instagram] User chose "Later" on token expired dialog');
                      Navigator.of(context).pop();
                    },
                    child: const Text('Later'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      debugPrint(
                          '[Instagram] User chose "Reconnect Instagram" on token expired dialog');
                      Navigator.of(context).pop();
                      debugPrint(
                          '[Instagram] Navigating to Add Integration for Instagram');
                      Navigator.of(context).pushNamed(
                        AppRoutes.addIntegration,
                        arguments: {'platform': 'instagram'},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE4405F),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reconnect Instagram'),
                  ),
                ],
              );
            },
          );
        });
      } else {
        setState(() {
          _instagramProfile = null;
          _error = 'Failed to load Instagram profile: $e';
        });
      }
    }
  }

  Future<void> _fetchInstagramProfileFromBackend() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final integrationService = ref.read(integrationServiceProvider);
    if (businessId == null || _currentIntegration?.id == null) return;

    try {
      // Get access token
      final userIdToken = await integrationService?.getUserIdToken();
      if (userIdToken == null) {
        throw Exception('Failed to get user id token');
      }

      // Call backend API to get Instagram profile data
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/instagram/${_currentIntegration!.id}/profile'),
        headers: {
          'Business-ID': businessId,
          'Authorization': 'Bearer $userIdToken',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Backend Instagram profile response: ${response.statusCode}');
      debugPrint('Backend Instagram profile body: ${response.body}');

      if (response.statusCode == 200) {
        final profileData = json.decode(response.body);
        setState(() {
          _instagramProfile = profileData;
        });
        debugPrint(
            'Instagram profile loaded from backend: @${profileData['username']}');
      } else if (response.statusCode == 401) {
        // Handle token expiration
        final errorBody = json.decode(response.body);
        final errorMessage = errorBody['message'] ?? 'Token expired';
        debugPrint('Instagram token expired: $errorMessage');
        throw TokenExpiredException(errorMessage);
      } else {
        throw Exception(
            'Backend API failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Failed to fetch Instagram profile from backend: $e');
      throw e;
    }
  }

  Future<void> _fetchIntegrationLogs() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/v1/config/facebook/instagram/integration-logs'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Integration logs response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final logs = json.decode(response.body);
        debugPrint('=== INSTAGRAM INTEGRATION LOGS ===');
        for (var log in logs) {
          debugPrint('${log['type']}: ${log['timestamp']} - ${log['details']}');
        }
        debugPrint('=== END INTEGRATION LOGS ===');

        // Show logs in a dialog for debugging
        if (mounted) {
          _showIntegrationLogsDialog(logs);
        }
      } else {
        debugPrint(
            'Failed to fetch integration logs: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching integration logs: $e');
    }
  }

  Future<void> _refreshInstagramMetrics() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);

    if (businessId == null || _currentIntegration?.id == null) {
      _showErrorSnackBar('Unable to refresh: integration not found');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint(
          'Manually refreshing Instagram metrics for integration: ${_currentIntegration!.id}');

      final response = await http.post(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/v1/config/instagram/${_currentIntegration!.id}/sync-metrics'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Metrics sync response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        debugPrint('Metrics refreshed successfully: ${responseData}');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Instagram metrics updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Reload the profile to show updated metrics
          await _loadInstagramProfile();
        }
      } else {
        debugPrint(
            'Failed to refresh metrics: ${response.statusCode} - ${response.body}');
        _showErrorSnackBar('Failed to refresh metrics. Please try again.');
      }
    } catch (e) {
      debugPrint('Error refreshing Instagram metrics: $e');
      _showErrorSnackBar(
          'Network error. Please check your connection and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _showIntegrationLogsDialog(List<dynamic> logs) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Integration Debug Logs'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${log['type']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${log['timestamp']}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${log['details']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Copy logs to clipboard
                final logText = logs
                    .map((log) =>
                        '${log['type']}: ${log['timestamp']}\n${log['details']}\n')
                    .join('\n');
                Clipboard.setData(ClipboardData(text: logText));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copied to clipboard')),
                );
              },
              child: const Text('Copy to Clipboard'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startInstagramConnection() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId == null) {
      setState(() {
        _error = 'No business selected';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get Meta auth URL from backend (supports Instagram integration)
      final authService = ref.read(authServiceProvider);
      final response = await http.get(
        Uri.parse(
          'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/meta/auth-url'
          '?channels=${Uri.encodeComponent('instagram')}'
          '&redirect_uri=${Uri.encodeComponent('https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/meta/oauth/redirect')}'
          '&state=${Uri.encodeComponent('vendor_${DateTime.now().millisecondsSinceEpoch}')}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final authUrl = data['auth_url'];

        // Launch Instagram OAuth URL with multiple fallback options
        try {
          // First try to launch in external browser
          final uri = Uri.parse(authUrl);

          if (await canLaunchUrl(uri)) {
            // Try external application first (Instagram app if available)
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
          } else {
            // Fallback to in-app web view
            await launchUrl(
              uri,
              mode: LaunchMode.inAppWebView,
            );
          }

          // Show instructions to user
          _showAuthInstructions();
        } catch (launchError) {
          // If URL launching fails, try platform-specific webview
          try {
            await launchUrl(
              Uri.parse(authUrl),
              mode: LaunchMode.platformDefault,
            );
            _showAuthInstructions();
          } catch (e) {
            // Last resort: copy URL to clipboard and show instructions
            await _handleUrlLaunchFailure(authUrl);
          }
        }
      } else {
        throw Exception('Failed to get authorization URL');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to start Instagram connection: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAuthInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Instagram Authorization'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please complete the authorization in the opened browser:'),
            SizedBox(height: 12),
            Text('1. Login to your Instagram Business account'),
            Text('2. Grant permissions to SeaFrika'),
            Text('3. You will be redirected back automatically'),
            SizedBox(height: 12),
            Text('Come back to this screen after authorization.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkAuthorizationStatus();
            },
            child: const Text('I\'ve Completed Authorization'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUrlLaunchFailure(String authUrl) async {
    // Copy URL to clipboard as fallback
    try {
      await Clipboard.setData(ClipboardData(text: authUrl));

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Authorization Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'We couldn\'t open the Instagram authorization page automatically.'),
                const SizedBox(height: 12),
                const Text(
                    'The authorization URL has been copied to your clipboard.'),
                const SizedBox(height: 12),
                const Text('Please:'),
                const Text('1. Open your browser'),
                const Text('2. Paste the URL from clipboard'),
                const Text('3. Complete Instagram authorization'),
                const Text('4. Return to this app'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    authUrl,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _checkAuthorizationStatus();
                },
                child: const Text('I\'ve Completed Authorization'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // If clipboard also fails, show error
      setState(() {
        _error =
            'Could not launch Instagram authorization. Please try again or contact support.';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAuthorizationStatus() async {
    print('🔍 DEBUG: User tapped "I\'ve Completed Authorization"');
    setState(() {
      _isLoading = true;
    });

    // Wait a moment for the backend to process the authorization
    print('🔍 DEBUG: Waiting 2 seconds for backend processing...');
    await Future.delayed(const Duration(seconds: 2));

    // Check if integration was created and navigate to dashboard if successful
    await _checkAuthorizationAndNavigate();
  }

  Future<void> _checkAuthorizationAndNavigate() async {
    print('🔍 DEBUG: Starting authorization check...');

    final businessId = ref.read(selectedBusinessIdProvider);
    print('🔍 DEBUG: Business ID: $businessId');

    if (businessId == null) {
      print('❌ DEBUG: No business ID found');
      setState(() {
        _isLoading = false;
        _error = 'No business selected';
      });
      return;
    }

    try {
      final integrationService = ref.read(integrationServiceProvider);
      print(
          '🔍 DEBUG: Integration service: ${integrationService != null ? 'Available' : 'NULL'}');

      if (integrationService == null) {
        print('❌ DEBUG: Integration service is null');
        setState(() {
          _isLoading = false;
          _error = 'No business selected';
        });
        return;
      }

      // First check if integration already exists
      print('🔍 DEBUG: Fetching existing integrations...');
      final integrations = await integrationService.fetchIntegrations();
      print('🔍 DEBUG: Found ${integrations.length} existing integrations');

      final existingIntegration = integrations
          .where((integration) => integration.channel == 'instagram')
          .firstOrNull;

      print(
          '🔍 DEBUG: Existing Instagram integration: ${existingIntegration != null ? 'Found (${existingIntegration.status})' : 'Not found'}');

      if (existingIntegration != null &&
          (existingIntegration.status == 'active' ||
              existingIntegration.status == 'connected')) {
        print(
            '✅ DEBUG: Active/Connected integration found, navigating to dashboard...');
        // Integration already exists - navigate to dashboard
        await _navigateToInstagramDashboard(existingIntegration);
        return;
      }

      // Integration doesn't exist yet - try to create it by fetching profile from backend
      print(
          '🔍 DEBUG: No active integration found, attempting to create from backend...');
      await _createIntegrationFromBackend(integrationService, businessId);
    } catch (e) {
      print('❌ DEBUG: Error in authorization check: $e');
      setState(() {
        _error = 'Failed to check authorization status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createIntegrationFromBackend(
      integrationService, String businessId) async {
    print('🔍 DEBUG: Starting integration creation from backend...');
    print('🔍 DEBUG: Business ID for backend call: $businessId');

    try {
      // First, check if integration already exists
      final existingIntegrations = await integrationService.fetchIntegrations();
      Integration? instagramIntegration;

      try {
        instagramIntegration = existingIntegrations.firstWhere(
          (integration) => integration.channel == 'instagram',
        );
      } catch (e) {
        // No existing integration found
        instagramIntegration = null;
      }

      print(
          '🔍 DEBUG: Found ${existingIntegrations.length} existing integrations');
      if (instagramIntegration != null) {
        print(
            '✅ DEBUG: Found existing Instagram integration: ${instagramIntegration.id}');
        await _navigateToInstagramDashboard(instagramIntegration);
        return;
      } else {
        print('🔍 DEBUG: Existing Instagram integration: Not found');
        print(
            '🔍 DEBUG: No active integration found, attempting to create from backend...');
      }

      // The backend should have created the integration during OAuth callback
      // If we reach here, it means the OAuth was completed but integration wasn't created
      // This could be a timing issue or the OAuth didn't complete properly
      print('⚠️ DEBUG: OAuth completed but no integration found');
      print(
          '🔍 DEBUG: This could indicate a timing issue or incomplete OAuth flow');

      setState(() {
        _isLoading = false;
      });
      _showAuthorizationRetryDialog();
    } catch (e) {
      print('❌ DEBUG: Exception during integration creation: $e');
      print('❌ DEBUG: Exception type: ${e.runtimeType}');
      setState(() {
        _isLoading = false;
      });
      _showAuthorizationRetryDialog();
    }
  }

  Future<void> _navigateToInstagramDashboard(Integration integration) async {
    print('✅ DEBUG: Navigating to Instagram dashboard...');
    print('🔍 DEBUG: Integration ID: ${integration.id}');
    print('🔍 DEBUG: Integration status: ${integration.status}');
    print('🔍 DEBUG: Integration platform: ${integration.platformId}');

    setState(() {
      _currentIntegration = integration;
      _isLoading = false;
    });

    // Show success message
    if (mounted) {
      print('🔍 DEBUG: Showing success message...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instagram integration successful!'),
          backgroundColor: Colors.green,
        ),
      );

      // Wait a moment for user to see the success message
      await Future.delayed(const Duration(milliseconds: 1500));

      // Navigate to Instagram dashboard (analytics screen)
      if (mounted) {
        print('🔍 DEBUG: Navigating to InstagramAnalyticsScreen...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => InstagramAnalyticsScreen(
              integrationId: integration.id,
            ),
          ),
        );
        print('✅ DEBUG: Navigation completed successfully');
      } else {
        print('⚠️ DEBUG: Widget not mounted, skipping navigation');
      }
    } else {
      print('⚠️ DEBUG: Widget not mounted, skipping success message');
    }
  }

  void _showAuthorizationRetryDialog() {
    print('⚠️ DEBUG: Showing authorization retry dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Integration Processing'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('We\'re still processing your Instagram authorization.'),
            SizedBox(height: 12),
            Text(
                'This can take a few moments. Please try again or wait a bit longer.'),
            SizedBox(height: 12),
            Text(
                'Note: If you completed the Instagram authorization in your browser, the integration should be created soon.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('🔍 DEBUG: User chose to check again');
              Navigator.pop(context);
              _checkAuthorizationAndNavigate(); // Retry
            },
            child: const Text('Check Again'),
          ),
          TextButton(
            onPressed: () {
              print('🔍 DEBUG: User chose to wait');
              Navigator.pop(context);
            },
            child: const Text('Wait'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectInstagram() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Instagram'),
        content: const Text(
          'Are you sure you want to disconnect your Instagram Business account? '
          'This will stop syncing products and remove access to Instagram features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
        await integrationService.disconnectIntegration(_currentIntegration!.id);

        setState(() {
          _currentIntegration = null;
          _instagramProfile = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Instagram disconnected successfully')),
          );
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to disconnect Instagram: $e';
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(selectedBusinessIdProvider);

    // Show error if no business is selected
    if (businessId == null) {
      return Scaffold(
        appBar: IntegrationAppBar(
          title: 'Instagram Business',
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
                'Please select a business to configure Instagram integration',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'Instagram Business',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _error == 'token_expired'
                            ? 'Instagram integration has expired and needs to be reconnected'
                            : _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_error == 'token_expired') ...[
                            ElevatedButton(
                              onPressed: _handleReconnectInstagram,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE4405F),
                                foregroundColor: Colors.white,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.refresh, size: 16),
                                  SizedBox(width: 8),
                                  Text('Reconnect Instagram'),
                                ],
                              ),
                            ),
                          ] else if (_error!
                              .contains('Instagram account not connected')) ...[
                            ElevatedButton(
                              onPressed: _startInstagramConnection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF833AB4),
                                foregroundColor: Colors.white,
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt, size: 16),
                                  SizedBox(width: 8),
                                  Text('Connect Instagram'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ] else if (_error!.contains(
                              'No Instagram Business Account found')) ...[
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: Colors.blue.shade600,
                                          size: 24),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Instagram Business Account Required',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'To connect Instagram, you need:\n'
                                        '1. An Instagram Business or Creator account\n'
                                        '2. A Facebook page connected to your Instagram\n'
                                        '3. Admin access to the Facebook page',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _startInstagramConnection,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF833AB4),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh, size: 16),
                                      SizedBox(width: 8),
                                      Text('Try Again'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          ElevatedButton(
                            onPressed: _checkExistingIntegration,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_currentIntegration == null) {
      return _buildConnectionScreen();
    } else {
      return _buildConnectedScreen();
    }
  }

  Widget _buildConnectionScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instagram branding
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF833AB4),
                  Color(0xFFE1306C),
                  Color(0xFFFD1D1D)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 48,
                    color: Color(0xFF833AB4),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Instagram Business',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect your Instagram Business account to showcase your products',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Benefits section
          const Text(
            'What you can do with Instagram integration:',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildBenefitItem(
            Icons.inventory_2_outlined,
            'Sync Products',
            'Automatically sync your products to Instagram Shopping',
          ),
          _buildBenefitItem(
            Icons.analytics_outlined,
            'Track Performance',
            'Monitor engagement and reach of your Instagram posts',
          ),
          _buildBenefitItem(
            Icons.shopping_bag_outlined,
            'Direct Sales',
            'Enable customers to purchase directly from Instagram',
          ),
          _buildBenefitItem(
            Icons.notifications_outlined,
            'Real-time Updates',
            'Get notified of comments, messages, and mentions',
          ),

          const SizedBox(height: 32),

          // Connection options
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.blue.shade600, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Choose Your Connection Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Business Account Option
                _buildConnectionOption(
                  icon: Icons.business,
                  title: 'Instagram Business Account',
                  subtitle:
                      'Full features including analytics, content publishing, and comments management',
                  requirements: [
                    'Instagram Business/Creator account',
                    'Connected Facebook Page you manage',
                    'Advanced analytics and insights',
                  ],
                  buttonText: 'Connect Business Account',
                  buttonColor: const Color(0xFF833AB4),
                  onPressed: _startInstagramConnection,
                  recommended: true,
                ),

                const SizedBox(height: 20),

                // Personal Account Option
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Requirements info

          const SizedBox(height: 16),

          // Help section
          TextButton(
            onPressed: () {
              setState(() {
                _showConnectionSteps = !_showConnectionSteps;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Need help setting up?'),
                Icon(
                  _showConnectionSteps ? Icons.expand_less : Icons.expand_more,
                ),
              ],
            ),
          ),

          if (_showConnectionSteps) _buildSetupSteps(),
        ],
      ),
    );
  }

  Widget _buildConnectedScreen() {
    // Check if this is a Facebook fallback profile instead of a real Instagram account
    /*  if (_instagramProfile != null && _isFacebookFallbackProfile()) {
      return _buildFacebookFallbackScreen();
    } */
    debugPrint('[Instagram] Building connected screen _error: $_error');
    // If token expired, show not connected card instead
    if (_error == 'token_expired') {
      return _buildConnectionScreen();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection status
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
                  'Instagram Connected',
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

          const SizedBox(height: 24),

          // Instagram profile info
          if (_instagramProfile != null)
            _buildProfileInfo()
          else
            _buildReconnectProfileState(),

          const SizedBox(height: 24),

          // Integration settings
          _buildIntegrationSettings(),

          const SizedBox(height: 24),

          // Quick actions
          _buildQuickActions(),

          const SizedBox(height: 32),

          // Debug section (only in development)
          if (const bool.fromEnvironment('dart.vm.product') == false) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bug_report,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Debug Tools',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _fetchIntegrationLogs,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('View Integration Logs'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Disconnect button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _disconnectInstagram,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Disconnect Instagram',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacebookFallbackScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Instagram Business Account Required',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Facebook profile connected instead of Instagram',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Current profile info (Facebook fallback)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.facebook, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Currently Connected Facebook Profile',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage:
                          _instagramProfile!['profile_picture_url'] != null
                              ? NetworkImage(
                                  _instagramProfile!['profile_picture_url'])
                              : null,
                      backgroundColor: Colors.grey.shade300,
                      child: _instagramProfile!['profile_picture_url'] == null
                          ? Icon(Icons.person,
                              size: 20, color: Colors.grey.shade600)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _instagramProfile!['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '@${_instagramProfile!['username'] ?? 'unknown'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
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

          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'How to Connect Instagram Business',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInstructionStep(
                  '1',
                  'Convert to Business Account',
                  'Switch your Instagram account to a Business or Creator account in Instagram settings.',
                ),
                _buildInstructionStep(
                  '2',
                  'Connect to Facebook Page',
                  'Link your Instagram Business account to a Facebook page you manage.',
                ),
                _buildInstructionStep(
                  '3',
                  'Try Connection Again',
                  'Return here and attempt the connection process again.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _startInstagramConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF833AB4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Try Again',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _disconnectInstagram,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, size: 20),
                      SizedBox(width: 8),
                      Text('Disconnect',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(
      String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupSteps() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Setup Steps:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStepItem(1, 'Convert to Business Account',
              'Switch your Instagram to a Business account in settings'),
          _buildStepItem(2, 'Connect Facebook Page',
              'Link your Instagram to a Facebook Business Page'),
          _buildStepItem(3, 'Complete Business Information',
              'Add your contact details and business category'),
          _buildStepItem(4, 'Click Connect Above',
              'Use the connect button to authorize SeaFrika'),
        ],
      ),
    );
  }

  Widget _buildStepItem(int number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status and refresh
          Row(
            children: [
              Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Connected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _refreshInstagramMetrics,
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh Metrics',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Profile picture and basic info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundImage: _instagramProfile!['profile_picture_url'] !=
                          null
                      ? NetworkImage(_instagramProfile!['profile_picture_url'])
                      : null,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: _instagramProfile!['profile_picture_url'] == null
                      ? Icon(Icons.person, size: 24, color: AppTheme.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _instagramProfile!['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${_instagramProfile!['username'] ?? 'unknown'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Stats in a more compact grid layout
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                              Icons.people,
                              _instagramProfile!['followers_count'] != null
                                  ? _formatCount(int.tryParse(
                                          _instagramProfile!['followers_count']
                                              .toString()) ??
                                      0)
                                  : '--',
                              'Followers'),
                        ),
                        Expanded(
                          child: _buildStatItem(
                              Icons.person_add,
                              _instagramProfile!['follows_count'] != null
                                  ? _formatCount(int.tryParse(
                                          _instagramProfile!['follows_count']
                                              .toString()) ??
                                      0)
                                  : '--',
                              'Following'),
                        ),
                        Expanded(
                          child: _buildStatItem(
                              Icons.photo_library,
                              _instagramProfile!['media_count'] != null
                                  ? (int.tryParse(
                                              _instagramProfile!['media_count']
                                                  .toString()) ??
                                          0)
                                      .toString()
                                  : '--',
                              'Posts'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Biography if available
          if (_instagramProfile!['biography'] != null &&
              _instagramProfile!['biography'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
              ),
              child: Text(
                _instagramProfile!['biography'],
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Website link if available
          if (_instagramProfile!['website'] != null &&
              _instagramProfile!['website'].toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final url = _instagramProfile!['website'];
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.link,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _instagramProfile!['website'],
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_instagramProfile!['account_type'] != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    _instagramProfile!['account_type'] == 'BUSINESS'
                        ? Icons.business
                        : Icons.person_outline,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_instagramProfile!['account_type']} Account',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Features section
          if (_instagramProfile!['features'] != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, size: 18, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Available Features',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_instagramProfile!['features']['view_profile'] ==
                          true)
                        _buildFeatureChip(
                            'Profile Access', Icons.person, Colors.blue),
                      if (_instagramProfile!['features']['view_media'] == true)
                        _buildFeatureChip(
                            'Media Access', Icons.photo_library, Colors.purple),
                      if (_instagramProfile!['features']['basic_insights'] ==
                          true)
                        _buildFeatureChip(
                            'Basic Analytics', Icons.analytics, Colors.orange),
                      if (_instagramProfile!['features']['publish_content'] ==
                          true)
                        _buildFeatureChip(
                            'Content Publishing', Icons.publish, Colors.green),
                      if (_instagramProfile!['features']['manage_comments'] ==
                          true)
                        _buildFeatureChip(
                            'Comment Management', Icons.comment, Colors.indigo),
                      if (_instagramProfile!['features']
                              ['advanced_analytics'] ==
                          true)
                        _buildFeatureChip('Advanced Analytics',
                            Icons.trending_up, Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
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

  bool _isFacebookFallbackProfile() {
    if (_instagramProfile == null) return false;
    return _instagramProfile!['account_type'] == 'FACEBOOK_USER' ||
        _instagramProfile!['api_type'] == 'Facebook Graph API';
  }

  Widget _buildStatItem(IconData icon, String count, String label) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildReconnectProfileState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Instagram Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                Icons.warning_amber,
                color: Colors.orange.shade600,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.shade100,
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Icon(
                  Icons.link_off,
                  color: Colors.orange.shade600,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Required',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete Instagram authorization to view profile',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _startInstagramConnection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Complete Authorization',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sync Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () {
                  // Navigate to detailed settings
                  Navigator.pushNamed(
                    context,
                    '/integration-settings',
                    arguments: _currentIntegration,
                  );
                },
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSettingItem(
            'Auto-sync Products',
            _currentIntegration!.settings.syncProducts,
            Icons.inventory_2_outlined,
          ),
          _buildSettingItem(
            'Sync Interval',
            '${_currentIntegration!.settings.syncInterval} minutes',
            Icons.schedule,
          ),
          _buildSettingItem(
            'Last Sync',
            'Never', // You can implement last sync tracking
            Icons.sync,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, dynamic value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14),
          ),
          const Spacer(),
          Text(
            value is bool ? (value ? 'On' : 'Off') : value.toString(),
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Sync Now',
                Icons.sync,
                () => _performSync(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'View Posts',
                Icons.photo_library,
                () => _viewInstagramPosts(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Analytics',
                Icons.analytics,
                () => _viewAnalytics(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                'Settings',
                Icons.settings,
                () => _openSettings(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _performSync() async {
    setState(() => _isLoading = true);

    try {
      // Call sync endpoint
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync started successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _viewInstagramPosts() {
    Navigator.pushNamed(
      context,
      AppRoutes.instagramPosts,
      arguments: {'integrationId': _currentIntegration?.id},
    );
  }

  void _viewAnalytics() {
    Navigator.pushNamed(
      context,
      AppRoutes.instagramAnalytics,
      arguments: {'integrationId': _currentIntegration?.id},
    );
  }

  void _openSettings() {
    Navigator.pushNamed(
      context,
      AppRoutes.integrationSettings,
      arguments: {'integrationId': _currentIntegration?.id},
    );
  }

  Widget _buildConnectionOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> requirements,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onPressed,
    required bool recommended,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              recommended ? buttonColor.withOpacity(0.3) : Colors.grey.shade300,
          width: recommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: buttonColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: buttonColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...requirements
              .map((req) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            req,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTokenExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange[600]),
              const SizedBox(width: 8),
              const Expanded(child: Text('Instagram Token Expired')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Instagram integration has expired and needs to be reconnected.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                'This happens periodically for security reasons. You\'ll need to:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text('• Reconnect your Instagram Business account'),
              const Text('• Grant permissions again'),
              const Text('• Your settings and data will be preserved'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate back or show fallback data
                setState(() {
                  _error = null;
                });
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleReconnectInstagram();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE4405F),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reconnect Now'),
            ),
          ],
        );
      },
    );
  }

  void _handleReconnectInstagram() {
    // Navigate to Meta Integration screen using NavigationService
    NavigationService.navigateTo(AppRoutes.metaIntegration);
  }
}
