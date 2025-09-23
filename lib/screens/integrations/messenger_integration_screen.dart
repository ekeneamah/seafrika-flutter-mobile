import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/widgets/integration_app_bar.dart';
import 'package:vendor_app/services/navigation_service.dart';

/// Messenger Integration Screen
///
/// This screen handles Facebook Messenger integration for customer communication.
/// Features include:
/// - Message management and automation
/// - Customer conversation tracking
/// - Response templates and chatbots
/// - Message analytics and insights

class MessengerIntegrationScreen extends ConsumerStatefulWidget {
  final String? integrationId;

  const MessengerIntegrationScreen({
    super.key,
    this.integrationId,
  });

  @override
  ConsumerState<MessengerIntegrationScreen> createState() =>
      _MessengerIntegrationScreenState();
}

class _MessengerIntegrationScreenState
    extends ConsumerState<MessengerIntegrationScreen> {
  static const Color _messengerBlue = Color(0xFF0084FF);

  bool _isLoading = false;
  String? _error;
  Integration? _currentIntegration;

  @override
  void initState() {
    super.initState();
    _loadIntegration();
  }

  Future<void> _loadIntegration() async {
    if (widget.integrationId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final integrationService = ref.read(integrationServiceProvider);
      if (integrationService == null) {
        throw Exception('No business selected');
      }

      final integrations = await integrationService.fetchIntegrations();
      final integration = integrations.firstWhere(
        (i) => i.id == widget.integrationId,
        orElse: () => throw Exception('Integration not found'),
      );

      setState(() {
        _currentIntegration = integration;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IntegrationAppBar(
        title: 'Messenger',
        actions: [
          if (_currentIntegration != null)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                NavigationService.navigateToIntegrationSettings(
                  _currentIntegration!.id,
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _currentIntegration == null
                  ? _buildNotConnectedView()
                  : _buildConnectedView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Integration',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadIntegration,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message, size: 64, color: _messengerBlue),
          const SizedBox(height: 16),
          Text(
            'Messenger Not Connected',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Connect Facebook Messenger to manage customer conversations and automate responses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              NavigationService.navigateToAddIntegration();
            },
            icon: const Icon(Icons.add),
            label: const Text('Connect Messenger'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _messengerBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedView() {
    final pageInfo = _currentIntegration!.accountInfo;
    final pageName = pageInfo?['pageName'] ?? 'Unknown Page';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Info Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _messengerBlue,
                    child: const Icon(
                      Icons.message,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Messenger for $pageName',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Analytics Cards
          Text(
            'Analytics Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Analytics Row
          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Total Messages',
                  value: '1,247',
                  icon: Icons.chat_bubble_outline,
                  color: _messengerBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'This Week',
                  value: '89',
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Avg Response',
                  value: '12 min',
                  icon: Icons.timer_outlined,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnalyticsCard(
                  title: 'Active Chats',
                  value: '23',
                  icon: Icons.people_outline,
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Inbox Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Messages',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Full inbox view coming soon!'),
                    ),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Message Items
          _buildMessageItem(
            customerName: 'Sarah Johnson',
            lastMessage: 'Hi, I have a question about my order...',
            timestamp: '2 min ago',
            isUnread: true,
          ),

          _buildMessageItem(
            customerName: 'Mike Chen',
            lastMessage: 'Thank you for the quick response!',
            timestamp: '15 min ago',
            isUnread: false,
          ),

          _buildMessageItem(
            customerName: 'Lisa Rodriguez',
            lastMessage: 'When will my package arrive?',
            timestamp: '1 hour ago',
            isUnread: true,
          ),

          _buildMessageItem(
            customerName: 'John Smith',
            lastMessage: 'Perfect, exactly what I needed.',
            timestamp: '3 hours ago',
            isUnread: false,
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.smart_toy,
                  title: 'Auto-Replies',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Auto-replies settings coming soon!'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    NavigationService.navigateToIntegrationSettings(
                      _currentIntegration!.id,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Disconnect Section
          Center(
            child: TextButton.icon(
              onPressed: () => _showDisconnectDialog(),
              icon: Icon(Icons.link_off, color: Colors.red[600]),
              label: Text(
                'Disconnect Messenger',
                style: TextStyle(color: Colors.red[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required String customerName,
    required String lastMessage,
    required String timestamp,
    required bool isUnread,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening conversation with $customerName...'),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _messengerBlue.withOpacity(0.1),
                child: Text(
                  customerName[0].toUpperCase(),
                  style: TextStyle(
                    color: _messengerBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          customerName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          timestamp,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isUnread ? Colors.black87 : Colors.grey[600],
                            fontWeight:
                                isUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _messengerBlue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                color: _messengerBlue,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Messenger'),
        content: const Text(
          'Are you sure you want to disconnect your Messenger integration? '
          'This will stop receiving messages and remove access to Messenger features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _disconnectIntegration();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectIntegration() async {
    // TODO: Implement disconnect logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disconnect functionality coming soon!'),
      ),
    );
  }
}
