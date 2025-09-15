import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/theme/app_theme.dart';
import 'package:vendor_app/screens/integrations/whatsapp_dashboard_screen.dart';
import 'package:vendor_app/screens/integrations/whatsapp_enhanced_dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WhatsAppIntegrationScreen extends ConsumerStatefulWidget {
  const WhatsAppIntegrationScreen({super.key});

  @override
  ConsumerState<WhatsAppIntegrationScreen> createState() => _WhatsAppIntegrationScreenState();
}

class _WhatsAppIntegrationScreenState extends ConsumerState<WhatsAppIntegrationScreen> {
  bool _isLoading = false;
  String? _error;
  Integration? _currentIntegration;
  Map<String, dynamic>? _whatsappProfile;
  bool _showSetupSteps = false;

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
      final whatsappIntegration = integrations
          .where((integration) => integration.platformId == 'whatsapp')
          .firstOrNull;

      if (whatsappIntegration != null) {
        setState(() {
          _currentIntegration = whatsappIntegration;
        });
        await _loadWhatsAppProfile();
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

  Future<void> _loadWhatsAppProfile() async {
    if (_currentIntegration == null) return;
    
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/whatsapp/${_currentIntegration!.id}/business-profile'),
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
          _whatsappProfile = responseData;
        });
      } else {
        final errorBody = json.decode(response.body);
        setState(() {
          _whatsappProfile = null;
          _error = 'Failed to load WhatsApp profile: ${errorBody['message'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      debugPrint('Failed to load WhatsApp profile: $e');
      setState(() {
        _whatsappProfile = null;
      });
    }
  }

  Future<void> _startWhatsAppConnection() async {
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
      // For WhatsApp Business API, we need to show setup instructions
      // as it requires Meta Business verification and phone number verification
      _showWhatsAppSetupDialog();
    } catch (e) {
      setState(() {
        _error = 'Failed to start WhatsApp connection: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showWhatsAppSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('WhatsApp Business Setup'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WhatsApp Business API requires additional setup:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildSetupStep('1', 'Meta Business Account', 'Create a Meta Business account at business.facebook.com'),
              _buildSetupStep('2', 'Phone Number Verification', 'Add and verify your business phone number'),
              _buildSetupStep('3', 'WhatsApp Business Account', 'Create a WhatsApp Business account'),
              _buildSetupStep('4', 'API Access', 'Apply for WhatsApp Business API access'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Important Note',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'WhatsApp Business API requires business verification and approval. This process can take 1-2 weeks.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await launchUrl(Uri.parse('https://business.facebook.com/'));
            },
            child: const Text('Open Meta Business'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showManualSetupForm();
            },
            child: const Text('I Have API Access'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showManualSetupForm() {
    final phoneNumberIdController = TextEditingController();
    final accessTokenController = TextEditingController();
    final businessAccountIdController = TextEditingController();
    final appIdController = TextEditingController();
    final webhookTokenController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WhatsApp API Configuration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneNumberIdController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number ID',
                  hintText: 'From WhatsApp Business API dashboard',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: accessTokenController,
                decoration: const InputDecoration(
                  labelText: 'Access Token',
                  hintText: 'Permanent access token',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: businessAccountIdController,
                decoration: const InputDecoration(
                  labelText: 'Business Account ID',
                  hintText: 'WhatsApp Business Account ID',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: appIdController,
                decoration: const InputDecoration(
                  labelText: 'App ID',
                  hintText: 'Meta App ID',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: webhookTokenController,
                decoration: const InputDecoration(
                  labelText: 'Webhook Verify Token',
                  hintText: 'Custom verification token',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createWhatsAppIntegration({
                'phone_number_id': phoneNumberIdController.text,
                'access_token': accessTokenController.text,
                'business_account_id': businessAccountIdController.text,
                'app_id': appIdController.text,
                'webhook_verify_token': webhookTokenController.text,
              });
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _createWhatsAppIntegration(Map<String, String> credentials) async {
    setState(() => _isLoading = true);

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      final newIntegration = await integrationService.createWhatsAppIntegration(
        phoneNumberId: credentials['phone_number_id']!,
        accessToken: credentials['access_token']!,
        businessAccountId: credentials['business_account_id']!,
        appId: credentials['app_id']!,
        webhookVerifyToken: credentials['webhook_verify_token'],
      );

      setState(() {
        _currentIntegration = newIntegration;
      });

      await _loadWhatsAppProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WhatsApp integration successful!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to WhatsApp dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WhatsAppEnhancedDashboardScreen(
              integrationId: newIntegration.id,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to create WhatsApp integration: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _disconnectWhatsApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect WhatsApp'),
        content: const Text(
          'Are you sure you want to disconnect your WhatsApp Business account? '
          'This will stop message handling and remove access to WhatsApp features.',
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
          _whatsappProfile = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp disconnected successfully')),
          );
        }
      } catch (e) {
        setState(() {
          _error = 'Failed to disconnect WhatsApp: $e';
        });
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSetupStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    final businessId = ref.watch(selectedBusinessIdProvider);
    
    if (businessId == null) {
      return Scaffold(
        appBar: IntegrationAppBar(
          title: 'WhatsApp Business',
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
                'Please select a business to configure WhatsApp integration',
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
        title: 'WhatsApp Business',
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
                            onPressed: _startWhatsAppConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat, size: 16),
                                SizedBox(width: 8),
                                Text('Connect WhatsApp'),
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
          // WhatsApp branding
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
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
                    Icons.chat,
                    size: 48,
                    color: Color(0xFF25D366),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'WhatsApp Business',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect with customers through WhatsApp messaging',
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
            'What you can do with WhatsApp Business:',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildBenefitItem(
            Icons.message,
            'Customer Messaging',
            'Communicate directly with customers via WhatsApp',
          ),
          _buildBenefitItem(
            Icons.notifications_active,
            'Order Notifications',
            'Send order confirmations and updates automatically',
          ),
          _buildBenefitItem(
            Icons.support_agent,
            'Customer Support',
            'Provide instant customer support through WhatsApp',
          ),
          _buildBenefitItem(
            Icons.campaign,
            'Marketing Messages',
            'Send promotional messages and product updates',
          ),
          _buildBenefitItem(
            Icons.schedule,
            'Business Hours',
            'Set up auto-replies for outside business hours',
          ),

          const SizedBox(height: 32),

          // Connection button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startWhatsAppConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Connect WhatsApp Business',
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
                _showSetupSteps = !_showSetupSteps;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Need help with setup?'),
                Icon(
                  _showSetupSteps ? Icons.expand_less : Icons.expand_more,
                ),
              ],
            ),
          ),

          if (_showSetupSteps) _buildSetupInstructions(),
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
                  'WhatsApp Connected',
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

          // WhatsApp profile info
          if (_whatsappProfile != null) _buildProfileInfo(),

          const SizedBox(height: 24),

          // Quick actions
          _buildQuickActions(),

          const SizedBox(height: 32),

          // Disconnect button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _disconnectWhatsApp,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Disconnect WhatsApp',
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
              color: const Color(0xFF25D366).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF25D366),
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

  Widget _buildSetupInstructions() {
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
            'WhatsApp Business API Setup Requirements:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildSetupStep('1', 'Meta Business Account', 'Register at business.facebook.com'),
          _buildSetupStep('2', 'Business Verification', 'Complete business verification process'),
          _buildSetupStep('3', 'Phone Number', 'Add and verify business phone number'),
          _buildSetupStep('4', 'API Access', 'Apply for WhatsApp Business API'),
          _buildSetupStep('5', 'App Creation', 'Create Meta app with WhatsApp product'),
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
          Row(
            children: [
              Icon(Icons.business, color: Colors.grey[600]),
              const SizedBox(width: 8),
              const Text(
                'Business Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_whatsappProfile!['description'] != null) ...[
            Text(
              _whatsappProfile!['description'],
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
          ],
          if (_whatsappProfile!['email'] != null)
            _buildProfileField('Email', _whatsappProfile!['email']),
          if (_whatsappProfile!['address'] != null)
            _buildProfileField('Address', _whatsappProfile!['address']),
          if (_whatsappProfile!['vertical'] != null)
            _buildProfileField('Industry', _whatsappProfile!['vertical']),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(value),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Messages',
                'View conversations',
                Icons.message,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WhatsAppEnhancedDashboardScreen(
                        integrationId: _currentIntegration!.id,
                        initialTab: 1, // Conversations tab
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Templates',
                'Manage templates',
                Icons.description,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WhatsAppDashboardScreen(
                        integrationId: _currentIntegration!.id,
                        initialTab: 1,
                      ),
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
                'Analytics',
                'View insights',
                Icons.analytics,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WhatsAppDashboardScreen(
                        integrationId: _currentIntegration!.id,
                        initialTab: 2,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Settings',
                'Configure options',
                Icons.settings,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WhatsAppDashboardScreen(
                        integrationId: _currentIntegration!.id,
                        initialTab: 3,
                      ),
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
