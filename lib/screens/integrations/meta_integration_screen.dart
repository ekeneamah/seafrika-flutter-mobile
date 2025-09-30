import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:vendor_app/services/meta_integration_service.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/utils/business_preferences_helper.dart';

class MetaIntegrationScreen extends ConsumerStatefulWidget {
  const MetaIntegrationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MetaIntegrationScreen> createState() =>
      _MetaIntegrationScreenState();
}

class _MetaIntegrationScreenState extends ConsumerState<MetaIntegrationScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  MetaOAuthUrlResponse? _lastResponse;
  bool _hasCheckedBusiness = false;

  @override
  void initState() {
    super.initState();
    // Check business selection after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBusinessSelection();
    });
  }

  /// Check if a business is selected and show dialog if not
  Future<void> _checkBusinessSelection() async {
    if (_hasCheckedBusiness) return;
    _hasCheckedBusiness = true;

    final hasSelectedBusiness =
        await BusinessPreferencesHelper.hasSelectedBusiness();

    if (!hasSelectedBusiness && mounted) {
      _showBusinessSelectionDialog();
    }
  }

  /// Show dialog prompting user to select a business
  void _showBusinessSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Business'),
          content: const Text(
              'You need to select a business before setting up Meta integrations. '
              'Would you like to go to the business selection screen?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context)
                    .pushNamed(AppRoutes.businessList)
                    .then((_) {
                  // Recheck business selection when returning
                  _hasCheckedBusiness = false;
                  _checkBusinessSelection();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Select Business'),
            ),
          ],
        );
      },
    );
  }

  /// Launch OAuth flow for selected channels
  Future<void> _launchOAuth(List<String> channels) async {
    // Check business selection first
    final hasSelectedBusiness =
        await BusinessPreferencesHelper.hasSelectedBusiness();
    if (!hasSelectedBusiness) {
      _showBusinessSelectionDialog();
      return;
    }

    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId == null) {
      setState(() {
        _errorMessage = 'No business selected. Please select a business first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await MetaIntegrationService.generateOAuthUrl(
        channels: channels,
        businessId: businessId,
        state: '${businessId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      debugPrint('Received OAuth URL response: ${response.toString()}');

      setState(() {
        _lastResponse = response;
      });

      debugPrint('Starting Meta OAuth flow with URL: ${response.authUrl}');

      try {
        // Use flutter_web_auth_2 for modern OAuth flow with HTTPS redirects
        final result = await FlutterWebAuth2.authenticate(
          url: response.authUrl,
          callbackUrlScheme: 'https',
          options: const FlutterWebAuth2Options(
            timeout: 120000, // 2 minutes timeout
            preferEphemeral: false,
          ),
        );

        debugPrint('Meta OAuth result received: $result');

        // Parse the callback URL to check for success/error
        final uri = Uri.parse(result);
        final status = uri.queryParameters['status'];
        final message = uri.queryParameters['message'];
        final error = uri.queryParameters['error'];

        if (status == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(message ?? 'Meta platforms connected successfully!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            // Navigate back to integrations list
            Navigator.of(context).pop();
          }
        } else {
          // Handle error case
          final errorMessage = error ?? message ?? 'Authentication failed';
          setState(() {
            _errorMessage = 'Meta OAuth failed: $errorMessage';
          });
        }
      } on Exception catch (e) {
        debugPrint('Meta OAuth authentication failed: $e');

        // Check if it's a user cancellation
        if (e.toString().contains('CANCELED') ||
            e.toString().contains('User closed')) {
          debugPrint('User cancelled Meta OAuth');
          // Don't show error for user cancellation
        } else {
          setState(() {
            _errorMessage = 'Meta authentication failed. Please try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('Error in Meta OAuth flow: $e');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(selectedBusinessIdProvider);

    // Show loading or main content if business is selected
    if (businessId != null) {
      return _buildMainContent(businessId);
    }

    // Show placeholder while checking business selection
    return Scaffold(
      appBar: const IntegrationAppBar(
        title: 'Meta Integration',
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildMainContent(String businessId) {
    return Scaffold(
      appBar: const IntegrationAppBar(
        title: 'Meta Integration',
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.secondary],
                        ),
                      ),
                      child: const Icon(
                        Icons.share,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connect Meta Platforms',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Integrate Facebook Pages, Messenger, and Instagram Business for unified social media management',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
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

          // Content Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Integration options
                  _buildIntegrationCard(
                    title: 'Facebook Pages',
                    description:
                        'Manage your Facebook business pages, posts, and engagement',
                    icon: Icons.facebook,
                    color: const Color(0xFF1877F2),
                    channels: ['facebook_pages'],
                    capabilities: MetaIntegrationCapabilities
                            .getChannelCapabilities()['facebook_pages'] ??
                        [],
                  ),

                  const SizedBox(height: 16),

                  _buildIntegrationCard(
                    title: 'Messenger',
                    description:
                        'Handle customer messages and automated responses',
                    icon: Icons.message,
                    color: const Color(0xFF0084FF),
                    channels: ['messenger'],
                    capabilities: MetaIntegrationCapabilities
                            .getChannelCapabilities()['messenger'] ??
                        [],
                  ),

                  const SizedBox(height: 16),

                  _buildIntegrationCard(
                    title: 'Instagram Business',
                    description: 'Manage Instagram content, comments, and DMs',
                    icon: Icons.camera_alt,
                    color: const Color(0xFFE4405F),
                    channels: ['instagram'],
                    capabilities: MetaIntegrationCapabilities
                            .getChannelCapabilities()['instagram'] ??
                        [],
                  ),

                  const SizedBox(height: 24),

                  // All platforms option
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.group_work,
                              color: Colors.white,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Connect All Platforms',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Integrate Facebook Pages, Messenger, and Instagram in one seamless flow',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _launchOAuth([
                                          'facebook_pages',
                                          'messenger',
                                          'instagram'
                                        ]),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.all(16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Text(
                                        'Connect All Platforms',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Loading indicator
                  if (_isLoading)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Generating OAuth URL...',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                  // Error display
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Error:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),

                  // Last response info
                  if (_lastResponse != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'OAuth URL Generated:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                              'Channels: ${_lastResponse!.channelDescriptions}'),
                          Text('App ID: ${_lastResponse!.appId}'),
                          if (_lastResponse!.state != null)
                            Text('State: ${_lastResponse!.state}'),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Help Section
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
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Setup Information',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'After clicking connect, you\'ll be redirected to Facebook to authorize access. Make sure you:',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...[
                          '• Grant access to your Facebook Pages',
                          '• Ensure pages are connected to Instagram Business accounts',
                          '• Complete the authorization process',
                          '• Return to this app to see your connected platforms'
                        ].map((tip) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                tip,
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> channels,
    required List<String> capabilities,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                    border: Border.all(color: color.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
            const SizedBox(height: 12),

            // Capabilities
            Text(
              'Capabilities:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            ...capabilities.map(
              (capability) => Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.check, color: color, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        capability,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _launchOAuth(channels),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Connect $title',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
