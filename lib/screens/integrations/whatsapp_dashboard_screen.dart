import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WhatsAppDashboardScreen extends ConsumerStatefulWidget {
  final String integrationId;
  final int initialTab;

  const WhatsAppDashboardScreen({
    super.key,
    required this.integrationId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<WhatsAppDashboardScreen> createState() =>
      _WhatsAppDashboardScreenState();
}

class _WhatsAppDashboardScreenState
    extends ConsumerState<WhatsAppDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;
  Integration? _integration;
  Map<String, dynamic>? _businessProfile;
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _templates = [];
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadIntegration(),
        _loadBusinessProfile(),
        _loadMessages(),
        _loadTemplates(),
        _loadAnalytics(),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadIntegration() async {
    final integrationService = ref.read(integrationServiceProvider);
    if (integrationService == null) {
      throw Exception('No business selected');
    }

    final integrations = await integrationService.fetchIntegrations();
    final integration =
        integrations.where((i) => i.id == widget.integrationId).firstOrNull;

    if (integration == null) {
      throw Exception('Integration not found');
    }

    setState(() {
      _integration = integration;
    });
  }

  Future<void> _loadBusinessProfile() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/whatsapp/${widget.integrationId}/business-profile'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _businessProfile = data;
        });
      }
    } catch (e) {
      debugPrint('Failed to load business profile: $e');
    }
  }

  Future<void> _loadMessages() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/whatsapp/${widget.integrationId}/messages'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Failed to load messages: $e');
    }
  }

  Future<void> _loadTemplates() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/whatsapp/${widget.integrationId}/templates'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _templates = List<Map<String, dynamic>>.from(data['templates'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Failed to load templates: $e');
    }
  }

  Future<void> _loadAnalytics() async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/whatsapp/${widget.integrationId}/analytics'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _analytics = data;
        });
      }
    } catch (e) {
      debugPrint('Failed to load analytics: $e');
    }
  }

  Future<void> _sendMessage(String to, String message,
      {String? templateName}) async {
    final businessId = ref.read(selectedBusinessIdProvider);
    final authService = ref.read(authServiceProvider);
    if (businessId == null) return;

    setState(() => _isLoading = true);

    try {
      final payload = <String, dynamic>{
        'to': to,
        'type': templateName != null ? 'template' : 'text',
      };

      if (templateName != null) {
        payload['template'] = {
          'name': templateName,
          'language': {'code': 'en'},
        };
      } else {
        payload['text'] = {'body': message};
      }

      final response = await http.post(
        Uri.parse(
            'https://seafrikaapi-u53tcgosiq-uc.a.run.app/api/integrations/whatsapp/${widget.integrationId}/send-message'),
        headers: {
          'Business-ID': businessId,
          'User-ID': authService.currentUser?.id ?? '',
          'Authorization':
              'Bearer ${authService.currentUser?.accessToken ?? ''}',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadMessages();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'WhatsApp Business',
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Messages', icon: Icon(Icons.message)),
            Tab(text: 'Templates', icon: Icon(Icons.article)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Settings', icon: Icon(Icons.settings)),
          ],
        ),
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
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMessagesTab(),
                    _buildTemplatesTab(),
                    _buildAnalyticsTab(),
                    _buildSettingsTab(),
                  ],
                ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _showSendMessageDialog,
              backgroundColor: const Color(0xFF25D366),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildMessagesTab() {
    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: _messages.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('Start a conversation with your customers'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageCard(message);
              },
            ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final isOutgoing = message['direction'] == 'outbound';
    final messageType = message['type'] ?? 'text';
    final timestamp = message['timestamp'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutgoing
                        ? Colors.green.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOutgoing ? 'Sent' : 'Received',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOutgoing
                          ? Colors.green.shade700
                          : Colors.blue.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                if (timestamp != null) ...[
                  Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Message content
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isOutgoing ? Colors.green : Colors.blue,
                  child: Icon(
                    isOutgoing ? Icons.send : Icons.person,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOutgoing
                            ? 'To: ${message['to'] ?? 'Unknown'}'
                            : 'From: ${message['from'] ?? 'Unknown'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildMessageContent(message, messageType),
                    ],
                  ),
                ),
              ],
            ),

            // Message status
            if (isOutgoing && message['status'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _getStatusIcon(message['status']),
                    size: 16,
                    color: _getStatusColor(message['status']),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusText(message['status']),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(message['status']),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(
      Map<String, dynamic> message, String messageType) {
    switch (messageType) {
      case 'text':
        return Text(
          message['text']?['body'] ?? 'No content',
          style: const TextStyle(fontSize: 16),
        );
      case 'template':
        final templateName = message['template']?['name'] ?? 'Unknown template';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Template: $templateName',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            if (message['template']?['components'] != null) ...[
              const SizedBox(height: 4),
              Text(
                message['template']['components'][0]['text'] ??
                    'Template message',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        );
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.image, size: 16, color: Colors.green),
                SizedBox(width: 4),
                Text('Image', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (message['image']?['caption'] != null) ...[
              const SizedBox(height: 4),
              Text(message['image']['caption']),
            ],
          ],
        );
      case 'document':
        return Row(
          children: [
            const Icon(Icons.description, size: 16, color: Colors.blue),
            const SizedBox(width: 4),
            Text(
              message['document']?['filename'] ?? 'Document',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      default:
        return Text(
          'Unsupported message type: $messageType',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        );
    }
  }

  Widget _buildTemplatesTab() {
    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: _templates.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No templates found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('Create templates in Meta Business Manager'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return _buildTemplateCard(template);
              },
            ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    final status = template['status'] ?? 'unknown';
    final category = template['category'] ?? 'unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template['name'] ?? 'Unnamed Template',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTemplateStatusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Category: ${category.toUpperCase()}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),

            if (template['language'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Language: ${template['language']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Template components
            if (template['components'] != null) ...[
              ...List.generate(
                (template['components'] as List).length,
                (index) {
                  final component = template['components'][index];
                  return _buildTemplateComponent(component);
                },
              ),
            ],

            if (status == 'APPROVED') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showUseTemplateDialog(template),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Use Template'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateComponent(Map<String, dynamic> component) {
    final type = component['type'] ?? 'unknown';

    switch (type) {
      case 'HEADER':
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            component['text'] ?? 'Header',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case 'BODY':
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Text(
            component['text'] ?? 'Body text',
            style: const TextStyle(fontSize: 16),
          ),
        );
      case 'FOOTER':
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Text(
            component['text'] ?? 'Footer',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        );
      case 'BUTTONS':
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Buttons:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ...List.generate(
                (component['buttons'] as List? ?? []).length,
                (index) {
                  final button = component['buttons'][index];
                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      button['text'] ?? 'Button',
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      default:
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Unknown component: $type',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        );
    }
  }

  Widget _buildAnalyticsTab() {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business profile overview
            if (_businessProfile != null) _buildBusinessProfileOverview(),

            const SizedBox(height: 24),

            // Analytics cards
            if (_analytics != null) ...[
              const Text(
                'Message Analytics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildAnalyticsCards(),
            ] else ...[
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.analytics, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Analytics not available',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text('Analytics data will appear when available'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessProfileOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _businessProfile!['display_name'] ?? 'Business Profile',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_businessProfile!['description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _businessProfile!['description'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_businessProfile!['about'] != null ||
                _businessProfile!['email'] != null ||
                _businessProfile!['websites'] != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
            ],
            if (_businessProfile!['about'] != null) ...[
              _buildProfileInfo('About', _businessProfile!['about']),
              const SizedBox(height: 8),
            ],
            if (_businessProfile!['email'] != null) ...[
              _buildProfileInfo('Email', _businessProfile!['email']),
              const SizedBox(height: 8),
            ],
            if (_businessProfile!['websites'] != null &&
                (_businessProfile!['websites'] as List).isNotEmpty) ...[
              _buildProfileInfo(
                  'Website', (_businessProfile!['websites'] as List).first),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard('Messages Sent', _analytics?['sent']?.toString() ?? '0',
            Icons.send),
        _buildStatCard('Messages Received',
            _analytics?['received']?.toString() ?? '0', Icons.inbox),
        _buildStatCard(
            'Templates', _templates.length.toString(), Icons.article),
        _buildStatCard('Delivered', _analytics?['delivered']?.toString() ?? '0',
            Icons.check_circle),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: const Color(0xFF25D366),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WhatsApp Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Business Profile Settings
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Business Profile'),
                  subtitle: const Text('Manage your business information'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Navigate to business profile settings
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Business Hours'),
                  subtitle: const Text('Set your operating hours'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Navigate to business hours settings
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Message Settings
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('Auto Responses'),
                  subtitle: const Text('Configure automated messages'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Navigate to auto response settings
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.article),
                  title: const Text('Message Templates'),
                  subtitle: const Text('Manage message templates'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Navigate to template management
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Webhook Settings
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.webhook),
                  title: const Text('Webhook Configuration'),
                  subtitle: const Text('Configure webhook settings'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Navigate to webhook settings
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  subtitle: const Text('Configure notification preferences'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: Navigate to notification settings
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Connection Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Connected'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_integration != null) ...[
                    Text(
                      'Connected on ${_integration!.createdAt.toString().split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendMessageDialog() {
    showDialog(
      context: context,
      builder: (context) => _SendMessageDialog(
        templates: _templates,
        onSendMessage: _sendMessage,
      ),
    );
  }

  void _showUseTemplateDialog(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (context) => _UseTemplateDialog(
        template: template,
        onSendTemplate: (to) =>
            _sendMessage(to, '', templateName: template['name']),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timestamp;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return Icons.check;
      case 'delivered':
        return Icons.done_all;
      case 'read':
        return Icons.done_all;
      case 'failed':
        return Icons.error;
      default:
        return Icons.schedule;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return Colors.grey;
      case 'delivered':
        return Colors.blue;
      case 'read':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'sent':
        return 'Sent';
      case 'delivered':
        return 'Delivered';
      case 'read':
        return 'Read';
      case 'failed':
        return 'Failed';
      default:
        return 'Pending';
    }
  }

  Color _getTemplateStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'disabled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

class _SendMessageDialog extends StatefulWidget {
  final List<Map<String, dynamic>> templates;
  final Function(String to, String message, {String? templateName})
      onSendMessage;

  const _SendMessageDialog({
    required this.templates,
    required this.onSendMessage,
  });

  @override
  State<_SendMessageDialog> createState() => _SendMessageDialogState();
}

class _SendMessageDialogState extends State<_SendMessageDialog> {
  final _toController = TextEditingController();
  final _messageController = TextEditingController();
  String _messageType = 'text';
  String? _selectedTemplate;
  bool _isLoading = false;

  @override
  void dispose() {
    _toController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _toController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1234567890',
              border: OutlineInputBorder(),
              prefixText: '+',
            ),
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 16),

          // Message type selection
          DropdownButtonFormField<String>(
            value: _messageType,
            decoration: const InputDecoration(
              labelText: 'Message Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'text', child: Text('Text Message')),
              DropdownMenuItem(
                  value: 'template', child: Text('Template Message')),
            ],
            onChanged: (value) {
              setState(() {
                _messageType = value!;
              });
            },
          ),

          const SizedBox(height: 16),

          if (_messageType == 'text') ...[
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Type your message...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 1000,
            ),
          ] else if (_messageType == 'template') ...[
            DropdownButtonFormField<String>(
              value: _selectedTemplate,
              decoration: const InputDecoration(
                labelText: 'Template',
                border: OutlineInputBorder(),
              ),
              items: widget.templates
                  .where((template) => template['status'] == 'APPROVED')
                  .map((template) => DropdownMenuItem<String>(
                        value: template['name'],
                        child: Text(template['name']),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTemplate = value;
                });
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendMessage,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  void _sendMessage() {
    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_messageType == 'text' && _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_messageType == 'template' && _selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a template'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    widget.onSendMessage(
      _toController.text.trim(),
      _messageController.text.trim(),
      templateName: _messageType == 'template' ? _selectedTemplate : null,
    );

    Navigator.pop(context);
  }
}

class _UseTemplateDialog extends StatefulWidget {
  final Map<String, dynamic> template;
  final Function(String to) onSendTemplate;

  const _UseTemplateDialog({
    required this.template,
    required this.onSendTemplate,
  });

  @override
  State<_UseTemplateDialog> createState() => _UseTemplateDialogState();
}

class _UseTemplateDialogState extends State<_UseTemplateDialog> {
  final _toController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Send Template: ${widget.template['name']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _toController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1234567890',
              border: OutlineInputBorder(),
              prefixText: '+',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Template Preview:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (widget.template['components'] != null) ...[
                  ...List.generate(
                    (widget.template['components'] as List).length,
                    (index) {
                      final component = widget.template['components'][index];
                      if (component['text'] != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(component['text']),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendTemplate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  void _sendTemplate() {
    if (_toController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    widget.onSendTemplate(_toController.text.trim());
    Navigator.pop(context);
  }
}
