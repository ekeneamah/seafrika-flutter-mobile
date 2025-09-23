import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/integration_service.dart';
import 'package:vendor_app/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Providers for WhatsApp
final whatsappMessagesProvider = StateNotifierProvider.autoDispose.family<
    WhatsAppMessagesNotifier,
    AsyncValue<List<Map<String, dynamic>>>,
    WhatsAppMessagesParams>((ref, params) {
  return WhatsAppMessagesNotifier(ref, params);
});

// Parameters for WhatsApp messages provider
class WhatsAppMessagesParams {
  final String integrationId;
  final String contactId;

  WhatsAppMessagesParams({
    required this.integrationId,
    required this.contactId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppMessagesParams &&
          runtimeType == other.runtimeType &&
          integrationId == other.integrationId &&
          contactId == other.contactId;

  @override
  int get hashCode => integrationId.hashCode ^ contactId.hashCode;
}

final whatsappConversationsProvider = StateNotifierProvider.autoDispose.family<
    WhatsAppConversationsNotifier,
    AsyncValue<List<Map<String, dynamic>>>,
    String>((ref, integrationId) {
  return WhatsAppConversationsNotifier(ref, integrationId);
});

final whatsappBusinessProfileProvider = StateNotifierProvider.autoDispose
    .family<WhatsAppBusinessProfileNotifier, AsyncValue<Map<String, dynamic>?>,
        String>((ref, integrationId) {
  return WhatsAppBusinessProfileNotifier(ref, integrationId);
});

final whatsappAnalyticsProvider = StateNotifierProvider.autoDispose.family<
    WhatsAppAnalyticsNotifier,
    AsyncValue<Map<String, dynamic>?>,
    String>((ref, integrationId) {
  return WhatsAppAnalyticsNotifier(ref, integrationId);
});

// Notifiers
class WhatsAppMessagesNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  final String _integrationId;
  final String _contactId;

  WhatsAppMessagesNotifier(this._ref, WhatsAppMessagesParams params)
      : _integrationId = params.integrationId,
        _contactId = params.contactId,
        super(const AsyncValue.loading()) {
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    try {
      final service = _ref.read(integrationServiceProvider);
      if (service == null) throw Exception('Service not available');

      final token = await service.getUserIdToken();

      final response = await http.get(
        Uri.parse(
            '${service.baseUrl}/integrations/whatsapp/$_integrationId/conversations/$_contactId/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        state = AsyncValue.data(
            List<Map<String, dynamic>>.from(data['messages'] ?? []));
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> sendMessage(String to, String message) async {
    try {
      final service = _ref.read(integrationServiceProvider);
      if (service == null) throw Exception('Service not available');

      final token = await service.getUserIdToken();

      final response = await http.post(
        Uri.parse(
            '${service.baseUrl}/integrations/whatsapp/$_integrationId/send-message'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'to': to,
          'type': 'text',
          'text': {'body': message}
        }),
      );

      if (response.statusCode == 200) {
        await fetchMessages();
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      // Handle error
      print('Error sending message: $e');
    }
  }

  Future<void> markAsRead(String messageId) async {
    try {
      final service = _ref.read(integrationServiceProvider);
      if (service == null) throw Exception('Service not available');

      final token = await service.getUserIdToken();

      final response = await http.post(
        Uri.parse(
            '${service.baseUrl}/integrations/whatsapp/$_integrationId/mark-read/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        await fetchMessages();
      } else {
        throw Exception(
            'Failed to mark message as read: ${response.statusCode}');
      }
    } catch (e) {
      // Handle error
      print('Error marking message as read: $e');
    }
  }
}

class WhatsAppConversationsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  final String _integrationId;

  WhatsAppConversationsNotifier(this._ref, this._integrationId)
      : super(const AsyncValue.loading()) {
    fetchConversations();
  }

  Future<void> fetchConversations() async {
    try {
      final service = _ref.read(integrationServiceProvider);
      if (service == null) throw Exception('Service not available');

      final token = await service.getUserIdToken();

      final response = await http.get(
        Uri.parse(
            '${service.baseUrl}/integrations/whatsapp/$_integrationId/conversations'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        state = AsyncValue.data(
            List<Map<String, dynamic>>.from(data['conversations'] ?? []));
      } else {
        throw Exception('Failed to load conversations: ${response.statusCode}');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

class WhatsAppBusinessProfileNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final Ref _ref;
  final String _integrationId;

  WhatsAppBusinessProfileNotifier(this._ref, this._integrationId)
      : super(const AsyncValue.loading()) {
    fetchBusinessProfile();
  }

  Future<void> fetchBusinessProfile() async {
    try {
      final service = _ref.read(integrationServiceProvider);
      if (service == null) throw Exception('Service not available');

      final token = await service.getUserIdToken();

      final response = await http.get(
        Uri.parse(
            '${service.baseUrl}/integrations/whatsapp/$_integrationId/business-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        state = AsyncValue.data(Map<String, dynamic>.from(data));
      } else {
        throw Exception(
            'Failed to load business profile: ${response.statusCode}');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateBusinessProfile(Map<String, dynamic> profileData) async {
    try {
      final service = _ref.read(integrationServiceProvider);
      if (service == null) throw Exception('Service not available');

      final token = await service.getUserIdToken();

      final response = await http.post(
        Uri.parse(
            '${service.baseUrl}/integrations/whatsapp/$_integrationId/business-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(profileData),
      );

      if (response.statusCode == 200) {
        await fetchBusinessProfile();
      } else {
        throw Exception(
            'Failed to update business profile: ${response.statusCode}');
      }
    } catch (e) {
      // Handle error
      print('Error updating business profile: $e');
    }
  }
}

class WhatsAppAnalyticsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>?>> {
  final Ref _ref;
  final String _integrationId;

  WhatsAppAnalyticsNotifier(this._ref, this._integrationId)
      : super(const AsyncValue.loading()) {
    fetchAnalytics();
  }

  Future<void> fetchAnalytics() async {
    try {
      final service = _ref.read(integrationServiceProvider);
      if (service == null) throw Exception('Service not available');

      final token = await service.getUserIdToken();

      // Get analytics for the last 30 days
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final startDate = DateFormat('yyyy-MM-dd').format(thirtyDaysAgo);
      final endDate = DateFormat('yyyy-MM-dd').format(now);

      final response = await http.get(
        Uri.parse(
            '${service.baseUrl}/integrations/whatsapp/$_integrationId/analytics?start=$startDate&end=$endDate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        state = AsyncValue.data(Map<String, dynamic>.from(data));
      } else {
        throw Exception('Failed to load analytics: ${response.statusCode}');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

class WhatsAppEnhancedDashboardScreen extends ConsumerStatefulWidget {
  final String integrationId;
  final int initialTab;

  const WhatsAppEnhancedDashboardScreen({
    super.key,
    required this.integrationId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<WhatsAppEnhancedDashboardScreen> createState() =>
      _WhatsAppEnhancedDashboardScreenState();
}

class _WhatsAppEnhancedDashboardScreenState
    extends ConsumerState<WhatsAppEnhancedDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;
  Integration? _integration;
  String? _selectedContactId;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _loadIntegration();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadIntegration() async {
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
      final integration =
          integrations.where((i) => i.id == widget.integrationId).firstOrNull;

      if (integration == null) {
        throw Exception('Integration not found');
      }

      setState(() {
        _integration = integration;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load integration: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_integration?.platformName ?? 'WhatsApp Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Conversations'),
            Tab(text: 'Templates'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildConversationsTab(),
                    _buildTemplatesTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    final businessProfile =
        ref.watch(whatsappBusinessProfileProvider(widget.integrationId));

    return businessProfile.when(
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('No business profile found'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      if (profile['profile_picture_url'] != null)
                        Center(
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage:
                                NetworkImage(profile['profile_picture_url']),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _buildProfileItem(
                          'Business Name', profile['name'] ?? 'Not set'),
                      _buildProfileItem(
                          'Description', profile['description'] ?? 'Not set'),
                      _buildProfileItem(
                          'Address', profile['address'] ?? 'Not set'),
                      _buildProfileItem('Email', profile['email'] ?? 'Not set'),
                      _buildProfileItem(
                          'Industry', profile['vertical'] ?? 'Not set'),
                      if (profile['websites'] != null &&
                          (profile['websites'] as List).isNotEmpty)
                        _buildProfileItem(
                            'Website', (profile['websites'] as List).first),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quick stats card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Stats',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildQuickStatsGrid(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildActionButton(
                            icon: Icons.message,
                            label: 'Send Message',
                            onTap: () {
                              _tabController
                                  .animateTo(1); // Go to conversations tab
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.people,
                            label: 'Contacts',
                            onTap: () {
                              // Navigate to contacts screen
                            },
                          ),
                          _buildActionButton(
                            icon: Icons.article,
                            label: 'Templates',
                            onTap: () {
                              _tabController
                                  .animateTo(2); // Go to templates tab
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildConversationsTab() {
    final conversations =
        ref.watch(whatsappConversationsProvider(widget.integrationId));

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Conversation list
              SizedBox(
                width: 300,
                child: conversations.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return const Center(
                          child: Text('No conversations found'));
                    }

                    return ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final conversation = data[index];
                        final contact = conversation['contact'] ?? {};
                        final lastMessage = conversation['last_message'] ?? {};

                        return ListTile(
                          leading: CircleAvatar(
                            child:
                                Text((contact['name'] ?? '?').substring(0, 1)),
                          ),
                          title: Text(contact['name'] ?? 'Unknown'),
                          subtitle: Text(
                            lastMessage['text']?['body'] ?? 'No message',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: conversation['unread_count'] > 0
                              ? CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.green,
                                  child: Text(
                                    conversation['unread_count'].toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : null,
                          selected: _selectedContactId == contact['wa_id'],
                          onTap: () {
                            setState(() {
                              _selectedContactId = contact['wa_id'];
                            });
                          },
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(child: Text('Error: $error')),
                ),
              ),

              // Vertical divider
              const VerticalDivider(width: 1),

              // Conversation detail
              Expanded(
                child: _selectedContactId == null
                    ? const Center(
                        child: Text('Select a conversation to view messages'))
                    : _buildConversationDetail(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConversationDetail() {
    if (_selectedContactId == null) {
      return const Center(
          child: Text('Select a conversation to view messages'));
    }

    final messages = ref.watch(
      whatsappMessagesProvider(
        WhatsAppMessagesParams(
          integrationId: widget.integrationId,
          contactId: _selectedContactId!,
        ),
      ),
    );

    return Column(
      children: [
        // Messages list
        Expanded(
          child: messages.when(
            data: (data) {
              if (data.isEmpty) {
                return const Center(child: Text('No messages found'));
              }

              // Sort messages by timestamp
              data.sort((a, b) {
                final aTime = DateTime.parse(a['timestamp']);
                final bTime = DateTime.parse(b['timestamp']);
                return aTime.compareTo(bTime); // Ascending order
              });

              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final message = data[index];
                  final isFromMe = message['from'] ==
                      _integration?.credentials?['phone_number_id'];

                  return Align(
                    alignment:
                        isFromMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isFromMe
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message['text']?['body'] != null)
                            Text(message['text']['body']),
                          if (message['image'] != null) const Text('[Image]'),
                          if (message['video'] != null) const Text('[Video]'),
                          if (message['document'] != null)
                            const Text('[Document]'),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, h:mm a').format(
                              DateTime.parse(message['timestamp']),
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          ),
        ),

        // Message input
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () {
                  // Handle file attachment
                },
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 5,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (_messageController.text.isNotEmpty &&
                      _selectedContactId != null) {
                    final notifier = ref.read(
                      whatsappMessagesProvider(
                        WhatsAppMessagesParams(
                          integrationId: widget.integrationId,
                          contactId: _selectedContactId!,
                        ),
                      ).notifier,
                    );
                    notifier.sendMessage(
                        _selectedContactId!, _messageController.text);
                    _messageController.clear();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplatesTab() {
    // Placeholder for templates tab
    return FutureBuilder<http.Response>(
      future: _fetchTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.statusCode != 200) {
          return const Center(child: Text('Failed to load templates'));
        }

        final templates = json.decode(snapshot.data!.body);
        if (templates is! List || templates.isEmpty) {
          return const Center(child: Text('No templates found'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template['name'] ?? 'Unnamed Template',
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${template['status'] ?? 'Unknown'}',
                      style: TextStyle(
                        color: _getStatusColor(template['status']),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        'Language: ${template['language'] ?? 'Not specified'}'),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          // Show dialog to send template
                          _showSendTemplateDialog(template);
                        },
                        child: const Text('Send'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    final analytics =
        ref.watch(whatsappAnalyticsProvider(widget.integrationId));

    return analytics.when(
      data: (data) {
        if (data == null) {
          return const Center(child: Text('No analytics data found'));
        }

        final dataPoints = data['data_points'] as List? ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message Metrics',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildMetricsGrid(dataPoints),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Message Status Chart',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 300,
                        child: _buildMessageChart(dataPoints),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  // Helper methods
  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildQuickStatsGrid() {
    final conversations =
        ref.watch(whatsappConversationsProvider(widget.integrationId));
    final analytics =
        ref.watch(whatsappAnalyticsProvider(widget.integrationId));

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      children: [
        _buildStatItem(
          'Conversations',
          conversations.when(
            data: (data) => data.length.toString(),
            loading: () => '...',
            error: (_, __) => '0',
          ),
        ),
        _buildStatItem(
          'Messages Sent',
          analytics.when(
            data: (data) {
              int total = 0;
              for (final point in (data?['data_points'] as List? ?? [])) {
                total += (point['sent'] as int?) ?? 0;
              }
              return total.toString();
            },
            loading: () => '...',
            error: (_, __) => '0',
          ),
        ),
        _buildStatItem(
          'Messages Delivered',
          analytics.when(
            data: (data) {
              int total = 0;
              for (final point in (data?['data_points'] as List? ?? [])) {
                total += (point['delivered'] as int?) ?? 0;
              }
              return total.toString();
            },
            loading: () => '...',
            error: (_, __) => '0',
          ),
        ),
        _buildStatItem(
          'Messages Read',
          analytics.when(
            data: (data) {
              int total = 0;
              for (final point in (data?['data_points'] as List? ?? [])) {
                total += (point['read'] as int?) ?? 0;
              }
              return total.toString();
            },
            loading: () => '...',
            error: (_, __) => '0',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue.shade100,
            child: Icon(icon, color: Colors.blue.shade800),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(List dataPoints) {
    // Calculate totals
    int totalSent = 0;
    int totalDelivered = 0;
    int totalRead = 0;
    int totalFailed = 0;

    for (final point in dataPoints) {
      totalSent += (point['sent'] as int?) ?? 0;
      totalDelivered += (point['delivered'] as int?) ?? 0;
      totalRead += (point['read'] as int?) ?? 0;
      totalFailed += (point['failed'] as int?) ?? 0;
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      children: [
        _buildMetricItem('Sent', totalSent.toString(), Colors.blue),
        _buildMetricItem('Delivered', totalDelivered.toString(), Colors.green),
        _buildMetricItem('Read', totalRead.toString(), Colors.purple),
        _buildMetricItem('Failed', totalFailed.toString(), Colors.red),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(
                _getIconForMetric(label),
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageChart(List dataPoints) {
    // This is a placeholder for a chart
    // In a real implementation, you would use a charting library like fl_chart
    return Center(
      child: Text(
        'Message Analytics Chart\nTotal Data Points: ${dataPoints.length}',
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<http.Response> _fetchTemplates() async {
    final service = ref.read(integrationServiceProvider);
    if (service == null) throw Exception('Service not available');

    final token = await service.getUserIdToken();

    return http.get(
      Uri.parse(
          '${service.baseUrl}/integrations/whatsapp/${widget.integrationId}/templates'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  void _showSendTemplateDialog(Map<String, dynamic> template) {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Send "${template['name']}" Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Recipient Phone Number',
                hintText: '+1234567890',
              ),
              keyboardType: TextInputType.phone,
            ),
            // Additional fields for template parameters would go here
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (phoneController.text.isNotEmpty) {
                _sendTemplate(template, phoneController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTemplate(
      Map<String, dynamic> template, String phone) async {
    try {
      final service = ref.read(integrationServiceProvider);
      if (service == null) throw Exception('Service not available');

      final token = await service.getUserIdToken();

      final response = await http.post(
        Uri.parse(
            '${service.baseUrl}/integrations/whatsapp/${widget.integrationId}/send-template'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'to': phone,
          'templateName': template['name'],
          'language': template['language'] ?? 'en_US',
          'components': [] // Template parameters would go here
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template sent successfully')),
        );
      } else {
        throw Exception('Failed to send template: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  IconData _getIconForMetric(String metric) {
    switch (metric) {
      case 'Sent':
        return Icons.send;
      case 'Delivered':
        return Icons.done;
      case 'Read':
        return Icons.done_all;
      case 'Failed':
        return Icons.error_outline;
      default:
        return Icons.message;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
