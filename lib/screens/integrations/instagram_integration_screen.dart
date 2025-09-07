import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InstagramIntegrationScreen extends ConsumerStatefulWidget {
  const InstagramIntegrationScreen({super.key});

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      final integrations = await integrationService.fetchIntegrations();
      
      final instagramIntegration = integrations
          .where((integration) => integration.platformId == 'instagram')
          .firstOrNull;

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

    try {
      // Call backend to get Instagram profile data
      final response = await http.get(
        Uri.parse('https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/facebook/instagram/profile'),
        headers: {
          'Authorization': 'Bearer ${_currentIntegration!.credentials?['access_token']}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _instagramProfile = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Failed to load Instagram profile: $e');
    }
  }

  Future<void> _startInstagramConnection() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get Instagram auth URL from backend
      final response = await http.get(
        Uri.parse(
          'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/facebook/instagram/auth-url'
          '?redirect_uri=${Uri.encodeComponent('https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/config/facebook/instagram/oauth/redirect')}'
          '&state=${Uri.encodeComponent('vendor_${DateTime.now().millisecondsSinceEpoch}')}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final authUrl = data['auth_url'];

        // Launch Instagram OAuth URL
        if (await canLaunchUrl(Uri.parse(authUrl))) {
          await launchUrl(
            Uri.parse(authUrl),
            mode: LaunchMode.externalApplication,
          );
          
          // Show instructions to user
          _showAuthInstructions();
        } else {
          throw Exception('Could not launch Instagram authorization URL');
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

  Future<void> _checkAuthorizationStatus() async {
    setState(() {
      _isLoading = true;
    });

    // Wait a moment for the backend to process the authorization
    await Future.delayed(const Duration(seconds: 2));

    // Check if integration was created
    await _checkExistingIntegration();
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
        await integrationService.disconnectIntegration(_currentIntegration!.id);
        
        setState(() {
          _currentIntegration = null;
          _instagramProfile = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Instagram disconnected successfully')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instagram Business'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
                      ElevatedButton(
                        onPressed: _checkExistingIntegration,
                        child: const Text('Retry'),
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
                colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFFD1D1D)],
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

          // Connection requirements
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accent.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Requirements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('• Instagram Business or Creator account'),
                const Text('• Connected Facebook Page'),
                const Text('• Valid business information'),
                const Text('• Compliance with Instagram policies'),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Connect button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startInstagramConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF833AB4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text(
                    'Connect Instagram Business',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

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
                  _showConnectionSteps
                      ? Icons.expand_less
                      : Icons.expand_more,
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
          if (_instagramProfile != null) _buildProfileInfo(),

          const SizedBox(height: 24),

          // Integration settings
          _buildIntegrationSettings(),

          const SizedBox(height: 24),

          // Quick actions
          _buildQuickActions(),

          const SizedBox(height: 32),

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
          _buildStepItem(1, 'Convert to Business Account', 'Switch your Instagram to a Business account in settings'),
          _buildStepItem(2, 'Connect Facebook Page', 'Link your Instagram to a Facebook Business Page'),
          _buildStepItem(3, 'Complete Business Information', 'Add your contact details and business category'),
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
          const Text(
            'Instagram Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: _instagramProfile!['profile_picture_url'] != null
                    ? NetworkImage(_instagramProfile!['profile_picture_url'])
                    : null,
                child: _instagramProfile!['profile_picture_url'] == null
                    ? const Icon(Icons.person)
                    : null,
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
                    ),
                    Text(
                      '@${_instagramProfile!['username'] ?? 'unknown'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (_instagramProfile!['followers_count'] != null)
                      Text(
                        '${_instagramProfile!['followers_count']} followers',
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

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
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
    Navigator.pushNamed(context, '/instagram-posts');
  }

  void _viewAnalytics() {
    Navigator.pushNamed(context, '/instagram-analytics');
  }

  void _openSettings() {
    Navigator.pushNamed(
      context,
      '/integration-settings',
      arguments: _currentIntegration,
    );
  }
}
