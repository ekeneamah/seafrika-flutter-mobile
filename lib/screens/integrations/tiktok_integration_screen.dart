import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/models/tiktok_models.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/providers/tiktok_providers.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/services/tiktok_service.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TikTokIntegrationScreen extends ConsumerStatefulWidget {
  final String? integrationId;

  const TikTokIntegrationScreen({super.key, this.integrationId});

  @override
  ConsumerState<TikTokIntegrationScreen> createState() =>
      _TikTokIntegrationScreenState();
}

class _TikTokIntegrationScreenState
    extends ConsumerState<TikTokIntegrationScreen> {
  bool _isLoading = false;
  String? _error;
  Integration? _currentIntegration;
  Map<String, dynamic>? _tikTokProfile;
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

      Integration? tikTokIntegration;

      if (widget.integrationId != null) {
        // Load specific integration by ID
        tikTokIntegration =
            await integrationService.fetchIntegration(widget.integrationId!);
      } else {
        // Load first TikTok integration for this business
        final integrations = await integrationService.fetchIntegrations();
        tikTokIntegration = integrations
            .where((integration) => integration.channel == 'tiktok')
            .firstOrNull;
      }

      if (tikTokIntegration != null) {
        setState(() {
          _currentIntegration = tikTokIntegration;
        });
        await _loadTikTokProfile();
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

  Future<void> _loadTikTokProfile() async {
    if (_currentIntegration == null) return;

    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/v1/config/tiktok/${_currentIntegration!.id}/profile-info'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _tikTokProfile = responseData;
        });
      } else {
        final errorBody = json.decode(response.body);
        setState(() {
          _tikTokProfile = null;
          _error =
              'Failed to load TikTok profile: ${errorBody['message'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      debugPrint('Failed to load TikTok profile: $e');
      setState(() {
        _tikTokProfile = null;
      });
    }
  }

  Future<void> _startTikTokConnection() async {
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
      // Get TikTok auth URL from backend
      final authService = ref.read(authServiceProvider);
      final response = await http.get(
        Uri.parse(
          'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/tiktok/auth-url'
          '?redirect_uri=${Uri.encodeComponent('https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/tiktok/oauth/redirect')}'
          '&state=${Uri.encodeComponent('vendor_${DateTime.now().millisecondsSinceEpoch}')}',
        ),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );
      debugPrint(
          '🔍 TikTokIntegrationScreen._startTikTokConnection RAW Backend Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final authUrl = responseData['authUrl'] as String;

        debugPrint('TikTok Auth URL: $authUrl');

        // Launch the URL in the browser
        final Uri url = Uri.parse(authUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
          );
          _showReturnDialog();
        } else {
          setState(() {
            _error = 'Could not launch TikTok authorization URL';
            _isLoading = false;
          });
        }
      } else {
        final errorBody = json.decode(response.body);
        setState(() {
          _error =
              'Failed to get TikTok auth URL: ${errorBody['message'] ?? 'Unknown error'}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to start TikTok connection: $e';
        _isLoading = false;
      });
    }
  }

  void _showReturnDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Complete TikTok Authorization'),
          content: const Text(
            'You\'ve been redirected to TikTok to authorize access. '
            'Please complete the authorization process in your browser, '
            'then return here and tap "I\'ve Completed Authorization" to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isLoading = false;
                });
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkForNewIntegration();
              },
              child: const Text('I\'ve Completed Authorization'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkForNewIntegration() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Wait a moment for the backend to process
      await Future.delayed(const Duration(seconds: 2));

      // Refresh integration list
      await _checkExistingIntegration();
    } catch (e) {
      setState(() {
        _error = 'Failed to check for new integration: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnectTikTok() async {
    if (_currentIntegration == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) return;

      await integrationService.deleteIntegration(_currentIntegration!.id);

      setState(() {
        _currentIntegration = null;
        _tikTokProfile = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TikTok account disconnected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to disconnect TikTok: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disconnect TikTok'),
          content: const Text(
            'Are you sure you want to disconnect your TikTok account? '
            'This will remove access to your TikTok videos and analytics.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _disconnectTikTok();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectionSteps() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'How to Connect TikTok',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showConnectionSteps = false;
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStep(
              1,
              'Tap "Connect TikTok Account"',
              'This will open TikTok\'s authorization page in your browser.',
            ),
            const SizedBox(height: 12),
            _buildStep(
              2,
              'Sign in to TikTok',
              'Use your TikTok Business account credentials to sign in.',
            ),
            const SizedBox(height: 12),
            _buildStep(
              3,
              'Authorize Access',
              'Grant Seafrika permission to access your TikTok videos and analytics.',
            ),
            const SizedBox(height: 12),
            _buildStep(
              4,
              'Return to App',
              'Come back to this screen and tap "I\'ve Completed Authorization".',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Make sure you\'re using a TikTok Business account with video publishing permissions.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
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
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TikTok Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tikTokProfile?['username'] ?? 'TikTok Business',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _tikTokProfile?['display_name'] ??
                                  'Connected Account',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Connected',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_tikTokProfile != null) ...[
                    Row(
                      children: [
                        _buildStatItem(
                          'Videos',
                          (_tikTokProfile!['video_count'] ?? 0).toString(),
                        ),
                        const SizedBox(width: 24),
                        _buildStatItem(
                          'Followers',
                          _formatNumber(_tikTokProfile!['follower_count'] ?? 0),
                        ),
                        const SizedBox(width: 24),
                        _buildStatItem(
                          'Likes',
                          _formatNumber(_tikTokProfile!['likes_count'] ?? 0),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.video_library,
                    title: 'Sync Videos',
                    subtitle: 'Update your video library',
                    onTap: () {
                      // TODO: Implement video sync
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Video sync feature coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildActionButton(
                    icon: Icons.analytics,
                    title: 'View Analytics',
                    subtitle: 'Check your performance metrics',
                    onTap: () {
                      // TODO: Navigate to TikTok analytics
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Analytics feature coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildActionButton(
                    icon: Icons.link_off,
                    title: 'Disconnect Account',
                    subtitle: 'Remove TikTok integration',
                    onTap: _showDisconnectDialog,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Integration Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Integration Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Platform', 'TikTok Business'),
                  _buildInfoRow('Status', 'Active'),
                  _buildInfoRow(
                    'Connected',
                    _currentIntegration?.createdAt.toString().split(' ')[0] ??
                        'N/A',
                  ),
                  _buildInfoRow(
                    'Integration ID',
                    _currentIntegration?.id ?? 'N/A',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? Colors.red : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.music_note,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connect your TikTok Business Account',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Link your TikTok Business account to manage your videos, view analytics, and engage with your audience directly from Seafrika.',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Benefits
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildBenefit(
                  Icons.video_library,
                  'Manage Videos',
                  'View and organize your TikTok content',
                ),
                const SizedBox(height: 16),
                _buildBenefit(
                  Icons.analytics,
                  'Track Performance',
                  'Monitor views, likes, and engagement',
                ),
                const SizedBox(height: 16),
                _buildBenefit(
                  Icons.comment,
                  'Engage with Audience',
                  'Respond to comments and messages',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startTikTokConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Connect TikTok Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () {
              setState(() {
                _showConnectionSteps = !_showConnectionSteps;
              });
            },
            child: const Text('How does this work?'),
          ),

          if (_showConnectionSteps) _buildConnectionSteps(),
        ],
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
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
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IntegrationAppBar(
        title: 'TikTok Integration',
      ),
      body: _isLoading && _currentIntegration == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _error = null;
                            });
                            _checkExistingIntegration();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _currentIntegration != null
                  ? _buildConnectedState()
                  : _buildDisconnectedState(),
    );
  }
}
