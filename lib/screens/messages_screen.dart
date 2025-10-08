import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message.dart';
import '../providers/messages_provider.dart';
import '../widgets/messages/conversation_list.dart';
import '../widgets/messages/platform_filter_chips.dart';
import '../widgets/messages/messages_search_bar.dart';
import '../widgets/messages/message_stats_card.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsyncValue = ref.watch(messagesProvider);
    final messageFilters = ref.watch(messageFiltersProvider);
    final selectedPlatforms = ref.watch(selectedPlatformsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            foregroundColor: theme.colorScheme.onSurface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primaryContainer.withOpacity(0.3),
                      theme.colorScheme.secondaryContainer.withOpacity(0.3),
                      theme.colorScheme.tertiaryContainer.withOpacity(0.3),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Actions
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Messages',
                                    style: GoogleFonts.inter(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Manage all your customer conversations',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Action Buttons
                            IconButton(
                              onPressed: () => _showFilterDialog(context, ref),
                              icon: Badge(
                                isLabelVisible: messageFilters.hasActiveFilters,
                                backgroundColor: theme.colorScheme.error,
                                child: Icon(
                                  Icons.filter_list,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => ref.refresh(messagesProvider),
                              icon: Icon(
                                Icons.refresh,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Message Stats Cards
                        const MessageStatsCard(),

                        const SizedBox(height: 20),

                        // Search Bar
                        const MessagesSearchBar(),

                        const SizedBox(height: 16),

                        // Platform Filter Chips
                        const PlatformFilterChips(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Unread'),
                Tab(text: 'Pinned'),
                Tab(text: 'Archived'),
              ],
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),

          // Content
          SliverFillRemaining(
            child: messagesAsyncValue.when(
              data: (conversations) =>
                  _buildTabContent(conversations, selectedPlatforms),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading messages',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: GoogleFonts.inter(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(messagesProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showComposeDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Compose'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildTabContent(List<Conversation> conversations,
      Set<MessagePlatform> selectedPlatforms) {
    return TabBarView(
      controller: _tabController,
      children: [
        // All conversations
        ConversationList(
          conversations: _filterConversations(conversations, selectedPlatforms),
          onConversationTap: _onConversationTap,
        ),
        // Unread conversations
        ConversationList(
          conversations: _filterConversations(
            conversations.where((c) => c.unreadCount > 0).toList(),
            selectedPlatforms,
          ),
          onConversationTap: _onConversationTap,
        ),
        // Pinned conversations
        ConversationList(
          conversations: _filterConversations(
            conversations.where((c) => c.isPinned).toList(),
            selectedPlatforms,
          ),
          onConversationTap: _onConversationTap,
        ),
        // Archived conversations
        ConversationList(
          conversations: _filterConversations(
            conversations.where((c) => c.isArchived).toList(),
            selectedPlatforms,
          ),
          onConversationTap: _onConversationTap,
        ),
      ],
    );
  }

  List<Conversation> _filterConversations(
    List<Conversation> conversations,
    Set<MessagePlatform> selectedPlatforms,
  ) {
    if (selectedPlatforms.isEmpty) return conversations;

    return conversations
        .where(
            (conversation) => selectedPlatforms.contains(conversation.platform))
        .toList();
  }

  void _onConversationTap(Conversation conversation) {
    Navigator.pushNamed(
      context,
      '/messages/conversation',
      arguments: conversation,
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const MessagesFilterSheet(),
      ),
    );
  }

  void _showComposeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ComposeMessageDialog(),
    );
  }
}

// Filter Sheet Widget
class MessagesFilterSheet extends ConsumerWidget {
  const MessagesFilterSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(messageFiltersProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Filter Messages',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Filter
                  _buildFilterSection(
                    'Date Range',
                    Column(
                      children: [
                        ListTile(
                          title: const Text('Start Date'),
                          subtitle: Text(
                            filters.startDate?.toString().split(' ')[0] ??
                                'Not set',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectStartDate(context, ref),
                        ),
                        ListTile(
                          title: const Text('End Date'),
                          subtitle: Text(
                            filters.endDate?.toString().split(' ')[0] ??
                                'Not set',
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () => _selectEndDate(context, ref),
                        ),
                      ],
                    ),
                  ),

                  // Message Type Filter
                  _buildFilterSection(
                    'Message Types',
                    Wrap(
                      spacing: 8,
                      children: MessageType.values.map((type) {
                        final isSelected = filters.messageTypes.contains(type);
                        return FilterChip(
                          label: Text(type.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref
                                .read(messageFiltersProvider.notifier)
                                .toggleMessageType(type);
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  // Priority Filter
                  _buildFilterSection(
                    'Priority',
                    Wrap(
                      spacing: 8,
                      children: MessagePriority.values.map((priority) {
                        final isSelected =
                            filters.priorities.contains(priority);
                        return FilterChip(
                          label: Text(priority.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            ref
                                .read(messageFiltersProvider.notifier)
                                .togglePriority(priority);
                          },
                        );
                      }).toList(),
                    ),
                  ),

                  // Read Status Filter
                  _buildFilterSection(
                    'Read Status',
                    Column(
                      children: [
                        CheckboxListTile(
                          title: const Text('Show Read Messages'),
                          value: filters.showRead,
                          onChanged: (value) {
                            ref
                                .read(messageFiltersProvider.notifier)
                                .setShowRead(value ?? true);
                          },
                        ),
                        CheckboxListTile(
                          title: const Text('Show Unread Messages'),
                          value: filters.showUnread,
                          onChanged: (value) {
                            ref
                                .read(messageFiltersProvider.notifier)
                                .setShowUnread(value ?? true);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(messageFiltersProvider.notifier).clearFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        content,
        const SizedBox(height: 24),
      ],
    );
  }

  void _selectStartDate(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      ref.read(messageFiltersProvider.notifier).setStartDate(date);
    }
  }

  void _selectEndDate(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      ref.read(messageFiltersProvider.notifier).setEndDate(date);
    }
  }
}

// Compose Message Dialog
class ComposeMessageDialog extends StatefulWidget {
  const ComposeMessageDialog({Key? key}) : super(key: key);

  @override
  State<ComposeMessageDialog> createState() => _ComposeMessageDialogState();
}

class _ComposeMessageDialogState extends State<ComposeMessageDialog> {
  final _messageController = TextEditingController();
  MessagePlatform? _selectedPlatform;
  String? _selectedRecipient;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Compose Message',
        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Platform Selector
            DropdownButtonFormField<MessagePlatform>(
              decoration: const InputDecoration(
                labelText: 'Platform',
                border: OutlineInputBorder(),
              ),
              value: _selectedPlatform,
              items: MessagePlatform.values.map((platform) {
                return DropdownMenuItem(
                  value: platform,
                  child: Row(
                    children: [
                      Text(platform.icon),
                      const SizedBox(width: 8),
                      Text(platform.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedPlatform = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Recipient Field
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Recipient',
                border: OutlineInputBorder(),
                hintText: 'Enter recipient ID or username',
              ),
              onChanged: (value) {
                _selectedRecipient = value;
              },
            ),
            const SizedBox(height: 16),

            // Message Field
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                hintText: 'Type your message...',
              ),
              maxLines: 3,
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
          onPressed: _canSend()
              ? () {
                  // TODO: Implement message sending
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message sending not yet implemented'),
                    ),
                  );
                }
              : null,
          child: const Text('Send'),
        ),
      ],
    );
  }

  bool _canSend() {
    return _selectedPlatform != null &&
        _selectedRecipient?.isNotEmpty == true &&
        _messageController.text.isNotEmpty;
  }
}
