import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/models/facebook_models.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/providers/facebook_providers.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/services/facebook_service.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/theme/app_theme.dart';
import 'package:vendor_app/screens/integrations/facebook_enhanced_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacebookIntegrationScreen extends ConsumerStatefulWidget {
  const FacebookIntegrationScreen({super.key});

  @override
  ConsumerState<FacebookIntegrationScreen> createState() => _FacebookIntegrationScreenState();
}

class _FacebookIntegrationScreenState extends ConsumerState<FacebookIntegrationScreen> {
  bool _isLoading = false;
  String? _error;
  Integration? _currentIntegration;
  Map<String, dynamic>? _facebookPage;
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

      final integrations = await integrationService.fetchIntegrations();
      final facebookIntegration = integrations
          .where((integration) => integration.platformId == 'facebook')
          .firstOrNull;

      if (facebookIntegration != null) {
        setState(() {
          _currentIntegration = facebookIntegration;
        });
        await _loadFacebookPage();
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

  Future<void> _loadFacebookPage() async {
    if (_currentIntegration == null) return;
    
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/facebook/${_currentIntegration!.id}/page-info'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization': 'Bearer ${authService.currentUser?.accessToken ?? ''}',
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
          _error = 'Failed to load Facebook page: ${errorBody['message'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      debugPrint('Failed to load Facebook page: $e');
      setState(() {
        _facebookPage = null;
      });
    }
  }

  Future<void> _startFacebookConnection() async {
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
      // Get Facebook auth URL from backend
      final authService = ref.read(authServiceProvider);
      final response = await http.get(
        Uri.parse(
          'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/facebook/auth-url'
          '?redirect_uri=${Uri.encodeComponent('https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/facebook/oauth/redirect')}'
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

        // Launch Facebook OAuth URL
        try {
          final uri = Uri.parse(authUrl);
          
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
          } else {
            await launchUrl(
              uri,
              mode: LaunchMode.inAppWebView,
            );
          }
          
          _showAuthInstructions();
        } catch (launchError) {
          try {
            await launchUrl(
              Uri.parse(authUrl),
              mode: LaunchMode.platformDefault,
            );
            _showAuthInstructions();
          } catch (e) {
            await _handleUrlLaunchFailure(authUrl);
          }
        }
      } else {
        throw Exception('Failed to get authorization URL');
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to start Facebook connection: $e';
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
        title: const Text('Facebook Authorization'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please complete the authorization in the opened browser:'),
            SizedBox(height: 12),
            Text('1. Login to your Facebook account'),
            Text('2. Select the Facebook page to connect'),
            Text('3. Grant permissions to SeaFrika'),
            Text('4. You will be redirected back automatically'),
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
                const Text('We couldn\'t open the Facebook authorization page automatically.'),
                const SizedBox(height: 12),
                const Text('The authorization URL has been copied to your clipboard.'),
                const SizedBox(height: 12),
                const Text('Please:'),
                const Text('1. Open your browser'),
                const Text('2. Paste the URL from clipboard'),
                const Text('3. Complete Facebook authorization'),
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
      setState(() {
        _error = 'Could not launch Facebook authorization. Please try again or contact support.';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAuthorizationStatus() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 2));
    await _checkAuthorizationAndNavigate();
  }

  Future<void> _checkAuthorizationAndNavigate() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    
    if (businessId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No business selected';
      });
      return;
    }

    try {
      final integrationService = ref.read(integrationServiceProvider);
      
      if (integrationService == null) {
        setState(() {
          _isLoading = false;
          _error = 'No business selected';
        });
        return;
      }

      // Check if integration already exists
      final integrations = await integrationService.fetchIntegrations();
      final existingIntegration = integrations
          .where((integration) => integration.platformId == 'facebook')
          .firstOrNull;

      if (existingIntegration != null && (existingIntegration.status == 'active' || existingIntegration.status == 'connected')) {
        await _navigateToFacebookDashboard(existingIntegration);
        return;
      }

      // Try to create integration from backend
      await _createIntegrationFromBackend(integrationService, businessId);

    } catch (e) {
      setState(() {
        _error = 'Failed to check authorization status: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createIntegrationFromBackend(integrationService, String businessId) async {
    try {
      // Try to fetch page from backend (indicates successful OAuth)
      final pageUrl = 'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/facebook/page-info';
      final authService = ref.read(authServiceProvider);
      
      final response = await http.get(
        Uri.parse(pageUrl),
        headers: {
          'Content-Type': 'application/json',
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
        },
      );

      if (response.statusCode == 200) {
        final pageData = json.decode(response.body);
        
        // Create the integration using the service
        final newIntegration = await integrationService.createFacebookIntegration(
          pageId: pageData['id'],
          pageAccessToken: pageData['access_token'],
          accessToken: pageData['user_access_token'] ?? pageData['access_token'],
          userId: pageData['user_id'] ?? 'unknown',
          pageData: pageData,
        );

        // Success! Navigate to dashboard
        await _navigateToFacebookDashboard(newIntegration);

      } else {
        setState(() {
          _isLoading = false;
        });
        _showAuthorizationRetryDialog();
      }
    } catch (e) {
      setState(() {
        _isLoading = false,
      });
      _showAuthorizationRetryDialog();
    }
  }

  Future<void> _navigateToFacebookDashboard(Integration integration) async {
    setState(() {
      _currentIntegration = integration;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Facebook integration successful!'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const FacebookEnhancedDashboardScreen(),
          ),
        );
      }
    }
  }

  void _showAuthorizationRetryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Integration Processing'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('We\'re still processing your Facebook authorization.'),
            SizedBox(height: 12),
            Text('This can take a few moments. Please try again or wait a bit longer.'),
            SizedBox(height: 12),
            Text('Note: If you completed the Facebook authorization in your browser, the integration should be created soon.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkAuthorizationAndNavigate();
            },
            child: const Text('Check Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Wait'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectFacebook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Facebook'),
        content: const Text(
          'Are you sure you want to disconnect your Facebook page? '
          'This will stop syncing posts and remove access to Facebook features.',
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
          _facebookPage = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Facebook disconnected successfully')),
          );
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to disconnect Facebook: $e';
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(selectedBusinessIdProvider);
    
    if (businessId == null) {
      return Scaffold(
        appBar: IntegrationAppBar(
          title: 'Facebook Page',
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
                'Please select a business to configure Facebook integration',
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
        title: 'Facebook Page',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _startFacebookConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1877F2),
                              foregroundColor: Colors.white,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.facebook, size: 16),
                                SizedBox(width: 8),
                                Text('Connect Facebook'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Facebook branding
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1877F2),
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
                    Icons.facebook,
                    size: 48,
                    color: Color(0xFF1877F2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Facebook Page',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect your Facebook business page to engage with customers',
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
            'What you can do with Facebook Page integration:',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildBenefitItem(
            Icons.post_add,
            'Manage Posts',
            'Create, edit, and schedule posts directly from your dashboard',
          ),
          _buildBenefitItem(
            Icons.comment,
            'Handle Comments',
            'Respond to comments and moderate discussions',
          ),
          _buildBenefitItem(
            Icons.analytics,
            'View Analytics',
            'Track page performance, reach, and engagement metrics',
          ),
          _buildBenefitItem(
            Icons.message,
            'Page Messages',
            'Manage direct messages from customers',
          ),
          _buildBenefitItem(
            Icons.notifications,
            'Real-time Updates',
            'Get notified of new comments, messages, and interactions',
          ),

          const SizedBox(height: 32),

          // Connection button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startFacebookConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.facebook, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Connect Facebook Page',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Setup info
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
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
                  'Facebook Connected',
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

          // Facebook page info
          if (_facebookPage != null) _buildPageInfo(),

          const SizedBox(height: 24),

          // Quick actions
          _buildQuickActions(),

          const SizedBox(height: 32),

          // Disconnect button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _disconnectFacebook,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Disconnect Facebook',
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

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1877F2).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1877F2),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
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
          _buildStepItem(1, 'Facebook Business Page', 'Create a Facebook business page if you don\'t have one'),
          _buildStepItem(2, 'Admin Access', 'Ensure you have admin access to the Facebook page'),
          _buildStepItem(3, 'Page Information', 'Complete your page with business details and contact info'),
          _buildStepItem(4, 'Click Connect Above', 'Use the connect button to authorize SeaFrika'),
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
              color: const Color(0xFF1877F2),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageInfo() {
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
            children: [
              if (_facebookPage!['picture'] != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _facebookPage!['picture']['data']['url'],
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _facebookPage!['name'] ?? 'Unknown Page',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_facebookPage!['category'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _facebookPage!['category'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_facebookPage!['is_verified'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Verified',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          if (_facebookPage!['about'] != null || _facebookPage!['description'] != null) ...[
            const SizedBox(height: 16),
            Text(
              _facebookPage!['about'] ?? _facebookPage!['description'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              if (_facebookPage!['fan_count'] != null) ...[
                _buildStatChip('Fans', _formatCount(_facebookPage!['fan_count'])),
                const SizedBox(width: 8),
              ],
              if (_facebookPage!['followers_count'] != null) ...[
                _buildStatChip('Followers', _formatCount(_facebookPage!['followers_count'])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1877F2).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$value $label',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1877F2),
        ),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Posts',
                'Manage posts',
                Icons.post_add,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FacebookEnhancedDashboardScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Comments',
                'Handle comments',
                Icons.comment,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FacebookEnhancedDashboardScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Messages',
                'Page messages',
                Icons.message,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FacebookEnhancedDashboardScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Analytics',
                'View insights',
                Icons.analytics,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FacebookEnhancedDashboardScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
