import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/models/youtube_models.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/theme/app_theme.dart';
import 'package:vendor_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class YouTubeIntegrationScreen extends ConsumerStatefulWidget {
  final String? integrationId;

  const YouTubeIntegrationScreen({super.key, this.integrationId});

  @override
  ConsumerState<YouTubeIntegrationScreen> createState() =>
      _YouTubeIntegrationScreenState();
}

class _YouTubeIntegrationScreenState
    extends ConsumerState<YouTubeIntegrationScreen> {
  bool _isLoading = false;
  String? _error;
  Integration? _currentIntegration;
  YouTubeChannelInfo? _youTubeChannelInfo;
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

      Integration? youTubeIntegration;

      if (widget.integrationId != null) {
        // Load specific integration by ID
        final integrations = await integrationService.fetchIntegrations();
        youTubeIntegration =
            integrations.where((i) => i.id == widget.integrationId).firstOrNull;
      } else {
        // Find existing YouTube integration for this business
        final integrations = await integrationService.fetchIntegrations();
        youTubeIntegration = integrations
            .where(
                (i) => i.channel == 'youtube_channel' && i.status == 'active')
            .firstOrNull;
      }

      if (youTubeIntegration != null) {
        setState(() {
          _currentIntegration = youTubeIntegration;
          // Extract YouTube channel info from accountInfo
          if (youTubeIntegration?.accountInfo != null) {
            _youTubeChannelInfo =
                YouTubeChannelInfo.fromJson(youTubeIntegration!.accountInfo!);
          }
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _startYouTubeConnection() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId == null) {
      _showError('No business selected');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('Starting YouTube connection for businessId: $businessId');
      debugPrint(
          'Using Auth URL: ${ApiConfig.getYouTubeAuthUrl(businessId: businessId)}');
      // Get YouTube OAuth URL from backend
      final response = await http.get(
        Uri.parse(ApiConfig.getYouTubeAuthUrl(businessId: businessId)),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to get authorization URL: ${response.body}');
      }

      final data = json.decode(response.body);
      final authUrl = data['auth_url'];

      if (authUrl == null) {
        throw Exception('No authorization URL received');
      }

      // Open YouTube OAuth in browser
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: 'https',
        options: FlutterWebAuth2Options(
          timeout: 300, // 5 minutes in seconds
          windowName: 'YouTube OAuth',
        ),
      );

      // Parse result to check for success/error
      final uri = Uri.parse(result);
      final status = uri.queryParameters['status'];

      if (status == 'success') {
        // Show success message and refresh integration
        _showSuccess('YouTube channel connected successfully!');
        await _checkExistingIntegration();
      } else {
        final error = uri.queryParameters['error'] ?? 'Unknown error';
        throw Exception(Uri.decodeComponent(error));
      }
    } catch (error) {
      _showError('Failed to connect YouTube: ${error.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _error = message;
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showDisconnectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect YouTube?'),
        content: const Text(
          'Are you sure you want to disconnect your YouTube channel? You will lose access to video management and analytics features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _disconnectYouTube();
    }
  }

  Future<void> _disconnectYouTube() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    if (businessId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.put(
        Uri.parse(ApiConfig.getYouTubeIntegrationDisconnect()),
        headers: {
          'Business-ID': businessId,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentIntegration = null;
          _youTubeChannelInfo = null;
        });
        _showSuccess('YouTube channel disconnected successfully');
      } else {
        throw Exception('Failed to disconnect: ${response.body}');
      }
    } catch (error) {
      _showError('Failed to disconnect YouTube: ${error.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : Colors.grey[600],
              size: 20,
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
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Connect your YouTube Channel',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Link your YouTube channel to manage your videos, view analytics, and engage with your audience directly from Seafrika.',
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
                  'View and organize your YouTube content',
                ),
                const SizedBox(height: 16),
                _buildBenefit(
                  Icons.analytics,
                  'Track Performance',
                  'Monitor views, likes, and subscriber growth',
                ),
                const SizedBox(height: 16),
                _buildBenefit(
                  Icons.comment,
                  'Engage with Audience',
                  'Respond to comments and build community',
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _startYouTubeConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
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
                      'Connect YouTube Channel',
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

  Widget _buildConnectionSteps() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'How to Connect YouTube',
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
            'Tap "Connect YouTube Channel"',
            'This will open YouTube\'s authorization page in your browser.',
          ),
          const SizedBox(height: 12),
          _buildStep(
            2,
            'Sign in to YouTube',
            'Use your Google account credentials to sign in to YouTube.',
          ),
          const SizedBox(height: 12),
          _buildStep(
            3,
            'Authorize Access',
            'Grant Seafrika permission to access your YouTube channel and analytics.',
          ),
          const SizedBox(height: 12),
          _buildStep(
            4,
            'Return to App',
            'You\'ll be automatically redirected back to the app.',
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
                    'Make sure you\'re signed in to the correct Google account that owns your YouTube channel.',
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
          // YouTube Channel Card
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
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
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
                              _youTubeChannelInfo?.title ?? 'YouTube Channel',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _youTubeChannelInfo?.customUrl ??
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
                  if (_youTubeChannelInfo != null) ...[
                    Row(
                      children: [
                        _buildStatItem(
                          'Videos',
                          _youTubeChannelInfo!.formattedVideoCount,
                        ),
                        const SizedBox(width: 24),
                        _buildStatItem(
                          'Subscribers',
                          _youTubeChannelInfo!.formattedSubscriberCount,
                        ),
                        const SizedBox(width: 24),
                        _buildStatItem(
                          'Views',
                          _youTubeChannelInfo!.formattedViewCount,
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
                      // TODO: Navigate to YouTube analytics
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Analytics feature coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildActionButton(
                    icon: Icons.settings,
                    title: 'Integration Settings',
                    subtitle: 'Configure sync and notification preferences',
                    onTap: () {
                      // TODO: Navigate to settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings feature coming soon'),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  _buildActionButton(
                    icon: Icons.link_off,
                    title: 'Disconnect Channel',
                    subtitle: 'Remove YouTube integration',
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
                  _buildInfoRow('Platform', 'YouTube'),
                  _buildInfoRow('Status', 'Active'),
                  _buildInfoRow(
                    'Connected',
                    () {
                      final createdAt =
                          _currentIntegration?.createdAt.toString();
                      if (createdAt != null && createdAt.isNotEmpty) {
                        final parts = createdAt.split(' ');
                        return parts.isNotEmpty ? parts[0] : 'N/A';
                      }
                      return 'N/A';
                    }(),
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

  Widget _buildBenefit(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const IntegrationAppBar(
        title: 'YouTube Integration',
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
